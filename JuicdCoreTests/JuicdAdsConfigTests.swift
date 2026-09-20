import XCTest
@testable import Juicd

final class JuicdAdsConfigTests: XCTestCase {
    func testUsesPastedProductionAdMobIDs() {
        XCTAssertTrue(
            JuicdAdsConfig.applicationID.hasPrefix("ca-app-pub-6445327955674922~"),
            "GADApplicationIdentifier must be the Juicd iOS App ID"
        )
        XCTAssertTrue(
            JuicdAdsConfig.bannerUnitID.hasPrefix("ca-app-pub-6445327955674922/"),
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

    func testInFeedAdIsAlwaysEligible() {
        XCTAssertTrue(JuicdAdsDev.shouldShowAd())
    }

    func testDefaultPresentationIsDismissibleCardBanner() {
        XCTAssertEqual(JuicdAdsConfig.presentation, .cardBanner)
    }
}
