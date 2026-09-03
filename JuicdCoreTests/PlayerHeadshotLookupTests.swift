import XCTest
@testable import Juicd

final class PlayerHeadshotLookupTests: XCTestCase {
    func testFoldsDiacritics() {
        XCTAssertEqual(
            PlayerHeadshotLookup.foldedName("  Nikola Jokić  "),
            "nikola jokic"
        )
    }

    func testSkipsMoneylineAndStubPlayers() {
        XCTAssertFalse(
            PlayerHeadshotLookup.shouldLookup(
                name: "Boston Celtics",
                leagueTag: "NBA",
                propDescription: "Moneyline"
            )
        )
        XCTAssertFalse(
            PlayerHeadshotLookup.shouldLookup(
                name: "NBA Player 3",
                leagueTag: "NBA",
                propDescription: "Points"
            )
        )
        XCTAssertTrue(
            PlayerHeadshotLookup.shouldLookup(
                name: "Stephen Curry",
                leagueTag: "NBA",
                propDescription: "Points"
            )
        )
    }

    func testEspnPathMapping() {
        XCTAssertEqual(PlayerHeadshotLookup.espnHeadshotPath(leagueSlug: "nba"), "nba")
        XCTAssertEqual(PlayerHeadshotLookup.espnHeadshotPath(leagueSlug: "nfl"), "nfl")
        XCTAssertNil(PlayerHeadshotLookup.espnHeadshotPath(leagueSlug: "eng.1"))
    }

    func testCacheKeyIsStable() {
        XCTAssertEqual(
            PlayerHeadshotLookup.cacheKey(name: "Nikola Jokić", leagueTag: "nba"),
            PlayerHeadshotLookup.cacheKey(name: "nikola jokic", leagueTag: "NBA")
        )
    }
}
