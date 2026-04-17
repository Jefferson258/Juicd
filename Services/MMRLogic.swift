import Foundation

/// Rank is driven by **MMR** — wide bands so small day-to-day swings rarely change tier.
enum MMRLogic {
    static let startingMMR: Double = 1500
    static let dailyRankGroupSize = 10

    /// Tier split by percentile with distribution slightly centered on Platinum.
    /// Percent buckets (low -> high): 8, 14, 18, 26, 16, 10, 6, 2
    /// Cumulative cut points: 0.08, 0.22, 0.40, 0.66, 0.82, 0.92, 0.98, 1.00
    private static let tierPercentileCaps: [(RankTier, Double)] = [
        (.bronze, 0.08),
        (.silver, 0.22),
        (.gold, 0.40),
        (.platinum, 0.66),
        (.emerald, 0.82),
        (.diamond, 0.92),
        (.challenger, 0.98),
        (.champion, 1.0)
    ]

    static func tier(for mmr: Double) -> RankTier {
        let pct = percentileFromMMR(mmr)
        for (tier, cap) in tierPercentileCaps where pct <= cap {
            return tier
        }
        return .champion
    }

    /// MMR movement by placement in a 10-player daily group.
    /// Top 5 gain MMR, bottom 5 lose MMR; rank 1/10 are most extreme.
    static func mmrDelta(rank: Int, poolSize: Int) -> Double {
        guard poolSize == dailyRankGroupSize, rank >= 1, rank <= poolSize else { return 0 }
        let deltas: [Double] = [30, 22, 15, 9, 4, -4, -9, -15, -22, -30]
        return deltas[rank - 1]
    }

    /// Smooth raw daily MMR updates into a moving average.
    static func smoothedMMR(currentMMR: Double, rawDelta: Double) -> Double {
        let target = currentMMR + rawDelta
        return currentMMR + (target - currentMMR) * 0.35
    }

    /// Performance score for sorting a pool (higher = better placement).
    static func dailyPerformanceScore(
        userId: UUID,
        dayISO: String,
        baseMMR: Double,
        normalizedNetAtHundred: Double,
        rng: inout SeededRNG
    ) -> Double {
        let mmrEdge = (baseMMR - startingMMR) / 140
        let pointsEdge = min(100, max(-100, normalizedNetAtHundred)) / 100
        let noise = rng.nextDouble() * 11 + rng.nextDouble() * 5
        return 50 + mmrEdge * 6.5 + pointsEdge * 18 + noise
    }

    static func opponentName(seed: UInt64, index: Int) -> String {
        let names = ["Jax", "Rio", "Mara", "Chen", "Kai", "Nova", "Zeke", "Ava", "Leo", "Sky", "Ivy", "Owen", "Quinn", "Remy", "Sloane", "Tate"]
        let suffix = Int(seed % 900) + 100
        let base = names[index % names.count]
        return "\(base)\(suffix)"
    }

    private static func percentileFromMMR(_ mmr: Double) -> Double {
        let z = (mmr - startingMMR) / 220
        return max(0, min(1, normalCDF(z)))
    }

    private static func normalCDF(_ z: Double) -> Double {
        let sign = z < 0 ? -1.0 : 1.0
        let x = abs(z) / sqrt(2.0)
        let t = 1.0 / (1.0 + 0.3275911 * x)
        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let erfApprox = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x)
        return 0.5 * (1.0 + sign * erfApprox)
    }
}
