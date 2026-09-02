import XCTest
@testable import Juicd

final class JuicdAdsConfigTests: XCTestCase {
    func testUsesPastedProductionAdMobIDs() {
        XCTAssertTrue(
            JuicdAdsConfig.applicationID.hasPrefix("ca-app-pub-1484242722888691~"),
            "GADApplicationIdentifier must be the Juicd iOS App ID"
        )
        XCTAssertTrue(
            JuicdAdsConfig.bannerUnitID.hasPrefix("ca-app-pub-1484242722888691/"),
            "JUICD_ADMOB_BANNER_UNIT_ID must be the Juicd banner unit"
        )
        XCTAssertFalse(JuicdAdsConfig.usesTestAds)
    }

    func testSimulatorRequestsGoogleTestCreatives() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(JuicdAdsConfig.loadsGoogleTestCreatives)
        XCTAssertEqual(JuicdAdsConfig.creativeBannerUnitID, JuicdAdsConfig.testBannerUnitID)
        #endif
    }

    func testInFeedAdFollowsToggleOnly() {
        XCTAssertFalse(JuicdAdsDev.shouldShowAd(adsEnabled: false))
        XCTAssertTrue(JuicdAdsDev.shouldShowAd(adsEnabled: true))
        XCTAssertTrue(JuicdAdsDev.shouldShowAd(adsEnabled: true))
    }

    func testDefaultPresentationIsDismissibleCardBanner() {
        XCTAssertEqual(JuicdAdsConfig.presentation, .cardBanner)
    }
}
