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
    static func fetchPlayBoard() async -> SupabasePlayBoardResponse? {
        guard let url = SupabaseConfig.edgeBaseURL?.appendingPathComponent("play-board") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(SupabasePlayBoardResponse.self, from: data)
        } catch {
            return nil
        }
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

