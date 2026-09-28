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

    func testCFBMidLengthNames() {
        XCTAssertEqual(TeamAbbreviation.abbreviate("Ohio State Buckeyes", leagueTag: "CFB"), "Ohio State")
        XCTAssertEqual(TeamAbbreviation.abbreviate("Michigan Wolverines", leagueTag: "NCAAF"), "Michigan")
        XCTAssertEqual(TeamAbbreviation.abbreviate("Alabama Crimson Tide", leagueTag: "CFB"), "Alabama")
        XCTAssertEqual(TeamAbbreviation.abbreviate("University of Alabama", leagueTag: "CFB"), "Alabama")
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Ohio State Buckeyes @ Michigan Wolverines", leagueTag: "CFB"),
            "Ohio State @ Michigan"
        )
        // Short codes from stubs expand to mid names for CFB.
        XCTAssertEqual(TeamAbbreviation.abbreviate("OSU", leagueTag: "CFB"), "Ohio State")
        XCTAssertEqual(TeamAbbreviation.abbreviate("UA", leagueTag: "CFB"), "Alabama")
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("OSU @ MICH", leagueTag: "CFB"),
            "Ohio State @ Michigan"
        )
    }

    func testWNBAAndMLS() {
        XCTAssertEqual(TeamAbbreviation.abbreviate("Las Vegas Aces", leagueTag: "WNBA"), "Aces")
        XCTAssertEqual(TeamAbbreviation.abbreviate("Inter Miami CF", leagueTag: "MLS"), "Inter Miami")
    }
}
