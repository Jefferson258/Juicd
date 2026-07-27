import Foundation

struct SupabasePlayBoardResponse: Decodable {
    struct RibbonDTO: Decodable {
        var id: String
        var title: String
        var subtitle: String?
        var props: [PropDTO]
    }

    struct PropDTO: Decodable {
        var id: String
        var leagueTag: String
        var athleteOrTeam: String
        var matchup: String
        var propDescription: String
        var lineText: String
        var pickLabel: String
        var oddsDecimal: Double
    }

    var mode: String
    var source: String
    var slateKey: String
    var ribbons: [RibbonDTO]
    /// Present when Edge serves a read-through snapshot.
    var cached: Bool?
    var ageSeconds: Int?
    var ttlSeconds: Int?
}

struct SupabaseResolveSlipResponse: Decodable {
    struct LegOutcomeDTO: Decodable {
        var legId: String
        var didWin: Bool
    }

    var slateKey: String
    var outcomes: [LegOutcomeDTO]
}

enum SupabaseOddsService {
    /// Client soft-TTL: skip Edge if we have a fresh board in memory/disk.
    /// Manual Sync should pass `bypassClientCache: true` (Edge TTL still applies).
    private static let clientTTLSeconds: TimeInterval = 180
    private static let diskCacheKey = "juicd_play_board_client_cache_v1"

    private static var memoryCache: (savedAt: Date, response: SupabasePlayBoardResponse)?
    private static let cacheLock = NSLock()

    static func fetchPlayBoard(bypassClientCache: Bool = false) async -> SupabasePlayBoardResponse? {
        if !bypassClientCache, let cached = loadClientCache(), isClientFresh(cached.savedAt) {
            return cached.response
        }

        guard let url = SupabaseConfig.edgeBaseURL?.appendingPathComponent("play-board") else { return nil }
        // Client Sync never forces Edge Odds refresh — Edge TTL owns Odds quota.
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(SupabasePlayBoardResponse.self, from: data)
            saveClientCache(decoded, raw: data)
            return decoded
        } catch {
            // Prefer last known board over nil when offline / flake.
            if let cached = loadClientCache() {
                return cached.response
            }
            return nil
        }
    }

    static func clearClientBoardCache() {
        cacheLock.lock()
        memoryCache = nil
        cacheLock.unlock()
        UserDefaults.standard.removeObject(forKey: diskCacheKey)
    }

    private static func isClientFresh(_ savedAt: Date) -> Bool {
        Date().timeIntervalSince(savedAt) < clientTTLSeconds
    }

    private static func loadClientCache() -> (savedAt: Date, response: SupabasePlayBoardResponse)? {
        cacheLock.lock()
        let mem = memoryCache
        cacheLock.unlock()
        if let mem { return mem }

        guard
            let data = UserDefaults.standard.data(forKey: diskCacheKey),
            let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: data),
            let response = try? JSONDecoder().decode(SupabasePlayBoardResponse.self, from: envelope.payload)
        else { return nil }

        let savedAt = Date(timeIntervalSince1970: envelope.savedAt)
        cacheLock.lock()
        memoryCache = (savedAt, response)
        cacheLock.unlock()
        return (savedAt, response)
    }

    private static func saveClientCache(_ response: SupabasePlayBoardResponse, raw: Data) {
        let now = Date()
        cacheLock.lock()
        memoryCache = (now, response)
        cacheLock.unlock()
        let envelope = DiskEnvelope(savedAt: now.timeIntervalSince1970, payload: raw)
        if let data = try? JSONEncoder().encode(envelope) {
            UserDefaults.standard.set(data, forKey: diskCacheKey)
        }
    }

    private struct DiskEnvelope: Codable {
        var savedAt: Double
        var payload: Data
    }

    static func resolvePlaySlip(
        userId: UUID,
        legs: [BetLeg]
    ) async -> SupabaseResolveSlipResponse? {
        guard let url = SupabaseConfig.edgeBaseURL?.appendingPathComponent("resolve-play-slip") else { return nil }

        struct ResolveLegRequest: Encodable {
            var legId: String
            var choiceLabel: String
            var oddsDecimalAtSubmit: Double
        }
        struct ResolveRequest: Encodable {
            var userId: String
            var legs: [ResolveLegRequest]
        }

        let payload = ResolveRequest(
            userId: userId.uuidString.lowercased(),
            legs: legs.map {
                ResolveLegRequest(
                    legId: $0.id.uuidString.lowercased(),
                    choiceLabel: $0.choiceLabel,
                    oddsDecimalAtSubmit: $0.oddsDecimalAtSubmit
                )
            }
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(SupabaseResolveSlipResponse.self, from: data)
        } catch {
            return nil
        }
    }
}
