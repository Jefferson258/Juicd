import Foundation

struct StubOddsProvider {
    // Generates deterministic-yet-updatable odds so the UI feels "live".
    private func seed(forKey key: String) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(key)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    // Public: fetch a set of quarter markets for the daily tournament.
    func dailyQuarterMarkets(for date: Date, stageIndex: Int) -> [OddsMarket] {
        let dayKey = Self.isoDay(date)
        let baseEvents = [
            ("Giants vs Cowboys", "NYG-COW"),
            ("Rams vs Seahawks", "LAR-SEA"),
            ("Packers vs Bears", "GB-CHI"),
            ("Eagles vs Giants", "PHI-NYG")
        ]

        // Each stage uses different odds drift, but stays stable per refresh.
        let refreshNonce = Int(Date().timeIntervalSinceReferenceDate) / 10 // drift every ~10s

        return baseEvents.enumerated().map { idx, event in
            let marketId = UUID()
            let eventLabel = event.0
            let eventKey = "\(dayKey)-\(event.1)-Q\(stageIndex)-\(refreshNonce)"

            // Quarter prop "total" style markets.
            // We'll show two choices (Over/Under) with close odds.
            let seed = seed(forKey: eventKey)
            var rng = SeededRNG(seed: seed)

            let baseTotal = 24 + idx * 4
            let line = baseTotal + (rng.nextInt(0, 2) == 0 ? 0 : 1)

            let overOdds = clampDecimalOdds(1.55 + rng.nextDouble() * 0.35)
            let underOdds = clampDecimalOdds(1.55 + rng.nextDouble() * 0.35)

            let overChoice = OddsChoice(
                id: UUID(),
                marketType: .quarterOver,
                label: "Over \(line + stageIndex) pts",
                oddsDecimal: overOdds
            )
            let underChoice = OddsChoice(
                id: UUID(),
                marketType: .quarterUnder,
                label: "Under \(line + stageIndex) pts",
                oddsDecimal: underOdds
            )

            return OddsMarket(
                id: marketId,
                eventLabel: eventLabel,
                quarterIndex: stageIndex,
                choices: [overChoice, underChoice]
            )
        }
    }

    private static func isoDay(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private func clampDecimalOdds(_ v: Double) -> Double {
        min(max(v, 1.2), 4.5)
    }
}

/// Minimal deterministic PRNG for stable odds between refreshes.
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
    }

    mutating func nextUInt64() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }

    mutating func nextDouble() -> Double {
        let x = nextUInt64()
        return Double(x) / Double(UInt64.max)
    }

    mutating func nextInt(_ lower: Int, _ upperExclusive: Int) -> Int {
        let n = upperExclusive - lower
        return lower + Int(nextUInt64() % UInt64(max(n, 1)))
    }
}

