import Foundation

/// **Single integration point** for The Odds API on the Play tab once you add `ODDS_API_KEY`.
///
/// Today the UI uses `PlayBoardStubData`. When you are ready:
/// 1. Confirm which `markets` you need (player props vary by sport — see API docs).
/// 2. Parse `bookmakers[].markets[].outcomes[]` into `PlayPropBet` rows.
/// 3. In `PlayViewModel.refreshLiveOddsLine()`, merge the result into `ribbons` (e.g. replace the Popular ribbon or prepend a “Live” ribbon).
///
/// Docs: [The Odds API — Odds API](https://the-odds-api.com/liveapi/guides/v4/)
///
/// Example request shape (do not ship the key in client builds — use a backend proxy in production):
/// `GET https://api.the-odds-api.com/v4/sports/basketball_nba/odds/?apiKey=KEY&regions=us&oddsFormat=decimal&markets=player_points,player_rebounds`
enum TheOddsAPIPlayboardHook {
    /// Fetches live player-prop rows for the Play board. **Not implemented** — returns `nil` until you map the JSON.
    /// Wire this up once your key is in the target Info as `ODDS_API_KEY`.
    static func fetchPlayerPropsForSport(
        sportKey: String,
        markets: [String]
    ) async -> [PlayPropBet]? {
        guard OddsAPIConfig.isConfigured else { return nil }

        var components = URLComponents(
            string: "https://api.the-odds-api.com/v4/sports/\(sportKey)/odds/"
        )!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: OddsAPIConfig.apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "oddsFormat", value: "decimal"),
            URLQueryItem(name: "markets", value: markets.joined(separator: ","))
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 { return nil }
            _ = try JSONDecoder().decode([OddsAPIOddsEventDTO].self, from: data)
            // TODO: Map events + bookmaker markets to `PlayPropBet` (player name, line, Over/Under, decimal price).
            return nil
        } catch {
            return nil
        }
    }
}

// Minimal DTOs for decoding; extend when you implement mapping.
private struct OddsAPIOddsEventDTO: Decodable {
    let home_team: String?
    let away_team: String?
    let bookmakers: [OddsAPIBookmakerOddsDTO]?
}

private struct OddsAPIBookmakerOddsDTO: Decodable {
    let markets: [OddsAPIMarketOddsDTO]?
}

private struct OddsAPIMarketOddsDTO: Decodable {
    let key: String?
    let outcomes: [OddsAPIOutcomeOddsDTO]?
}

private struct OddsAPIOutcomeOddsDTO: Decodable {
    let name: String?
    let price: Double?
}
