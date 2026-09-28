import Foundation

// MARK: - Sport pills (Play tab)

enum PlaySportPill: String, CaseIterable, Identifiable {
    /// Home feed with multiple “Popular …” ribbons (not a third-party trademark).
    case forYou
    case nba
    case nfl
    case cfb
    case mlb
    case nhl
    case cbb
    case mbb
    case womensSoccer
    case soccer
    case ufc
    case mls
    case wnba

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .forYou: return "Popular"
        case .nba: return "NBA"
        case .nfl: return "NFL"
        case .cfb: return "CFB"
        case .mlb: return "MLB"
        case .nhl: return "NHL"
        case .cbb: return "CBB"
        case .mbb: return "MBB"
        case .womensSoccer: return "WSOC"
        case .soccer: return "SOC"
        case .ufc: return "UFC"
        case .mls: return "MLS"
        case .wnba: return "WNBA"
        }
    }

    /// Primary row: board order first, then remaining leagues.
    static var primaryRow: [PlaySportPill] {
        [.forYou, .nfl, .cfb, .nba, .mlb, .nhl, .ufc, .mls, .wnba, .cbb, .mbb, .womensSoccer, .soccer]
    }

    /// Ribbon header chevron: jump into this league’s board.
    static func sportPill(forRibbonId ribbonId: String) -> PlaySportPill? {
        switch ribbonId {
        case "popular_nba", "nba": return .nba
        case "popular_nfl", "nfl": return .nfl
        case "popular_cfb", "cfb", "ncaaf": return .cfb
        case "popular_mlb", "mlb": return .mlb
        case "popular_nhl", "nhl": return .nhl
        case "popular_cbb", "cbb": return .cbb
        case "popular_mbb", "mbb": return .mbb
        case "popular_wsoc", "womens_soccer": return .womensSoccer
        case "popular_soccer", "soccer": return .soccer
        case "popular_ufc", "ufc", "mma": return .ufc
        case "popular_mls", "mls": return .mls
        case "popular_wnba", "wnba": return .wnba
        case "live_api": return nil
        default:
            if ribbonId.hasPrefix("live_nfl") || ribbonId.hasPrefix("live_props_nfl") { return .nfl }
            if ribbonId.hasPrefix("live_cfb") || ribbonId.hasPrefix("live_props_cfb") { return .cfb }
            if ribbonId.hasPrefix("live_nba") || ribbonId.hasPrefix("live_props_nba") { return .nba }
            if ribbonId.hasPrefix("live_mlb") || ribbonId.hasPrefix("live_props_mlb") { return .mlb }
            if ribbonId.hasPrefix("live_nhl") || ribbonId.hasPrefix("live_props_nhl") { return .nhl }
            if ribbonId.hasPrefix("live_ufc") || ribbonId.hasPrefix("live_props_ufc") { return .ufc }
            if ribbonId.hasPrefix("live_mls") || ribbonId.hasPrefix("live_props_mls") { return .mls }
            if ribbonId.hasPrefix("live_wnba") || ribbonId.hasPrefix("live_props_wnba") { return .wnba }
            return nil
        }
    }

    func matchesLeagueTag(_ tag: String) -> Bool {
        let u = tag.uppercased()
        switch self {
        case .forYou: return true
        case .nba: return u == "NBA"
        case .nfl: return u == "NFL"
        case .cfb: return u == "CFB" || u == "NCAAF"
        case .mlb: return u == "MLB"
        case .nhl: return u == "NHL"
        case .cbb: return u == "CBB"
        case .mbb: return u == "MBB"
        case .womensSoccer: return u == "NWSL" || u == "WSL"
        case .soccer: return ["EPL", "UCL", "SOC"].contains(u)
        case .ufc: return u == "UFC" || u == "MMA"
        case .mls: return u == "MLS"
        case .wnba: return u == "WNBA"
        }
    }

    /// Second-row stat / market filters (PrizePicks-style). `id` matches `PlayPropBet.statFilterKey`.
    var statPillOptions: [(id: String, label: String)] {
        switch self {
        case .forYou:
            return []
        case .nba, .cbb, .mbb:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("points", "Points"),
                ("rebounds", "Rebounds"),
                ("assists", "Assists"),
                ("combo", "Pts+Rebs+Asts"),
                ("threes", "Threes"),
                ("blocks", "Blocks")
            ]
        case .nfl, .cfb:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("pass_yards", "Pass yards"),
                ("rush_yards", "Rush yards"),
                ("rec_yards", "Rec yards"),
                ("receptions", "Receptions"),
                ("pass_td", "Pass TDs"),
                ("combo_yards", "Rush+rec yards")
            ]
        case .mlb:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("hits", "Hits"),
                ("home_runs", "Home runs"),
                ("strikeouts", "Strikeouts"),
                ("total_bases", "Total bases")
            ]
        case .nhl:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("goals", "Goals"),
                ("points", "Points"),
                ("assists", "Assists"),
                ("shots", "Shots"),
                ("saves", "Saves")
            ]
        case .womensSoccer, .soccer, .mls:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("goals", "Goals"),
                ("shots", "Shots"),
                ("totals", "Totals"),
                ("corners", "Corners"),
                ("cards", "Cards")
            ]
        case .ufc:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("moneyline", "Moneyline")
            ]
        case .wnba:
            return [
                ("all", "All"),
                ("popular", "Popular"),
                ("points", "Points"),
                ("rebounds", "Rebounds"),
                ("assists", "Assists"),
                ("combo", "Pts+Rebs+Asts"),
                ("threes", "Threes"),
                ("blocks", "Blocks")
            ]
        }
    }
}

// MARK: - Stat key derived from stub / API prop text

extension PlayPropBet {
    /// Normalized key aligned with `PlaySportPill.statPillOptions` ids.
    var statFilterKey: String {
        let p = propDescription.lowercased()
        let t = leagueTag.uppercased()

        switch t {
        case "NFL", "CFB", "NCAAF":
            if p.contains("rush") && p.contains("rec") && p.contains("yard") { return "combo_yards" }
            if p.contains("pass") && p.contains("yard") { return "pass_yards" }
            if p.contains("rush") && p.contains("yard") { return "rush_yards" }
            if p.contains("rec") && p.contains("yard") { return "rec_yards" }
            if p.contains("reception") { return "receptions" }
            if p.contains("pass") && p.contains("td") { return "pass_td" }
            return "other"
        case "MLB":
            if p.contains("strikeout") { return "strikeouts" }
            if p.contains("home run") { return "home_runs" }
            if p.contains("hits") && p.contains("rbis") { return "hits" }
            if p.contains("hit") && !p.contains("+") { return "hits" }
            if p.contains("total base") { return "total_bases" }
            return "other"
        case "NHL":
            if p.contains("save") { return "saves" }
            if p.contains("shot") { return "shots" }
            if p.contains("goal") && !p.contains("against") { return "goals" }
            if p.contains("assist") { return "assists" }
            if p.contains("point") { return "points" }
            return "other"
        case "EPL", "UCL", "MLS", "NWSL", "WSL", "SOC":
            if p.contains("both teams") { return "totals" }
            if p.contains("yellow card") || (p.contains("card") && !p.contains("corner")) { return "cards" }
            if p.contains("corner") { return "corners" }
            if p.contains("card") { return "cards" }
            if p.contains("total goal") { return "totals" }
            if p.contains("shot") { return "shots" }
            if p.contains("goal") || p.contains("anytime") { return "goals" }
            return "other"
        case "UFC", "MMA":
            if p.contains("moneyline") || p.contains("h2h") || p.contains("head-to-head") { return "moneyline" }
            return "other"
        case "NBA", "CBB", "MBB", "WNBA":
            if p.contains("point") && (p.contains("+") || p.contains("pra")) { return "combo" }
            if p.contains("rebound") { return "rebounds" }
            if p.contains("assist") { return "assists" }
            if p.contains("three") || p.contains("made three") { return "threes" }
            if p.contains("block") { return "blocks" }
            if p.contains("point") { return "points" }
            return "other"
        default:
            return "other"
        }
    }

    /// Prototype: “Popular” keeps most standard player props so dev filters stay populated.
    var isPopularStyleLine: Bool {
        if isMoneylineStyle || hasMoneylineChoice { return true }
        if statFilterKey != "other" { return true }
        let p = propDescription.lowercased()
        return p.contains("completion")
            || p.contains("anytime")
            || p.contains("rbis")
            || p.contains("both teams")
            || p.contains("moneyline")
            || p.contains("head-to-head")
            || p.contains("h2h")
    }
}
