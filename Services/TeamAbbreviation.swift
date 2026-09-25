import Foundation

/// Maps Odds API / book full team names to short codes for compact Play tiles (H2H buttons, matchups).
enum TeamAbbreviation {
    /// Prefer a known league abbreviation; fall back to a compact token from the full name.
    static func abbreviate(_ name: String, leagueTag: String? = nil, sportKey: String? = nil) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if looksLikeAbbreviation(trimmed) { return trimmed.uppercased() }

        let key = normalize(trimmed)
        let league = resolvedLeague(tag: leagueTag, sportKey: sportKey)

        if let league, let table = tables[league], let hit = table[key] {
            return hit
        }
        for table in tables.values {
            if let hit = table[key] { return hit }
        }
        return fallbackToken(trimmed)
    }

    /// Abbreviate both sides of `"Away @ Home"` / `"Away vs Home"` matchup strings.
    static func abbreviateMatchup(_ matchup: String, leagueTag: String? = nil, sportKey: String? = nil) -> String {
        let trimmed = matchup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let separators = [" @ ", " vs ", " VS ", " Vs ", " v ", " V "]
        for sep in separators {
            if let range = trimmed.range(of: sep) {
                let away = String(trimmed[..<range.lowerBound])
                let home = String(trimmed[range.upperBound...])
                let displaySep = sep.lowercased().contains("vs") || sep.lowercased().contains(" v ")
                    ? " vs "
                    : " @ "
                return "\(abbreviate(away, leagueTag: leagueTag, sportKey: sportKey))\(displaySep)\(abbreviate(home, leagueTag: leagueTag, sportKey: sportKey))"
            }
        }
        return abbreviate(trimmed, leagueTag: leagueTag, sportKey: sportKey)
    }

    // MARK: - Internals

    private static func looksLikeAbbreviation(_ s: String) -> Bool {
        let u = s.uppercased()
        guard u.count <= 4, u.rangeOfCharacter(from: .letters) != nil else { return false }
        return u.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolvedLeague(tag: String?, sportKey: String?) -> String? {
        if let tag {
            switch tag.uppercased() {
            case "NFL": return "NFL"
            case "NBA": return "NBA"
            case "MLB": return "MLB"
            case "NHL": return "NHL"
            case "CFB", "NCAAF": return "CFB"
            case "CBB", "MBB", "NCAAB": return "CBB"
            default: break
            }
        }
        if let sportKey {
            if sportKey.contains("nfl") { return "NFL" }
            if sportKey.contains("nba") { return "NBA" }
            if sportKey.contains("mlb") { return "MLB" }
            if sportKey.contains("nhl") { return "NHL" }
            if sportKey.contains("ncaaf") || sportKey.contains("americanfootball_ncaaf") { return "CFB" }
            if sportKey.contains("ncaab") || sportKey.contains("basketball_ncaab") { return "CBB" }
        }
        return nil
    }

    /// Last-resort short label when the team isn't in the tables (e.g. obscure CFB).
    private static func fallbackToken(_ name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return String(name.prefix(3)).uppercased() }
        if parts.count == 1 {
            return String(parts[0].prefix(3)).uppercased()
        }
        // City + mascot → first letters of last two tokens when city is multi-word is messy;
        // prefer last token (mascot) truncated, or classic 3-letter from initials.
        let initials = parts.prefix(3).compactMap { $0.first.map(String.init) }.joined().uppercased()
        if initials.count >= 2 { return String(initials.prefix(3)) }
        return String(parts.last!.prefix(3)).uppercased()
    }

    private static let tables: [String: [String: String]] = [
        "NFL": nfl,
        "NBA": nba,
        "MLB": mlb,
        "NHL": nhl,
        "CFB": cfb,
        "CBB": cbb,
    ]

    private static let nfl: [String: String] = [
        "arizona cardinals": "ARI", "atlanta falcons": "ATL", "baltimore ravens": "BAL",
        "buffalo bills": "BUF", "carolina panthers": "CAR", "chicago bears": "CHI",
        "cincinnati bengals": "CIN", "cleveland browns": "CLE", "dallas cowboys": "DAL",
        "denver broncos": "DEN", "detroit lions": "DET", "green bay packers": "GB",
        "houston texans": "HOU", "indianapolis colts": "IND", "jacksonville jaguars": "JAX",
        "kansas city chiefs": "KC", "las vegas raiders": "LV", "oakland raiders": "LV",
        "los angeles chargers": "LAC", "san diego chargers": "LAC",
        "los angeles rams": "LAR", "st louis rams": "LAR", "miami dolphins": "MIA",
        "minnesota vikings": "MIN", "new england patriots": "NE", "new orleans saints": "NO",
        "new york giants": "NYG", "new york jets": "NYJ", "philadelphia eagles": "PHI",
        "pittsburgh steelers": "PIT", "san francisco 49ers": "SF", "seattle seahawks": "SEA",
        "tampa bay buccaneers": "TB", "tennessee titans": "TEN", "washington commanders": "WAS",
        "washington football team": "WAS", "washington redskins": "WAS",
    ]

    private static let nba: [String: String] = [
        "atlanta hawks": "ATL", "boston celtics": "BOS", "brooklyn nets": "BKN",
        "charlotte hornets": "CHA", "chicago bulls": "CHI", "cleveland cavaliers": "CLE",
        "dallas mavericks": "DAL", "denver nuggets": "DEN", "detroit pistons": "DET",
        "golden state warriors": "GSW", "houston rockets": "HOU", "indiana pacers": "IND",
        "la clippers": "LAC", "los angeles clippers": "LAC", "los angeles lakers": "LAL",
        "memphis grizzlies": "MEM", "miami heat": "MIA", "milwaukee bucks": "MIL",
        "minnesota timberwolves": "MIN", "new orleans pelicans": "NOP", "new york knicks": "NYK",
        "oklahoma city thunder": "OKC", "orlando magic": "ORL", "philadelphia 76ers": "PHI",
        "phoenix suns": "PHX", "portland trail blazers": "POR", "sacramento kings": "SAC",
        "san antonio spurs": "SAS", "toronto raptors": "TOR", "utah jazz": "UTA",
        "washington wizards": "WAS",
    ]

    private static let mlb: [String: String] = [
        "arizona diamondbacks": "ARI", "atlanta braves": "ATL", "baltimore orioles": "BAL",
        "boston red sox": "BOS", "chicago cubs": "CHC", "chicago white sox": "CWS",
        "cincinnati reds": "CIN", "cleveland guardians": "CLE", "cleveland indians": "CLE",
        "colorado rockies": "COL", "detroit tigers": "DET", "houston astros": "HOU",
        "kansas city royals": "KC", "los angeles angels": "LAA", "anaheim angels": "LAA",
        "los angeles dodgers": "LAD", "miami marlins": "MIA", "florida marlins": "MIA",
        "milwaukee brewers": "MIL", "minnesota twins": "MIN", "new york mets": "NYM",
        "new york yankees": "NYY", "oakland athletics": "OAK", "athletics": "OAK",
        "philadelphia phillies": "PHI", "pittsburgh pirates": "PIT", "san diego padres": "SD",
        "san francisco giants": "SF", "seattle mariners": "SEA", "st louis cardinals": "STL",
        "tampa bay rays": "TB", "texas rangers": "TEX", "toronto blue jays": "TOR",
        "washington nationals": "WSH",
    ]

    private static let nhl: [String: String] = [
        "anaheim ducks": "ANA", "arizona coyotes": "ARI", "utah hockey club": "UTA",
        "boston bruins": "BOS", "buffalo sabres": "BUF", "calgary flames": "CGY",
        "carolina hurricanes": "CAR", "chicago blackhawks": "CHI", "colorado avalanche": "COL",
        "columbus blue jackets": "CBJ", "dallas stars": "DAL", "detroit red wings": "DET",
        "edmonton oilers": "EDM", "florida panthers": "FLA", "los angeles kings": "LAK",
        "minnesota wild": "MIN", "montreal canadiens": "MTL", "nashville predators": "NSH",
        "new jersey devils": "NJD", "new york islanders": "NYI", "new york rangers": "NYR",
        "ottawa senators": "OTT", "philadelphia flyers": "PHI", "pittsburgh penguins": "PIT",
        "san jose sharks": "SJS", "seattle kraken": "SEA", "st louis blues": "STL",
        "tampa bay lightning": "TB", "toronto maple leafs": "TOR", "vancouver canucks": "VAN",
        "vegas golden knights": "VGK", "washington capitals": "WSH", "winnipeg jets": "WPG",
    ]

    /// Common Power-conference / ranked CFB — enough for H2H buttons; others use fallback.
    private static let cfb: [String: String] = [
        "alabama crimson tide": "ALA", "alabama": "ALA",
        "georgia bulldogs": "UGA", "georgia": "UGA",
        "ohio state buckeyes": "OSU", "ohio state": "OSU",
        "michigan wolverines": "MICH", "michigan": "MICH",
        "texas longhorns": "TEX", "texas": "TEX",
        "oregon ducks": "ORE", "oregon": "ORE",
        "penn state nittany lions": "PSU", "penn state": "PSU",
        "notre dame fighting irish": "ND", "notre dame": "ND",
        "usc trojans": "USC", "lsu tigers": "LSU", "lsu": "LSU",
        "florida state seminoles": "FSU", "florida state": "FSU",
        "clemson tigers": "CLEM", "clemson": "CLEM",
        "miami hurricanes": "MIA", "miami": "MIA",
        "tennessee volunteers": "TENN", "tennessee": "TENN",
        "oklahoma sooners": "OU", "oklahoma": "OU",
        "texas a&m aggies": "TA&M", "texas am aggies": "TA&M",
        "washington huskies": "UW", "florida gators": "FLA",
        "auburn tigers": "AUB", "wisconsin badgers": "WIS",
    ]

    private static let cbb: [String: String] = [
        "duke blue devils": "DUKE", "duke": "DUKE",
        "north carolina tar heels": "UNC", "north carolina": "UNC",
        "kentucky wildcats": "UK", "kentucky": "UK",
        "kansas jayhawks": "KU", "kansas": "KU",
        "uconn huskies": "CONN", "connecticut huskies": "CONN",
        "gonzaga bulldogs": "GONZ", "gonzaga": "GONZ",
        "houston cougars": "HOU", "houston": "HOU",
        "purdue boilermakers": "PUR", "purdue": "PUR",
        "arizona wildcats": "ARIZ", "arizona": "ARIZ",
    ]
}
