import Foundation
import UIKit

/// Resolve PrizePicks-style player busts from a name + league.
///
/// The Odds API does **not** ship photos. This uses ESPN’s public search + CDN
/// (unofficial, no partnership) and falls back to TheSportsDB’s free player
/// cutouts. IDs and image bytes are cached on disk so a board refresh does not
/// re-hit the network.
enum PlayerHeadshotLookup {
    static func foldedName(_ raw: String) -> String {
        raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cacheKey(name: String, leagueTag: String) -> String {
        "\(foldedName(name))|\(leagueTag.uppercased())"
    }

    static func shouldLookup(name: String, leagueTag: String, propDescription: String) -> Bool {
        let desc = propDescription.lowercased()
        if desc.contains("moneyline") || desc == "h2h" { return false }
        let n = foldedName(name)
        if n.isEmpty { return false }
        if n.range(of: #"^nba player \d+$"#, options: .regularExpression) != nil { return false }
        if n.range(of: #"player \d+$"#, options: .regularExpression) != nil { return false }
        _ = leagueTag
        return true
    }

    static func espnHeadshotPath(leagueSlug: String) -> String? {
        switch leagueSlug.lowercased() {
        case "nba": return "nba"
        case "nfl": return "nfl"
        case "mlb": return "mlb"
        case "nhl": return "nhl"
        case "wnba": return "wnba"
        case "mens-college-basketball", "womens-college-basketball": return leagueSlug.lowercased()
        default: return nil
        }
    }

    static func wantedEspnLeague(for tag: String) -> Set<String> {
        switch tag.uppercased() {
        case "NBA": return ["nba"]
        case "NFL": return ["nfl"]
        case "MLB": return ["mlb"]
        case "NHL": return ["nhl"]
        case "WNBA": return ["wnba"]
        case "CBB", "MBB": return ["mens-college-basketball", "ncaam"]
        case "NWSL", "WSL", "EPL", "UCL", "MLS", "SOC": return ["soccer", "eng.1", "usa.1", "uefa.champions"]
        default: return []
        }
    }
}

actor PlayerHeadshotStore {
    static let shared = PlayerHeadshotStore()

    private struct Index: Codable {
        var urls: [String: String] = [:]
        var misses: [String: Double] = [:]
    }

    private var index: Index
    private let session: URLSession
    private let indexURL: URL
    private let missTTL: TimeInterval = 7 * 24 * 60 * 60

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("juicd-headshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        indexURL = dir.appendingPathComponent("index.json")
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode(Index.self, from: data) {
            index = decoded
        } else {
            index = Index()
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 80 * 1024 * 1024,
            directory: dir.appendingPathComponent("urlcache", isDirectory: true)
        )
        session = URLSession(configuration: config)
    }

    func imageData(name: String, leagueTag: String, propDescription: String) async -> Data? {
        guard PlayerHeadshotLookup.shouldLookup(
            name: name,
            leagueTag: leagueTag,
            propDescription: propDescription
        ) else { return nil }

        let key = PlayerHeadshotLookup.cacheKey(name: name, leagueTag: leagueTag)
        if let urlStr = index.urls[key], let data = await download(urlStr) {
            return data
        }
        if let missAt = index.misses[key],
           Date().timeIntervalSince1970 - missAt < missTTL {
            return nil
        }
        return await resolve(name: name, leagueTag: leagueTag, key: key)
    }

    private func resolve(name: String, leagueTag: String, key: String) async -> Data? {
        let espn = await searchESPN(name: name, leagueTag: leagueTag)
        let sportsDB = espn == nil ? await searchSportsDB(name: name) : nil
        if let url = espn ?? sportsDB,
           let data = await download(url.absoluteString),
           !data.isEmpty {
            index.urls[key] = url.absoluteString
            index.misses.removeValue(forKey: key)
            persistIndex()
            return data
        }
        index.misses[key] = Date().timeIntervalSince1970
        persistIndex()
        return nil
    }

    private func persistIndex() {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func searchESPN(name: String, leagueTag: String) async -> URL? {
        let wanted = PlayerHeadshotLookup.wantedEspnLeague(for: leagueTag)
        let folded = PlayerHeadshotLookup.foldedName(name)
        if let fromV2 = await espnSearchV2(query: name, folded: folded, wanted: wanted) {
            return fromV2
        }
        return await espnSearchV3(query: name, folded: folded, wanted: wanted)
    }

    private func espnSearchV2(query: String, folded: String, wanted: Set<String>) async -> URL? {
        var comps = URLComponents(string: "https://site.web.api.espn.com/apis/search/v2")
        comps?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "8"),
        ]
        guard let url = comps?.url,
              let data = await fetch(url),
              let decoded = try? JSONDecoder().decode(ESPNSearchV2.self, from: data)
        else { return nil }

        let players = (decoded.results ?? []).filter { $0.type == "player" }.flatMap { $0.contents ?? [] }
        let ranked = players.sorted { a, b in
            score(name: a.displayName, desc: a.description, folded: folded, wanted: wanted)
                > score(name: b.displayName, desc: b.description, folded: folded, wanted: wanted)
        }
        for item in ranked.prefix(4) {
            if let raw = item.image?.defaultURL, let u = URL(string: raw) { return u }
        }
        return nil
    }

    private func espnSearchV3(query: String, folded: String, wanted: Set<String>) async -> URL? {
        var comps = URLComponents(string: "https://site.web.api.espn.com/apis/common/v3/search")
        comps?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "8"),
            URLQueryItem(name: "type", value: "player"),
        ]
        guard let url = comps?.url,
              let data = await fetch(url),
              let decoded = try? JSONDecoder().decode(ESPNSearchV3.self, from: data)
        else { return nil }

        let ranked = (decoded.items ?? []).sorted { a, b in
            score(name: a.displayName, desc: a.league, folded: folded, wanted: wanted)
                > score(name: b.displayName, desc: b.league, folded: folded, wanted: wanted)
        }
        for item in ranked.prefix(4) {
            guard let id = item.id else { continue }
            let slug = (item.league ?? "").lowercased()
            if let path = PlayerHeadshotLookup.espnHeadshotPath(leagueSlug: slug) {
                return URL(string: "https://a.espncdn.com/i/headshots/\(path)/players/full/\(id).png")
            }
        }
        return nil
    }

    private func searchSportsDB(name: String) async -> URL? {
        var comps = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/3/searchplayers.php")
        comps?.queryItems = [URLQueryItem(name: "p", value: name)]
        guard let url = comps?.url,
              let data = await fetch(url),
              let decoded = try? JSONDecoder().decode(SportsDBSearch.self, from: data)
        else { return nil }
        let folded = PlayerHeadshotLookup.foldedName(name)
        let hit = (decoded.player ?? []).first { PlayerHeadshotLookup.foldedName($0.strPlayer ?? "") == folded }
            ?? decoded.player?.first
        if let cut = hit?.strCutout, let u = URL(string: cut), !cut.isEmpty { return u }
        if let thumb = hit?.strThumb, let u = URL(string: thumb), !thumb.isEmpty { return u }
        return nil
    }

    private func score(name: String?, desc: String?, folded: String, wanted: Set<String>) -> Int {
        var s = 0
        let n = PlayerHeadshotLookup.foldedName(name ?? "")
        if n == folded { s += 10 }
        else if n.contains(folded) || folded.contains(n) { s += 4 }
        let d = (desc ?? "").lowercased()
        if wanted.contains(where: { d.contains($0) }) { s += 8 }
        return s
    }

    private func download(_ urlStr: String) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        return await fetch(url)
    }

    private func fetch(_ url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("application/json,image/png,image/jpeg,*/*", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(status), !data.isEmpty else { return nil }
            return data
        } catch {
            return nil
        }
    }
}

private struct ESPNSearchV2: Decodable {
    let results: [Block]?
    struct Block: Decodable {
        let type: String?
        let contents: [Content]?
    }
    struct Content: Decodable {
        let displayName: String?
        let description: String?
        let image: Image?
    }
    struct Image: Decodable {
        let defaultURL: String?
        enum CodingKeys: String, CodingKey { case defaultURL = "default" }
    }
}

private struct ESPNSearchV3: Decodable {
    let items: [Item]?
    struct Item: Decodable {
        let id: String?
        let displayName: String?
        let league: String?
        let sport: String?
    }
}

private struct SportsDBSearch: Decodable {
    let player: [Player]?
    struct Player: Decodable {
        let strPlayer: String?
        let strCutout: String?
        let strThumb: String?
    }
}
