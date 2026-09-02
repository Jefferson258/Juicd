import Foundation

/// Play-feed insertion policy + fake placeholder creatives (Profile spawn).
enum JuicdAdsDev {
    /// When set, Play shows this creative immediately. Cleared from Profile or when ads toggle off.
    static let forceCreativeIdKey = "juicd_ads_force_creative_id"
    /// Bumped so `PlayView` re-runs placement when spawning from Profile.
    static let forceRevisionKey = "juicd_ads_force_revision"

    private static let lastImpressionKey = "juicd_ads_last_impression_at"

    /// In-feed slot follows the Profile toggle only (no random roll).
    static func shouldShowAd(adsEnabled: Bool) -> Bool {
        adsEnabled
    }

    /// Call when the user **sees** the in-feed ad cell (once per placement).
    static func recordImpression() {
        UserDefaults.standard.set(Date(), forKey: lastImpressionKey)
    }
}

// MARK: - Dev creatives (fake brands — not real campaigns)

struct JuicdDevAdCreative: Identifiable {
    var id: String
    var headline: String
    var body: String
    var sponsorName: String
    var cta: String
    var systemImage: String
    var accent: (r: Double, g: Double, b: Double)

    static func random() -> JuicdDevAdCreative {
        all.randomElement() ?? all[0]
    }

    /// Sample campaigns: sports-adjacent, clearly fictional for dev.
    static let all: [JuicdDevAdCreative] = [
        JuicdDevAdCreative(
            id: "voltade",
            headline: "Hydrate between slates",
            body: "Electrolyte mix — dev placeholder, not a real product.",
            sponsorName: "VoltaDe Sports Drink",
            cta: "Learn more",
            systemImage: "drop.fill",
            accent: (0.2, 0.85, 0.55)
        ),
        JuicdDevAdCreative(
            id: "gridiron_plus",
            headline: "Every game. One app.",
            body: "Streaming bundle mock — fictional service for layout testing.",
            sponsorName: "Gridiron+",
            cta: "Watch trailer",
            systemImage: "play.tv.fill",
            accent: (0.35, 0.55, 0.98)
        ),
        JuicdDevAdCreative(
            id: "lineup_labs",
            headline: "Smarter line shopping",
            body: "Odds comparison concept — no real sportsbook linked.",
            sponsorName: "Lineup Labs",
            cta: "See demo",
            systemImage: "chart.line.uptrend.xyaxis",
            accent: (0.95, 0.45, 0.2)
        ),
        JuicdDevAdCreative(
            id: "bench_warmer",
            headline: "Fantasy without the grind",
            body: "Casual league format — placeholder copy only.",
            sponsorName: "Bench Warmer Fantasy",
            cta: "Explore",
            systemImage: "person.3.fill",
            accent: (0.55, 0.35, 0.95)
        ),
        JuicdDevAdCreative(
            id: "prime_time_audio",
            headline: "Calls while you watch",
            body: "Podcast network mock — not a real subscription.",
            sponsorName: "Prime Time Audio",
            cta: "Listen",
            systemImage: "headphones",
            accent: (0.9, 0.35, 0.25)
        )
    ]
}
