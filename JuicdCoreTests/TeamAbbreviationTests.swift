import XCTest
@testable import Juicd

final class TeamAbbreviationTests: XCTestCase {
    func testMLBFullNames() {
        XCTAssertEqual(TeamAbbreviation.abbreviate("New York Yankees", leagueTag: "MLB"), "NYY")
        XCTAssertEqual(TeamAbbreviation.abbreviate("Baltimore Orioles", leagueTag: "MLB"), "BAL")
    }

    func testMatchup() {
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("New York Yankees @ Baltimore Orioles", leagueTag: "MLB"),
            "NYY @ BAL"
        )
    }

    func testAlreadyShort() {
        XCTAssertEqual(TeamAbbreviation.abbreviate("NYY", leagueTag: "MLB"), "NYY")
        XCTAssertEqual(TeamAbbreviation.abbreviateMatchup("DEN @ MIN", leagueTag: "NBA"), "DEN @ MIN")
    }

    func testNFLAndNBA() {
        XCTAssertEqual(TeamAbbreviation.abbreviate("Kansas City Chiefs", leagueTag: "NFL"), "KC")
        XCTAssertEqual(TeamAbbreviation.abbreviate("Golden State Warriors", leagueTag: "NBA"), "GSW")
    }
}
