import Foundation

/// **Juicd** promotional odds: a couple of props get a fixed multiplier (prototype simulates; production uses a scheduled job + CMS).
enum JuicdOddsNightly {
    static let boostMultiplier: Double = 1.5
    static let boostCount = 2

    private static func seed(forSlateKey day: String) -> UInt64 {
        var h: UInt64 = 14_695_981_039_346_656_037
        for u in day.utf8 {
            h = h &* 31 &+ UInt64(u)
        }
        return h
    }

    /// Deterministic per **slate** (local 6am day): marks up to `boostCount` tiles across all ribbons with `juicdMultiplier`.
    static func applyBoosts(to ribbons: [PlayPropRibbon], slateKey: String) -> [PlayPropRibbon] {
        guard !ribbons.isEmpty else { return ribbons }
        var flat: [(Int, Int)] = []
        for (ri, r) in ribbons.enumerated() {
            for pi in r.props.indices {
                flat.append((ri, pi))
            }
        }
        guard !flat.isEmpty else { return ribbons }

        var rng = SeededRNG(seed: seed(forSlateKey: slateKey) ^ 0x4A11_1C)
        var order = Array(0..<flat.count)
        for i in stride(from: order.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(0, i + 1)
            order.swapAt(i, j)
        }

        let take = min(boostCount, flat.count)
        var copy = ribbons
        for k in 0..<take {
            let idx = order[k]
            let pair = flat[idx]
            copy[pair.0].props[pair.1].juicdMultiplier = boostMultiplier
        }
        return copy
    }
}
