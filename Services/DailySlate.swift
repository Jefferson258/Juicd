import Foundation

/// Betting **slate** = local calendar day that starts at **6:00** (not midnight). Before 6am, you’re still on the previous day’s slate.
/// Same slate key + deterministic seeds ⇒ same props/odds for every player without a database (prototype).
enum SlateDay {
    /// Anchor midnight for the slate’s **label date** (local TZ).
    static func anchorDate(for date: Date = .now) -> Date {
        let cal = Calendar.current
        let sod = cal.startOfDay(for: date)
        let six = cal.date(byAdding: .hour, value: 6, to: sod)!
        if date >= six {
            return sod
        }
        return cal.date(byAdding: .day, value: -1, to: sod)!
    }

    /// `yyyy-MM-dd` in **local** time for the current slate (6am boundary).
    static func slateKey(for date: Date = .now) -> String {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.timeZone = Calendar.current.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: anchorDate(for: date))
    }

    /// The slate that **ended** when the current one began (used to resolve ranked play).
    static func previousSlateKey(from date: Date = .now) -> String {
        let cal = Calendar.current
        let anchor = anchorDate(for: date)
        let prev = cal.date(byAdding: .day, value: -1, to: anchor)!
        let df = DateFormatter()
        df.calendar = cal
        df.timeZone = cal.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: prev)
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

/// Builds the Play board for a slate so all users see the **same** props and prices (IDs stable per slate).
enum DailySlateBoard {
    static func ribbons(forSlateKey slateKey: String, sport: PlaySportPill) -> [PlayPropRibbon] {
        let base: [PlayPropRibbon]
        switch sport {
        case .forYou:
            base = PlayBoardStubData.forYouRibbons
        default:
            guard let r = PlayBoardStubData.sportRibbon(for: sport) else { return [] }
            base = [r]
        }
        return base.map { ribbon in
            var r = ribbon
            r.props = ribbon.props.enumerated().map { idx, p in
                var q = p
                q.id = StableUUID.from("\(slateKey)|\(ribbon.id)|\(idx)|\(p.pickLabel)")
                return q
            }
            return r
        }
    }
}
