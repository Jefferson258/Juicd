import Foundation

/// One cached “live” line from The Odds API — **single HTTP request** per cold start when cache is stale
/// so you don’t burn free monthly quota while testing.
/// Docs: https://the-odds-api.com/liveapi/guides/v4/
struct LiveOddsLine: Equatable {
    let eventTitle: String
    let pickLabel: String
    let oddsDecimal: Double
    let sportKey: String
}

private struct CachePayload: Codable {
    let savedAt: Date
    let line: LineCodable
}

private struct LineCodable: Codable {
    let eventTitle: String
    let pickLabel: String
    let oddsDecimal: Double
    let sportKey: String
}

private struct OddsAPIEventDTO: Decodable {
    let home_team: String
    let away_team: String
    let bookmakers: [OddsAPIBookmakerDTO]?
}

private struct OddsAPIBookmakerDTO: Decodable {
    let markets: [OddsAPIMarketDTO]?
}

private struct OddsAPIMarketDTO: Decodable {
    let key: String
    let outcomes: [OddsAPIOutcomeDTO]?
}

private struct OddsAPIOutcomeDTO: Decodable {
    let name: String
    let price: Double
}

enum TheOddsAPIService {
    private static let cacheKey = "juicd_the_odds_api_one_line_v1"
    /// Don’t refetch more than once per app process (plus UserDefaults TTL).
    private static var didFetchThisSession = false

    /// Cache duration: 1 hour — keeps UI fresh without hammering the API during dev.
    private static let cacheTTL: TimeInterval = 3600

    /// Fetches **at most one** odds line per app session when key + network; otherwise returns cache or nil.
    static func fetchOneCachedLine(sportKey: String = "americanfootball_nfl") async -> LiveOddsLine? {
        if let hit = loadDiskCache(), Date().timeIntervalSince(hit.savedAt) < cacheTTL {
            return hit.line
        }
        guard OddsAPIConfig.isConfigured else { return loadDiskCache()?.line }
        guard !didFetchThisSession else { return loadDiskCache()?.line }
        didFetchThisSession = true

        let key = OddsAPIConfig.apiKey
        var components = URLComponents(string: "https://api.the-odds-api.com/v4/sports/\(sportKey)/odds/")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: key),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "markets", value: "h2h"),
            URLQueryItem(name: "oddsFormat", value: "decimal")
        ]
        guard let url = components.url else { return loadDiskCache()?.line }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return loadDiskCache()?.line
            }
            let events = try JSONDecoder().decode([OddsAPIEventDTO].self, from: data)
            guard let first = events.first else { return loadDiskCache()?.line }
            let title = "\(first.away_team) @ \(first.home_team)"
            guard
                let book = first.bookmakers?.first,
                let market = book.markets?.first(where: { $0.key == "h2h" }),
                let outcome = market.outcomes?.first
            else { return loadDiskCache()?.line }

            let line = LiveOddsLine(
                eventTitle: title,
                pickLabel: outcome.name,
                oddsDecimal: outcome.price,
                sportKey: sportKey
            )
            saveDiskCache(line)
            return line
        } catch {
            return loadDiskCache()?.line
        }
    }

    private static func loadDiskCache() -> (savedAt: Date, line: LiveOddsLine)? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else { return nil }
        let line = LiveOddsLine(
            eventTitle: payload.line.eventTitle,
            pickLabel: payload.line.pickLabel,
            oddsDecimal: payload.line.oddsDecimal,
            sportKey: payload.line.sportKey
        )
        return (payload.savedAt, line)
    }

    private static func saveDiskCache(_ line: LiveOddsLine) {
        let payload = CachePayload(
            savedAt: Date(),
            line: LineCodable(
                eventTitle: line.eventTitle,
                pickLabel: line.pickLabel,
                oddsDecimal: line.oddsDecimal,
                sportKey: line.sportKey
            )
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
