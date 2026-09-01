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
}
