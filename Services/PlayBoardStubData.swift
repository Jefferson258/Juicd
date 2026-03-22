import Foundation

/// Rich fake **player / game props** for the Play tab. Replace with `TheOddsAPIPlayboardHook` when you wire a key.
enum PlayBoardStubData {
    static let allRibbons: [PlayPropRibbon] = [
        popular,
        nba,
        nfl,
        mlb,
        nhl,
        soccer
    ]

    private static let popular: PlayPropRibbon = PlayPropRibbon(
        id: "popular",
        title: "Popular",
        subtitle: "Trending props tonight",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "LeBron James",
                matchup: "LAL @ BOS",
                propDescription: "Points O/U",
                lineText: "O/U 24.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Patrick Mahomes",
                matchup: "KC @ BUF",
                propDescription: "Pass yards",
                lineText: "O/U 285.5",
                pickLabel: "Over",
                oddsDecimal: 1.87
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Giannis Antetokounmpo",
                matchup: "MIL vs PHI",
                propDescription: "Rebounds",
                lineText: "O/U 12.5",
                pickLabel: "Over",
                oddsDecimal: 1.83
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Josh Allen",
                matchup: "BUF @ KC",
                propDescription: "Pass + rush TDs",
                lineText: "O/U 2.5",
                pickLabel: "Under",
                oddsDecimal: 2.05
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Aaron Judge",
                matchup: "NYY @ TOR",
                propDescription: "Home runs",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 2.40
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Connor McDavid",
                matchup: "EDM @ COL",
                propDescription: "Points",
                lineText: "O/U 1.5",
                pickLabel: "Over",
                oddsDecimal: 1.74
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Jayson Tatum",
                matchup: "BOS vs LAL",
                propDescription: "Made threes",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 1.95
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Christian McCaffrey",
                matchup: "SF @ SEA",
                propDescription: "Rush yards",
                lineText: "O/U 88.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            )
        ]
    )

    private static let nba: PlayPropRibbon = PlayPropRibbon(
        id: "nba",
        title: "NBA",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Nikola Jokić",
                matchup: "DEN @ MIN",
                propDescription: "Points + reb + ast",
                lineText: "O/U 48.5",
                pickLabel: "Over",
                oddsDecimal: 1.89
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Stephen Curry",
                matchup: "GSW @ PHX",
                propDescription: "Points",
                lineText: "O/U 27.5",
                pickLabel: "Over",
                oddsDecimal: 1.92
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Luka Dončić",
                matchup: "DAL vs OKC",
                propDescription: "Assists",
                lineText: "O/U 9.5",
                pickLabel: "Under",
                oddsDecimal: 1.98
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Joel Embiid",
                matchup: "PHI @ MIL",
                propDescription: "Points",
                lineText: "O/U 30.5",
                pickLabel: "Over",
                oddsDecimal: 1.85
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Anthony Edwards",
                matchup: "MIN vs DEN",
                propDescription: "Points",
                lineText: "O/U 26.5",
                pickLabel: "Over",
                oddsDecimal: 1.90
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Shai Gilgeous-Alexander",
                matchup: "OKC @ MEM",
                propDescription: "Points",
                lineText: "O/U 31.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Kevin Durant",
                matchup: "PHX vs GSW",
                propDescription: "Points",
                lineText: "O/U 27.5",
                pickLabel: "Under",
                oddsDecimal: 2.02
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Tyrese Haliburton",
                matchup: "IND @ MIA",
                propDescription: "Assists",
                lineText: "O/U 10.5",
                pickLabel: "Over",
                oddsDecimal: 1.86
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Victor Wembanyama",
                matchup: "SAS @ HOU",
                propDescription: "Blocks",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 1.94
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Damian Lillard",
                matchup: "MIL @ BOS",
                propDescription: "Made threes",
                lineText: "O/U 4.5",
                pickLabel: "Over",
                oddsDecimal: 2.08
            )
        ]
    )

    private static let nfl: PlayPropRibbon = PlayPropRibbon(
        id: "nfl",
        title: "NFL",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Lamar Jackson",
                matchup: "BAL @ PIT",
                propDescription: "Pass yards",
                lineText: "O/U 242.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Jalen Hurts",
                matchup: "PHI vs DAL",
                propDescription: "Rush yards",
                lineText: "O/U 38.5",
                pickLabel: "Over",
                oddsDecimal: 1.84
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "CeeDee Lamb",
                matchup: "DAL @ PHI",
                propDescription: "Receptions",
                lineText: "O/U 7.5",
                pickLabel: "Over",
                oddsDecimal: 1.89
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Tyreek Hill",
                matchup: "MIA @ NYJ",
                propDescription: "Rec yards",
                lineText: "O/U 92.5",
                pickLabel: "Under",
                oddsDecimal: 1.93
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Saquon Barkley",
                matchup: "PHI @ NYG",
                propDescription: "Rush + rec yards",
                lineText: "O/U 118.5",
                pickLabel: "Over",
                oddsDecimal: 1.87
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Justin Jefferson",
                matchup: "MIN @ DET",
                propDescription: "Rec yards",
                lineText: "O/U 98.5",
                pickLabel: "Over",
                oddsDecimal: 1.90
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Brock Purdy",
                matchup: "SF vs SEA",
                propDescription: "Pass TDs",
                lineText: "O/U 2.5",
                pickLabel: "Under",
                oddsDecimal: 2.12
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Dak Prescott",
                matchup: "DAL @ WAS",
                propDescription: "Completions",
                lineText: "O/U 24.5",
                pickLabel: "Over",
                oddsDecimal: 1.86
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Travis Kelce",
                matchup: "KC @ LAC",
                propDescription: "Rec yards",
                lineText: "O/U 68.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Amon-Ra St. Brown",
                matchup: "DET vs MIN",
                propDescription: "Receptions",
                lineText: "O/U 8.5",
                pickLabel: "Over",
                oddsDecimal: 1.95
            )
        ]
    )

    private static let mlb: PlayPropRibbon = PlayPropRibbon(
        id: "mlb",
        title: "MLB",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Shohei Ohtani",
                matchup: "LAD @ SD",
                propDescription: "Strikeouts (pitching)",
                lineText: "O/U 8.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Ronald Acuña Jr.",
                matchup: "ATL @ PHI",
                propDescription: "Hits + runs + RBIs",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Mookie Betts",
                matchup: "LAD vs SF",
                propDescription: "Total bases",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.87
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Juan Soto",
                matchup: "NYY @ BOS",
                propDescription: "Hits",
                lineText: "O/U 1.5",
                pickLabel: "Over",
                oddsDecimal: 2.05
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Freddie Freeman",
                matchup: "LAD @ COL",
                propDescription: "Hits",
                lineText: "O/U 1.5",
                pickLabel: "Under",
                oddsDecimal: 1.82
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Pete Alonso",
                matchup: "NYM @ ATL",
                propDescription: "Home runs",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 2.55
            )
        ]
    )

    private static let nhl: PlayPropRibbon = PlayPropRibbon(
        id: "nhl",
        title: "NHL",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Auston Matthews",
                matchup: "TOR @ FLA",
                propDescription: "Goals",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 1.72
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Nathan MacKinnon",
                matchup: "COL vs EDM",
                propDescription: "Points",
                lineText: "O/U 1.5",
                pickLabel: "Over",
                oddsDecimal: 1.80
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "David Pastrnak",
                matchup: "BOS @ TB",
                propDescription: "Shots on goal",
                lineText: "O/U 4.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Artemi Panarin",
                matchup: "NYR @ CAR",
                propDescription: "Assists",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 1.77
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Connor Bedard",
                matchup: "CHI @ DET",
                propDescription: "Points",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 1.69
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Igor Shesterkin",
                matchup: "NYR @ NJD",
                propDescription: "Saves",
                lineText: "O/U 28.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            )
        ]
    )

    private static let soccer: PlayPropRibbon = PlayPropRibbon(
        id: "soccer",
        title: "Soccer",
        subtitle: "Match & player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "EPL",
                athleteOrTeam: "Arsenal",
                matchup: "ARS vs MCI",
                propDescription: "Both teams score",
                lineText: "Yes / No",
                pickLabel: "Yes",
                oddsDecimal: 1.68
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "UCL",
                athleteOrTeam: "Kylian Mbappé",
                matchup: "RMA @ LFC",
                propDescription: "Anytime goal",
                lineText: "Yes",
                pickLabel: "Yes",
                oddsDecimal: 2.10
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLS",
                athleteOrTeam: "Inter Miami",
                matchup: "MIA vs ATL",
                propDescription: "Total goals",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 1.94
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "EPL",
                athleteOrTeam: "Erling Haaland",
                matchup: "MCI @ TOT",
                propDescription: "Shots on target",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.83
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "UCL",
                athleteOrTeam: "Mohamed Salah",
                matchup: "LFC vs RMA",
                propDescription: "Anytime goal",
                lineText: "Yes",
                pickLabel: "Yes",
                oddsDecimal: 2.25
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLS",
                athleteOrTeam: "LAFC",
                matchup: "LAFC @ SEA",
                propDescription: "Corners",
                lineText: "O/U 10.5",
                pickLabel: "Over",
                oddsDecimal: 1.89
            )
        ]
    )
}
