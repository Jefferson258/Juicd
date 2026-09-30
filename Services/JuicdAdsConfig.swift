import Foundation

/// AdMob IDs for Juicd.
///
/// Info.plist holds the live App ID + banner unit. Simulator and DEBUG builds
/// load Google’s official **Test Ad** creatives so you can see real banner
/// size/behavior without using live inventory (and without clicking your own ads).
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

    /// Simulator / DEBUG request Google’s Test Ad creatives. Release on device
    /// uses the plist unit. Override with env `JUICD_USE_PRODUCTION_ADS=1`.
    static var loadsGoogleTestCreatives: Bool {
        if ProcessInfo.processInfo.environment["JUICD_USE_PRODUCTION_ADS"] == "1" {
            return usesTestAds
        }
        if ProcessInfo.processInfo.arguments.contains("-juicd-production-ads") {
            return usesTestAds
        }
        #if targetEnvironment(simulator)
        return true
        #elseif DEBUG
        return true
        #else
        return usesTestAds
        #endif
    }

    static var creativeBannerUnitID: String {
        loadsGoogleTestCreatives ? testBannerUnitID : bannerUnitID
    }

    /// App Store installs use `receipt`. TestFlight uses `sandboxReceipt`.
    static func isProductionAppStoreReceipt(filename: String?) -> Bool {
        filename == "receipt"
    }

    static var isProductionAppStoreInstall: Bool {
        isProductionAppStoreReceipt(filename: Bundle.main.appStoreReceiptURL?.lastPathComponent)
    }

    /// Live ads only on the App Store build. TestFlight is Release, so without
    /// this check it would request real ads. Simulator and DEBUG keep Google’s
    /// test creatives, which are safe to tap.
    static var showsAds: Bool {
        if loadsGoogleTestCreatives { return true }
        return isProductionAppStoreInstall
    }

    /// Locked layout: dismissible 320×100 AdMob large banner in the sponsored card.
    /// Launch with `-juicd-ad-style native|card|bottom` only to compare.
    enum Presentation: String {
        case nativeCard = "native"
        case cardBanner = "card"
        case bottomBanner = "bottom"
    }

    static var presentation: Presentation {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-juicd-ad-style"), i + 1 < args.count {
            return Presentation(rawValue: args[i + 1].lowercased()) ?? .cardBanner
        }
        return .cardBanner
    }

    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
