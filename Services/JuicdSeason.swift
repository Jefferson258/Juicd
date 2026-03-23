import Foundation

/// A **season** is a **3-month calendar quarter** (not a full year). Stats and copy use `seasonKey` like `"2026-Q1"`.
enum JuicdSeason {
    /// Current quarter label in the device’s local calendar, e.g. `"2026-Q1"` … `"2026-Q4"`.
    static func currentSeasonKey(at date: Date = .now) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let q = (m - 1) / 3 + 1
        return "\(y)-Q\(q)"
    }

    /// Short UI label, e.g. `"Q1 2026"`.
    static func shortLabel(for seasonKey: String) -> String {
        let parts = seasonKey.split(separator: "-")
        guard parts.count == 2 else { return seasonKey }
        return "\(parts[1]) \(parts[0])"
    }

    /// Inclusive start and **exclusive** end for the quarter (local calendar).
    static func range(for seasonKey: String) -> (start: Date, end: Date)? {
        let parts = seasonKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              parts[1].hasPrefix("Q"),
              let q = Int(parts[1].dropFirst()),
              q >= 1, q <= 4
        else { return nil }

        let cal = Calendar.current
        let startMonth = (q - 1) * 3 + 1
        guard let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1)) else { return nil }
        guard let end = cal.date(byAdding: .month, value: 3, to: start) else { return nil }
        return (start, end)
    }

    static func contains(_ date: Date, seasonKey: String) -> Bool {
        guard let range = range(for: seasonKey) else { return false }
        return date >= range.start && date < range.end
    }

    /// Next quarter boundary at **midnight local** on the first day of the next quarter (for “when does it reset?” copy).
    static func nextSeasonStart(from date: Date = .now) -> Date? {
        let key = currentSeasonKey(at: date)
        guard let range = range(for: key) else { return nil }
        return range.end
    }
}
