import Foundation

/// AdMob IDs for Juicd.
///
/// Defaults are **Google’s official test IDs** so the SDK works before an AdMob
/// account exists. When you have the account, send:
/// 1. iOS **App ID** (`ca-app-pub-…~…`)
/// 2. **Banner ad unit ID** (`ca-app-pub-…/…`)
/// Those go in `Juicd/Info.plist` (`GADApplicationIdentifier` and
/// `JUICD_ADMOB_BANNER_UNIT_ID`). Do not send the Google password.
enum JuicdAdsConfig {
    /// Google sample iOS app. Replace with the Juicd iOS App ID from AdMob.
    static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"
    /// Google sample banner. Replace with a Juicd banner unit.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"

    static var applicationID: String {
        let raw = plist("GADApplicationIdentifier")
        return raw.isEmpty ? testApplicationID : raw
    }

    static var bannerUnitID: String {
        let raw = plist("JUICD_ADMOB_BANNER_UNIT_ID")
        return raw.isEmpty ? testBannerUnitID : raw
    }

    /// True until production unit IDs are pasted into Info.plist.
    static var usesTestAds: Bool {
        bannerUnitID.contains("3940256099942544") || applicationID.contains("3940256099942544")
    }

    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
