import Foundation

/// Juicd day = America/Chicago, rolling at **4:00am CT**.
/// A 1:00am CT Aug 28 tip belongs to the **Aug 27** slate.
enum SlateDay {
    static let chicagoTimeZone = TimeZone(identifier: "America/Chicago")!

    private static var chicagoCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chicagoTimeZone
        return cal
    }

    static func slateKey(for date: Date = .now) -> String {
        let cal = chicagoCalendar
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
        if (comps.hour ?? 0) < 4, let y = comps.year, let m = comps.month, let d = comps.day,
           let dayStart = cal.date(from: DateComponents(year: y, month: m, day: d)),
           let prev = cal.date(byAdding: .day, value: -1, to: dayStart) {
            comps = cal.dateComponents([.year, .month, .day], from: prev)
        }
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func previousSlateKey(from date: Date = .now) -> String {
        let cal = chicagoCalendar
        let key = slateKey(for: date)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let prev = cal.date(byAdding: .day, value: -1, to: start) else {
            return key
        }
        return slateKey(for: cal.date(bySettingHour: 12, minute: 0, second: 0, of: prev) ?? prev)
    }

    static func nextSlateKey(from date: Date = .now) -> String {
        let cal = chicagoCalendar
        let key = slateKey(for: date)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let next = cal.date(byAdding: .day, value: 1, to: start) else {
            return key
        }
        return slateKey(for: cal.date(bySettingHour: 12, minute: 0, second: 0, of: next) ?? next)
    }

    /// Monday 4am CT through Sunday night. Key is that Monday’s slate date.
    static func calendarWeekKey(for date: Date = .now) -> String {
        let cal = chicagoCalendar
        let key = slateKey(for: date)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let day = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else {
            return key
        }
        let weekday = cal.component(.weekday, from: day) // 1 Sun … 2 Mon …
        let offset = (weekday + 5) % 7 // Mon=0 … Sun=6
        guard let mon = cal.date(byAdding: .day, value: -offset, to: day) else { return key }
        return slateKey(for: cal.date(bySettingHour: 12, minute: 0, second: 0, of: mon) ?? mon)
    }

    static func nextCalendarWeekKey(for date: Date = .now) -> String {
        let cal = chicagoCalendar
        let key = calendarWeekKey(for: date)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let start = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let next = cal.date(byAdding: .day, value: 7, to: start) else {
            return key
        }
        return slateKey(for: cal.date(bySettingHour: 12, minute: 0, second: 0, of: next) ?? next)
    }

    static func isSundayEarlyWeeklyWindow(for date: Date = .now) -> Bool {
        let cal = chicagoCalendar
        let key = slateKey(for: date)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let day = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else {
            return false
        }
        return cal.component(.weekday, from: day) == 1
    }

    /// Alias: weekly is Monday–Sunday (not Thursday NFL week).
    static func nflWeekKey(for date: Date = .now) -> String {
        calendarWeekKey(for: date)
    }
}

enum GameCountdown {
    static func remaining(until commence: Date, now: Date = .now) -> TimeInterval {
        max(0, commence.timeIntervalSince(now))
    }

    static func label(until commence: Date, now: Date = .now) -> String {
        let s = Int(remaining(until: commence, now: now).rounded(.down))
        if s <= 0 { return "Started" }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h >= 24 {
            let d = h / 24
            return "\(d)d \(h % 24)h"
        }
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s % 60) }
        return String(format: "%d:%02d", m, s % 60)
    }

    /// Full phrase for UI: `"Started"` or `"Starts in 1:02:03"`.
    static func phrase(until commence: Date, now: Date = .now) -> String {
        let s = Int(remaining(until: commence, now: now).rounded(.down))
        if s <= 0 { return "Started" }
        return "Starts in \(label(until: commence, now: now))"
    }
}

enum StableUUID {
    /// Deterministic UUID from a string (same input ⇒ same UUID everywhere).
    static func from(_ string: String) -> UUID {
        var h1: UInt64 = 14_695_981_039_346_656_037
        var h2: UInt64 = 10_995_813_932_069_621_371
        for u in string.utf8 {
            h1 = h1 &* 31 &+ UInt64(u)
            h2 = h2 &* 131 &+ UInt64(u) &* 17
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((h1 >> (i * 8)) & 0xFF)
            bytes[i + 8] = UInt8((h2 >> (i * 8)) & 0xFF)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

/// Fallback Play board when Supabase is down. Only future CT tips; empty sports omitted.
enum DailySlateBoard {
    static func ribbons(forSlateKey slateKey: String, sport: PlaySportPill, now: Date = .now) -> [PlayPropRibbon] {
        let cal = SlateDay.chicagoTimeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cal
        let parts = slateKey.split(separator: "-").compactMap { Int($0) }
        let evening: Date = {
            if parts.count == 3,
               let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 19, minute: 10)) {
                return day
            }
            return now.addingTimeInterval(6 * 3600)
        }()
        let later = evening.addingTimeInterval(3 * 3600)

        let base: [PlayPropRibbon]
        switch sport {
        case .forYou:
            base = PlayBoardStubData.forYouRibbons
        default:
            guard let r = PlayBoardStubData.sportRibbon(for: sport) else { return [] }
            base = [r]
        }
        let allowed: Set<String> = ["NFL", "NBA", "NHL", "MLB"]
        return base.compactMap { ribbon in
            var r = ribbon
            r.props = ribbon.props.enumerated().compactMap { idx, p in
                guard allowed.contains(p.leagueTag.uppercased()) else { return nil }
                var q = p
                q.id = StableUUID.from("\(slateKey)|\(ribbon.id)|\(idx)|\(p.pickLabel)")
                q.commenceTime = idx.isMultiple(of: 2) ? evening : later
                q.eventId = "stub-\(ribbon.id)-\(idx / 2)"
                q.sportKey = sportKey(for: q.leagueTag)
                if q.pointLine == nil {
                    let digits = q.lineText.filter { $0.isNumber || $0 == "." }
                    q.pointLine = Double(digits)
                }
                return q.commenceTime.map { $0 > now } == true ? q : nil
            }
            return r.props.isEmpty ? nil : r
        }
    }

    private static func sportKey(for tag: String) -> String {
        switch tag.uppercased() {
        case "NFL": return "americanfootball_nfl"
        case "NBA": return "basketball_nba"
        case "NHL": return "icehockey_nhl"
        case "MLB": return "baseball_mlb"
        default: return ""
        }
    }
}

enum TourneySlateBuilder {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func daily(from props: [PlayPropBet], slateKey: String) -> RemoteTourneyPayload? {
        payload(kind: "daily", periodKey: slateKey, title: "Daily closest-pick", props: props, preferSameEvent: true)
    }

    static func weekly(from props: [PlayPropBet], weekKey: String) -> RemoteTourneyPayload? {
        payload(kind: "weekly", periodKey: weekKey, title: "Weekly closest-pick", props: props, preferSameEvent: false)
    }

    private static func payload(
        kind: String,
        periodKey: String,
        title: String,
        props: [PlayPropBet],
        preferSameEvent: Bool
    ) -> RemoteTourneyPayload? {
        let overs = props.filter {
            ($0.pickLabel == "Over" || $0.pickLabel == "O/U" || $0.hasOverUnderChoice)
                && $0.eventId != nil && $0.commenceTime != nil && numericLine(from: $0) != nil
        }
        var byEvent: [String: [PlayPropBet]] = [:]
        for p in overs {
            guard let id = p.eventId else { continue }
            byEvent[id, default: []].append(p)
        }
        var chosen: [PlayPropBet] = []
        if preferSameEvent, let best = byEvent.values.max(by: { $0.count < $1.count }) {
            chosen = Array(best.prefix(4))
        }
        if chosen.count < 4 {
            let ordered = byEvent.values.sorted { ($0.first?.commenceTime ?? .distantFuture) < ($1.first?.commenceTime ?? .distantFuture) }
            for list in ordered {
                guard let first = list.first, !chosen.contains(where: { $0.eventId == first.eventId }) else { continue }
                chosen.append(first)
                if chosen.count >= 4 { break }
            }
        }
        if chosen.count < 4 {
            for p in overs where !chosen.contains(where: { $0.id == p.id }) {
                chosen.append(p)
                if chosen.count >= 4 { break }
            }
        }
        var rounds = chosen.compactMap { roundFromOver($0) }
        if rounds.count < 4 {
            var seen = Set(rounds.map(\.eventId))
            for p in props where (p.propDescription.lowercased().contains("moneyline") || p.propDescription.lowercased().contains("h2h")) {
                guard let id = p.eventId, let commence = p.commenceTime, !seen.contains(id) else { continue }
                seen.insert(id)
                rounds.append(
                    RemoteTourneyRound(
                        round: rounds.count + 1,
                        propLabel: "\(p.matchup) — combined score",
                        statSummary: "Closest to the final combined score (both teams).",
                        line: nil,
                        eventId: id,
                        matchup: p.matchup,
                        player: "Combined score",
                        commenceTime: iso.string(from: commence),
                        sportKey: p.sportKey ?? ""
                    )
                )
                if rounds.count >= 4 { break }
            }
        }
        guard rounds.count >= 2 else { return nil }
        let numbered = rounds.prefix(4).enumerated().map { i, r in
            var copy = r
            copy.round = i + 1
            return copy
        }
        let earliestCommence = numbered
            .compactMap { ISO8601DateFormatter().date(from: $0.commenceTime) }
            .min()
        let commenceISO: String = {
            if let earliestCommence {
                return iso.string(from: earliestCommence)
            }
            return numbered[0].commenceTime
        }()
        let same = numbered.allSatisfy { $0.matchup == numbered[0].matchup }
        return RemoteTourneyPayload(
            kind: kind,
            periodKey: periodKey,
            title: title,
            gameLabel: same ? numbered[0].matchup : "\(numbered.count) games",
            commenceTime: commenceISO,
            // Freeze when the earliest slate game starts (same discipline as Play).
            freezeAt: commenceISO,
            roundSpecs: numbered
        )
    }

    private static func roundFromOver(_ p: PlayPropBet) -> RemoteTourneyRound? {
        guard let line = numericLine(from: p), let id = p.eventId, let commence = p.commenceTime else { return nil }
        return RemoteTourneyRound(
            round: 1,
            propLabel: "\(p.athleteOrTeam) — \(p.propDescription)",
            statSummary: "Closest to actual \(p.propDescription.lowercased()) (\(p.matchup)). Line \(p.lineText).",
            line: line,
            eventId: id,
            matchup: p.matchup,
            player: p.athleteOrTeam,
            commenceTime: iso.string(from: commence),
            sportKey: p.sportKey ?? ""
        )
    }

    private static func numericLine(from p: PlayPropBet) -> Double? {
        if let line = p.pointLine { return line }
        let digits = p.lineText.filter { $0.isNumber || $0 == "." }
        return Double(digits)
    }

    private static func freezeISO(from commenceISO: String) -> String {
        guard let commence = ISO8601DateFormatter().date(from: commenceISO) else { return commenceISO }
        return iso.string(from: commence.addingTimeInterval(-3600))
    }
}

enum PlayLineGrouping {
    /// Board transform: collapse O/U pairs and both-way H2H into one card per line/game.
    static func collapseBoardLines(_ props: [PlayPropBet]) -> [PlayPropBet] {
        collapseH2H(collapseOverUnder(props))
    }

    /// Collapse separate Over/Under tiles for the same player+line into one board tile.
    static func collapseOverUnder(_ props: [PlayPropBet]) -> [PlayPropBet] {
        var out: [PlayPropBet] = []
        var index: [String: Int] = [:]
        for prop in props {
            let isOU = prop.pickLabel == "Over" || prop.pickLabel == "Under" || prop.hasOverUnderChoice
            guard isOU else {
                out.append(prop)
                continue
            }
            let key = "\(prop.eventId ?? "")|\(prop.athleteOrTeam)|\(prop.propDescription)|\(prop.lineText)"
            if let i = index[key] {
                var existing = out[i]
                if prop.pickLabel == "Over" || prop.overOdds != nil {
                    existing.overOdds = prop.overOdds ?? prop.oddsDecimal
                }
                if prop.pickLabel == "Under" || prop.underOdds != nil {
                    existing.underOdds = prop.underOdds ?? prop.oddsDecimal
                }
                if existing.overOdds != nil, existing.underOdds != nil {
                    existing.pickLabel = "O/U"
                    existing.oddsDecimal = existing.overOdds ?? existing.oddsDecimal
                }
                out[i] = existing
            } else {
                var copy = prop
                if copy.overOdds == nil, copy.pickLabel == "Over" { copy.overOdds = copy.oddsDecimal }
                if copy.underOdds == nil, copy.pickLabel == "Under" { copy.underOdds = copy.oddsDecimal }
                if copy.overOdds != nil, copy.underOdds != nil {
                    copy.pickLabel = "O/U"
                    copy.oddsDecimal = copy.overOdds ?? copy.oddsDecimal
                }
                index[key] = out.count
                out.append(copy)
            }
        }
        return out
    }

    /// Collapse home ML + away ML into one card per game; user picks the winner on the card.
    static func collapseH2H(_ props: [PlayPropBet]) -> [PlayPropBet] {
        var out: [PlayPropBet] = []
        var index: [String: Int] = [:]
        for prop in props {
            guard prop.isMoneylineStyle else {
                out.append(prop)
                continue
            }
            let key: String = {
                if let event = prop.eventId, !event.isEmpty { return "event|\(event)" }
                return "match|\(prop.matchup)|\(prop.sportKey ?? "")"
            }()
            let homeName = prop.homeTeam?.trimmingCharacters(in: .whitespacesAndNewlines)
            let awayName = prop.awayTeam?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = prop.athleteOrTeam.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHome = {
                if let homeName, !homeName.isEmpty {
                    return label.caseInsensitiveCompare(homeName) == .orderedSame
                }
                return false
            }()
            let isAway = {
                if let awayName, !awayName.isEmpty {
                    return label.caseInsensitiveCompare(awayName) == .orderedSame
                }
                return false
            }()

            if let i = index[key] {
                var existing = out[i]
                if isHome || (existing.homeOdds == nil && !isAway) {
                    existing.homeOdds = prop.homeOdds ?? prop.oddsDecimal
                    if existing.homeTeam == nil { existing.homeTeam = label }
                }
                if isAway || (existing.awayOdds == nil && isAway) {
                    existing.awayOdds = prop.awayOdds ?? prop.oddsDecimal
                    if existing.awayTeam == nil { existing.awayTeam = label }
                }
                // If we couldn't classify, fill whichever slot is empty.
                if existing.homeOdds == nil {
                    existing.homeOdds = prop.oddsDecimal
                    if existing.homeTeam == nil || existing.homeTeam?.isEmpty == true {
                        existing.homeTeam = label
                    }
                } else if existing.awayOdds == nil {
                    existing.awayOdds = prop.oddsDecimal
                    if existing.awayTeam == nil || existing.awayTeam?.isEmpty == true {
                        existing.awayTeam = label
                    }
                }
                existing.pickLabel = "H2H"
                existing.lineText = "H2H"
                existing.athleteOrTeam = existing.matchup
                existing.propDescription = "Moneyline (head-to-head)"
                existing.oddsDecimal = existing.homeOdds ?? existing.awayOdds ?? existing.oddsDecimal
                out[i] = existing
            } else {
                var copy = prop
                if copy.homeOdds == nil, isHome { copy.homeOdds = copy.oddsDecimal }
                if copy.awayOdds == nil, isAway { copy.awayOdds = copy.oddsDecimal }
                if copy.homeOdds == nil, copy.awayOdds == nil {
                    // Single side so far — stash as home until the other side arrives.
                    copy.homeOdds = copy.oddsDecimal
                    if copy.homeTeam == nil { copy.homeTeam = label }
                }
                if copy.homeOdds != nil || copy.awayOdds != nil {
                    copy.pickLabel = "H2H"
                    copy.lineText = "H2H"
                    copy.athleteOrTeam = copy.matchup
                    copy.propDescription = "Moneyline (head-to-head)"
                }
                index[key] = out.count
                out.append(copy)
            }
        }
        return out
    }
}
