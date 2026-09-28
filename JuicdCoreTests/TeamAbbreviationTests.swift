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

    func testUFCMatchupForcesVs() {
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Islam Makhachev @ Arman Tsarukyan", leagueTag: "UFC"),
            "Makhachev vs Tsarukyan"
        )
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup(
                "Islam Makhachev @ Arman Tsarukyan",
                sportKey: "mma_mixed_martial_arts"
            ),
            "Makhachev vs Tsarukyan"
        )
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Alex Pereira vs Khalil Rountree", leagueTag: "MMA"),
            "Pereira vs Rountree"
        )
    }

    func testOtherSportsKeepIncomingSeparator() {
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Dallas Cowboys @ Philadelphia Eagles", leagueTag: "NFL"),
            "DAL @ PHI"
        )
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Dallas Mavericks vs Oklahoma City Thunder", leagueTag: "NBA"),
            "DAL vs OKC"
        )
        XCTAssertEqual(
            TeamAbbreviation.abbreviateMatchup("Inter Miami CF @ LA Galaxy", sportKey: "soccer_usa_mls"),
            "Inter Miami @ LA Galaxy"
        )
    }
}

final class OddsMatchupTitleTests: XCTestCase {
    func testUFCOddsFallbackUsesVs() {
        XCTAssertEqual(
            TheOddsAPIService.h2hEventTitle(
                away: "Islam Makhachev",
                home: "Arman Tsarukyan",
                sportKey: "mma_mixed_martial_arts"
            ),
            "Islam Makhachev vs Arman Tsarukyan"
        )
        XCTAssertEqual(
            TheOddsAPIService.h2hEventTitle(away: "A", home: "B", sportKey: "ufc"),
            "A vs B"
        )
    }

    func testOtherSportsOddsFallbackKeepsAt() {
        XCTAssertEqual(
            TheOddsAPIService.h2hEventTitle(
                away: "Dallas Cowboys",
                home: "Philadelphia Eagles",
                sportKey: "americanfootball_nfl"
            ),
            "Dallas Cowboys @ Philadelphia Eagles"
        )
        XCTAssertEqual(
            TheOddsAPIService.h2hEventTitle(away: "Away", home: "Home", sportKey: "basketball_nba"),
            "Away @ Home"
        )
    }
}
