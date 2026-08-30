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

/// Pure cache rules kept separate from URLSession so expiry and stale fallback
/// behavior can be tested without a network or a live Supabase project.
struct SupabasePlayBoardCachePolicy {
    let clientTTLSeconds: TimeInterval
    let maxStaleFallbackSeconds: TimeInterval

    func isFresh(savedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(savedAt)
        return age >= 0 && age < clientTTLSeconds
    }

    func staleResponse(
        _ response: SupabasePlayBoardResponse,
        savedAt: Date,
        now: Date
    ) -> SupabasePlayBoardResponse? {
        let age = now.timeIntervalSince(savedAt)
        guard age >= 0, age <= maxStaleFallbackSeconds else { return nil }
        var response = response
        response.cached = true
        response.ageSeconds = Int(age.rounded(.down))
        return response
    }
}

enum SupabaseOddsService {
    /// Client soft-TTL: skip Edge if we have a fresh board in memory/disk.
    /// Manual Sync should pass `bypassClientCache: true` (Edge TTL still applies).
    static let cachePolicy = SupabasePlayBoardCachePolicy(
        clientTTLSeconds: 180,
        maxStaleFallbackSeconds: 3600
    )
    /// A failed refresh may use a stale board briefly, but never indefinitely.
    /// Older odds can make a virtual-points pick inconsistent with the slate.
    private static let diskCacheKey = "juicd_play_board_client_cache_v1"

    private static var memoryCache: (savedAt: Date, response: SupabasePlayBoardResponse)?
    private static var inFlightFetch: Task<SupabasePlayBoardResponse?, Never>?
    private static let cacheLock = NSLock()

    /// Accept a settlement response only when it contains exactly one
    /// authoritative outcome for every submitted leg. A partial response must
    /// never be interpreted as losses by the local repository.
    static func validatedOutcomeMap(
        _ response: SupabaseResolveSlipResponse,
        for legs: [BetLeg]
    ) -> [UUID: Bool]? {
        guard !legs.isEmpty, response.outcomes.count == legs.count else { return nil }

        let expectedIds = Set(legs.map(\.id))
        var result: [UUID: Bool] = [:]
        for outcome in response.outcomes {
            guard let id = UUID(uuidString: outcome.legId),
                  expectedIds.contains(id),
                  result[id] == nil else {
                return nil
            }
            result[id] = outcome.didWin
        }
        return result.count == expectedIds.count ? result : nil
    }

    static func fetchPlayBoard(bypassClientCache: Bool = false) async -> SupabasePlayBoardResponse? {
        if !bypassClientCache, let cached = loadClientCache(),
           cachePolicy.isFresh(savedAt: cached.savedAt, now: .now) {
            return cached.response
        }

        cacheLock.lock()
        if let inFlightFetch {
            cacheLock.unlock()
            return await inFlightFetch.value
        }
        let task = Task { await performFetch() }
        inFlightFetch = task
        cacheLock.unlock()

        let result = await task.value
        cacheLock.lock()
        inFlightFetch = nil
        cacheLock.unlock()
        return result
    }

    private static func performFetch() async -> SupabasePlayBoardResponse? {
        guard let url = SupabaseConfig.edgeBaseURL?.appendingPathComponent("play-board") else {
            logFetchFailure(message: "play-board URL unavailable", source: "supabase_config")
            return nil
        }
        // Client Sync never forces Edge Odds refresh — Edge TTL owns Odds quota.
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                logFetchFailure(
                    message: "play-board returned an unsuccessful response",
                    source: "supabase_http",
                    statusCode: (response as? HTTPURLResponse)?.statusCode
                )
                return boundedStaleFallback()
            }
            let decoded = try JSONDecoder().decode(SupabasePlayBoardResponse.self, from: data)
            saveClientCache(decoded, raw: data)
            return decoded
        } catch {
            logFetchFailure(message: "play-board request failed: \(error.localizedDescription)", source: "supabase_request")
            return boundedStaleFallback()
        }
    }

    static func clearClientBoardCache() {
        cacheLock.lock()
        memoryCache = nil
        cacheLock.unlock()
        UserDefaults.standard.removeObject(forKey: diskCacheKey)
    }

    private static func boundedStaleFallback() -> SupabasePlayBoardResponse? {
        guard let cached = loadClientCache() else { return nil }
        return cachePolicy.staleResponse(cached.response, savedAt: cached.savedAt, now: .now)
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

    private static func logFetchFailure(message: String, source: String, statusCode: Int? = nil) {
        var extra: [String: AnalyticsValue] = ["source": .string(source)]
        if let statusCode {
            extra["status_code"] = .int(statusCode)
        }
        AppErrorLogger.log(
            severity: .warning,
            message: String(message.prefix(300)),
            screen: "play",
            extra: extra
        )
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
        guard let session = await SupabaseAuthService.restoreSession(), session.userId == userId else {
            return nil
        }

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
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
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
