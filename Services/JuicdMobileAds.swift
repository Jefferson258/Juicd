import GoogleMobileAds
import UIKit

enum JuicdMobileAds {
    private static var didStart = false

    /// Call once at launch. Safe to call again (no-op).
    static func start() {
        guard !didStart else { return }
        didStart = true
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
