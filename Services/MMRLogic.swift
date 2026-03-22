import Foundation

/// Rank is driven by **MMR** — wide bands so small day-to-day swings rarely change tier.
enum MMRLogic {
    static let startingMMR: Double = 1500

    /// Tier boundaries on MMR (exclusive upper bound except champion).
    private static let tierUpperBounds: [(RankTier, Double)] = [
        (.bronze, 1320),
        (.silver, 1390),
        (.gold, 1460),
        (.platinum, 1530),
        (.emerald, 1600),
        (.diamond, 1670),
        (.challenger, 1740),
        (.champion, .infinity)
    ]

    static func tier(for mmr: Double) -> RankTier {
        for (tier, cap) in tierUpperBounds where mmr < cap {
            return tier
        }
        return .champion
    }

    /// MMR change from placement in a daily pool (`rank` 1 = best). Tighter curve in the middle.
    static func mmrDelta(rank: Int, poolSize: Int) -> Double {
        guard poolSize >= 2, rank >= 1, rank <= poolSize else { return 0 }
        let p = (Double(rank) - 0.5) / Double(poolSize)
        let centered = 0.5 - p
        let t = centered * 2
        let sign = t >= 0 ? 1.0 : -1.0
        let mag = abs(t)
        let shaped = pow(mag, 1.35)
        return sign * 52 * shaped
    }

    /// Performance score for sorting a pool (higher = better placement).
    static func dailyPerformanceScore(
        userId: UUID,
        dayISO: String,
        baseMMR: Double,
        netProfitFromBets: Int,
        rng: inout SeededRNG
    ) -> Double {
        let mmrEdge = (baseMMR - startingMMR) / 120
        let profitEdge = Double(min(40, max(-40, netProfitFromBets))) / 40
        let noise = rng.nextDouble() * 28 + rng.nextDouble() * 12
        return 50 + mmrEdge * 8 + profitEdge * 10 + noise
    }

    static func opponentName(seed: UInt64, index: Int) -> String {
        let names = ["Jax", "Rio", "Mara", "Chen", "Kai", "Nova", "Zeke", "Ava", "Leo", "Sky", "Ivy", "Owen", "Quinn", "Remy", "Sloane", "Tate"]
        let suffix = Int(seed % 900) + 100
        let base = names[index % names.count]
        return "\(base)\(suffix)"
    }
}
