import GoogleMobileAds
import UIKit

enum JuicdMobileAds {
    private static var didStart = false

    /// Call once at launch. Safe to call again (no-op).
    /// Runs before any banner is created or loaded (`JuicdApp.init` and every
    /// `JuicdBannerAdLoader` call this first), so the content cap below applies
    /// to the very first ad request.
    static func start() {
        guard !didStart else { return }
        didStart = true
        // Family-safe cap: only "G" (general audience) creatives are eligible.
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        MobileAds.shared.start()
    }

    static func nonPersonalizedRequest() -> Request {
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        let request = Request()
        request.register(extras)
        // Used by Google for targeting and brand safety. Does not stop a cloaked
        // creative whose landing page is a scam after the click.
        request.contentURL = "https://juicdsports.com"
        request.neighboringContentURLs = [
            "https://juicdsports.com/privacy",
            "https://juicdsports.com/terms",
        ]
        request.keywords = ["sports", "tournament", "leaderboard"]
        return request
    }
}
