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
        return request
    }
}
