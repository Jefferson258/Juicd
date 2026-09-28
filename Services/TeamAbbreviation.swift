import Foundation

/// Maps Odds API / book full team names to short codes for compact Play tiles (H2H buttons, matchups).
enum TeamAbbreviation {
    /// Prefer a known league abbreviation; fall back to a compact token from the full name.
    static func abbreviate(_ name: String, leagueTag: String? = nil, sportKey: String? = nil) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let league = resolvedLeague(tag: leagueTag, sportKey: sportKey)

        // Already-short tokens: pro leagues keep codes (NYY/BAL); CFB/CBB expand to mid names when known.
        if looksLikeAbbreviation(trimmed) {
            let code = trimmed.uppercased()
            if league == "CFB", let mid = cfbCodeToMid[code] { return mid }
            if league == "CBB", let mid = cbbCodeToMid[code] { return mid }
            return code
        }

        let key = normalize(trimmed)

        if let league, let table = tables[league], let hit = table[key] {
            return hit
        }
        for table in tables.values {
            if let hit = table[key] { return hit }
        }
        return fallbackToken(trimmed, league: league)
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
            case "UFC", "MMA": return "UFC"
            case "MLS": return "MLS"
            case "WNBA": return "WNBA"
            default: break
            }
        }
        if let sportKey {
            if sportKey.contains("ncaaf") { return "CFB" }
            if sportKey.contains("nfl") { return "NFL" }
            if sportKey.contains("wnba") { return "WNBA" }
            if sportKey.contains("nba") { return "NBA" }
            if sportKey.contains("mlb") { return "MLB" }
            if sportKey.contains("nhl") { return "NHL" }
            if sportKey.contains("ncaab") || sportKey.contains("basketball_ncaab") { return "CBB" }
            if sportKey.contains("mma") || sportKey.contains("ufc") { return "UFC" }
            if sportKey.contains("soccer_usa_mls") || sportKey.hasSuffix("_mls") { return "MLS" }
        }
        return nil
    }

    /// Last-resort label when the team isn't in the tables.
    /// CFB/CBB prefer a readable school nickname (drop mascot); pro leagues keep short codes.
    private static func fallbackToken(_ name: String, league: String?) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return String(name.prefix(3)).uppercased() }

        if league == "CFB" || league == "CBB" {
            return collegeMidName(parts)
        }
        if league == "UFC" {
            // Fighters: last name if multi-token, else as-is.
            return parts.count >= 2 ? parts.last! : parts[0]
        }
        if parts.count == 1 {
            return String(parts[0].prefix(3)).uppercased()
        }
        let initials = parts.prefix(3).compactMap { $0.first.map(String.init) }.joined().uppercased()
        if initials.count >= 2 { return String(initials.prefix(3)) }
        return String(parts.last!.prefix(3)).uppercased()
    }

    /// "Alabama Crimson Tide" → "Alabama"; "Ohio State Buckeyes" → "Ohio State".
    private static func collegeMidName(_ parts: [String]) -> String {
        let mascots: Set<String> = [
            "tigers", "bulldogs", "wildcats", "crimson", "tide", "buckeyes", "wolverines",
            "longhorns", "ducks", "nittany", "lions", "fighting", "irish", "trojans",
            "seminoles", "hurricanes", "volunteers", "sooners", "aggies", "huskies",
            "gators", "badgers", "spartans", "hawkeyes", "jayhawks", "bearcats",
            "razorbacks", "gamecocks", "tar", "heels", "blue", "devils", "boilermakers",
            "cougars", "rebels", "bruins", "sun", "devils", "utes", "buffaloes",
            "mountaineers", "hokies", "cavaliers", "orange", "cardinal", "cardinals",
            "golden", "bears", "panthers", "eagles", "owls", "frogs", "horned",
            "mustangs", "red", "raiders", "cowboys", "cyclones", "huskers", "terrapins",
            "midshipmen", "black", "knights", "mean", "green", "thundering", "herd",
        ]
        var kept: [String] = []
        for p in parts {
            if mascots.contains(p.lowercased()) { break }
            kept.append(p)
        }
        if kept.isEmpty { return parts[0] }
        // Cap length for Play tiles (lineLimit 1).
        let joined = kept.joined(separator: " ")
        if joined.count <= 14 { return joined }
        return kept.prefix(2).joined(separator: " ")
    }

    private static let tables: [String: [String: String]] = [
        "NFL": nfl,
        "NBA": nba,
        "MLB": mlb,
        "NHL": nhl,
        "CFB": cfb,
        "CBB": cbb,
        "UFC": ufc,
        "MLS": mls,
        "WNBA": wnba,
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

    /// Mid-length CFB display names for Play tiles (not UA / not full "University of Alabama").
    private static let cfb: [String: String] = [
        "alabama crimson tide": "Alabama", "alabama": "Alabama", "university of alabama": "Alabama",
        "georgia bulldogs": "Georgia", "georgia": "Georgia", "university of georgia": "Georgia",
        "ohio state buckeyes": "Ohio State", "ohio state": "Ohio State", "ohio st": "Ohio State",
        "michigan wolverines": "Michigan", "michigan": "Michigan",
        "texas longhorns": "Texas", "texas": "Texas", "university of texas": "Texas",
        "oregon ducks": "Oregon", "oregon": "Oregon",
        "penn state nittany lions": "Penn State", "penn state": "Penn State", "penn st": "Penn State",
        "notre dame fighting irish": "Notre Dame", "notre dame": "Notre Dame",
        "usc trojans": "USC", "southern california": "USC", "southern cal": "USC",
        "lsu tigers": "LSU", "lsu": "LSU", "louisiana state": "LSU",
        "florida state seminoles": "Florida St", "florida state": "Florida St",
        "clemson tigers": "Clemson", "clemson": "Clemson",
        "miami hurricanes": "Miami", "miami": "Miami", "miami fl": "Miami",
        "tennessee volunteers": "Tennessee", "tennessee": "Tennessee",
        "oklahoma sooners": "Oklahoma", "oklahoma": "Oklahoma",
        "texas a&m aggies": "Texas A&M", "texas am aggies": "Texas A&M", "texas a&m": "Texas A&M",
        "washington huskies": "Washington", "washington": "Washington",
        "florida gators": "Florida", "florida": "Florida",
        "auburn tigers": "Auburn", "auburn": "Auburn",
        "wisconsin badgers": "Wisconsin", "wisconsin": "Wisconsin",
        "ole miss rebels": "Ole Miss", "ole miss": "Ole Miss", "mississippi": "Ole Miss",
        "mississippi state bulldogs": "Miss State", "mississippi state": "Miss State",
        "arkansas razorbacks": "Arkansas", "arkansas": "Arkansas",
        "missouri tigers": "Missouri", "missouri": "Missouri",
        "kentucky wildcats": "Kentucky", "kentucky": "Kentucky",
        "south carolina gamecocks": "S Carolina", "south carolina": "S Carolina",
        "iowa hawkeyes": "Iowa", "iowa": "Iowa",
        "iowa state cyclones": "Iowa State", "iowa state": "Iowa State",
        "michigan state spartans": "Mich State", "michigan state": "Mich State",
        "indiana hoosiers": "Indiana", "indiana": "Indiana",
        "illinois fighting illini": "Illinois", "illinois": "Illinois",
        "nebraska cornhuskers": "Nebraska", "nebraska": "Nebraska",
        "colorado buffaloes": "Colorado", "colorado": "Colorado",
        "utah utes": "Utah", "utah": "Utah",
        "arizona wildcats": "Arizona", "arizona": "Arizona",
        "arizona state sun devils": "Arizona St", "arizona state": "Arizona St",
        "baylor bears": "Baylor", "baylor": "Baylor",
        "tcu horned frogs": "TCU", "tcu": "TCU",
        "kansas jayhawks": "Kansas", "kansas": "Kansas",
        "kansas state wildcats": "Kansas St", "kansas state": "Kansas St",
        "oklahoma state cowboys": "Okla State", "oklahoma state": "Okla State",
        "west virginia mountaineers": "W Virginia", "west virginia": "W Virginia",
        "virginia tech hokies": "Va Tech", "virginia tech": "Va Tech",
        "north carolina tar heels": "N Carolina", "north carolina": "N Carolina",
        "nc state wolfpack": "NC State", "north carolina state": "NC State",
        "duke blue devils": "Duke", "duke": "Duke",
        "louisville cardinals": "Louisville", "louisville": "Louisville",
        "syracuse orange": "Syracuse", "syracuse": "Syracuse",
        "boston college eagles": "Boston Coll", "boston college": "Boston Coll",
        "pittsburgh panthers": "Pitt", "pittsburgh": "Pitt", "pitt": "Pitt",
        "rutgers scarlet knights": "Rutgers", "rutgers": "Rutgers",
        "maryland terrapins": "Maryland", "maryland": "Maryland",
        "ucla bruins": "UCLA", "ucla": "UCLA",
        "california golden bears": "Cal", "california": "Cal",
        "stanford cardinal": "Stanford", "stanford": "Stanford",
        "oregon state beavers": "Oregon St", "oregon state": "Oregon St",
        "washington state cougars": "Wash State", "washington state": "Wash State",
        "boise state broncos": "Boise St", "boise state": "Boise St",
        "byu cougars": "BYU", "byu": "BYU",
        "smu mustangs": "SMU", "smu": "SMU",
        "memphis tigers": "Memphis", "memphis": "Memphis",
        "cincinnati bearcats": "Cincinnati", "cincinnati": "Cincinnati",
        "ucf knights": "UCF", "ucf": "UCF", "central florida": "UCF",
        "georgia tech yellow jackets": "Ga Tech", "georgia tech": "Ga Tech",
        "vanderbilt commodores": "Vandy", "vanderbilt": "Vandy",
        "texas tech red raiders": "Texas Tech", "texas tech": "Texas Tech",
    ]

    /// Expand stub / Odds short CFB codes → mid display names.
    private static let cfbCodeToMid: [String: String] = [
        "ALA": "Alabama", "UA": "Alabama", "UGA": "Georgia", "GA": "Georgia",
        "OSU": "Ohio State", "OHIOST": "Ohio State", "MICH": "Michigan", "UM": "Michigan",
        "TEX": "Texas", "UT": "Texas", "ORE": "Oregon", "PSU": "Penn State",
        "ND": "Notre Dame", "USC": "USC", "LSU": "LSU", "FSU": "Florida St",
        "CLEM": "Clemson", "MIA": "Miami", "TENN": "Tennessee", "OU": "Oklahoma",
        "OKLA": "Oklahoma", "TAMU": "Texas A&M", "TA&M": "Texas A&M", "UW": "Washington",
        "FLA": "Florida", "UF": "Florida", "AUB": "Auburn", "WIS": "Wisconsin",
        "MISS": "Ole Miss", "MSST": "Miss State", "ARK": "Arkansas", "MIZ": "Missouri",
        "UK": "Kentucky", "SCAR": "S Carolina", "IOWA": "Iowa", "ISU": "Iowa State",
        "MSU": "Mich State", "IND": "Indiana", "ILL": "Illinois", "NEB": "Nebraska",
        "COLO": "Colorado", "UTAH": "Utah", "ARIZ": "Arizona", "ASU": "Arizona St",
        "BAY": "Baylor", "TCU": "TCU", "KU": "Kansas", "KSU": "Kansas St",
        "OKST": "Okla State", "WVU": "W Virginia", "VT": "Va Tech", "UNC": "N Carolina",
        "NCST": "NC State", "DUKE": "Duke", "LOU": "Louisville", "SYR": "Syracuse",
        "BC": "Boston Coll", "PITT": "Pitt", "RUT": "Rutgers", "MD": "Maryland",
        "UCLA": "UCLA", "CAL": "Cal", "STAN": "Stanford", "ORST": "Oregon St",
        "WSU": "Wash State", "BSU": "Boise St", "BYU": "BYU", "SMU": "SMU",
        "MEM": "Memphis", "CIN": "Cincinnati", "UCF": "UCF", "GT": "Ga Tech",
        "VAN": "Vandy", "TTU": "Texas Tech",
    ]

    private static let cbb: [String: String] = [
        "duke blue devils": "Duke", "duke": "Duke",
        "north carolina tar heels": "N Carolina", "north carolina": "N Carolina",
        "kentucky wildcats": "Kentucky", "kentucky": "Kentucky",
        "kansas jayhawks": "Kansas", "kansas": "Kansas",
        "uconn huskies": "UConn", "connecticut huskies": "UConn", "uconn": "UConn",
        "gonzaga bulldogs": "Gonzaga", "gonzaga": "Gonzaga",
        "houston cougars": "Houston", "houston": "Houston",
        "purdue boilermakers": "Purdue", "purdue": "Purdue",
        "arizona wildcats": "Arizona", "arizona": "Arizona",
    ]

    private static let cbbCodeToMid: [String: String] = [
        "DUKE": "Duke", "UNC": "N Carolina", "UK": "Kentucky", "KU": "Kansas",
        "CONN": "UConn", "UCONN": "UConn", "GONZ": "Gonzaga", "HOU": "Houston",
        "PUR": "Purdue", "ARIZ": "Arizona",
    ]

    private static let ufc: [String: String] = [:]

    private static let mls: [String: String] = [
        "inter miami cf": "Inter Miami", "inter miami": "Inter Miami",
        "la galaxy": "LA Galaxy", "los angeles galaxy": "LA Galaxy",
        "lafc": "LAFC", "los angeles fc": "LAFC",
        "seattle sounders fc": "Seattle", "seattle sounders": "Seattle",
        "atlanta united fc": "Atlanta", "atlanta united": "Atlanta",
        "new york city fc": "NYCFC", "nycfc": "NYCFC",
        "new york red bulls": "NY Red Bulls",
        "columbus crew": "Columbus", "austin fc": "Austin",
        "fc cincinnati": "Cincinnati", "portland timbers": "Portland",
        "minnesota united fc": "Minnesota", "orlando city sc": "Orlando",
        "philadelphia union": "Philadelphia", "chicago fire fc": "Chicago",
        "sporting kansas city": "Sporting KC", "real salt lake": "Salt Lake",
        "colorado rapids": "Colorado", "fc dallas": "Dallas",
        "houston dynamo fc": "Houston", "san jose earthquakes": "San Jose",
        "vancouver whitecaps fc": "Vancouver", "cf montreal": "Montreal",
        "toronto fc": "Toronto", "nashville sc": "Nashville",
        "charlotte fc": "Charlotte", "st louis city sc": "St Louis",
        "san diego fc": "San Diego",
    ]

    private static let wnba: [String: String] = [
        "las vegas aces": "Aces", "new york liberty": "Liberty",
        "connecticut sun": "Sun", "minnesota lynx": "Lynx",
        "seattle storm": "Storm", "phoenix mercury": "Mercury",
        "indiana fever": "Fever", "chicago sky": "Sky",
        "atlanta dream": "Dream", "dallas wings": "Wings",
        "washington mystics": "Mystics", "los angeles sparks": "Sparks",
        "golden state valkyries": "Valkyries",
    ]
}
