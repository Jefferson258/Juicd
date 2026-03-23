import Foundation

/// Rich fake **player / game props** for the Play tab. Replace with `TheOddsAPIPlayboardHook` when you wire a key.
enum PlayBoardStubData {
    /// For You home: multiple “Popular …” ribbons by league.
    static let forYouRibbons: [PlayPropRibbon] = [
        popularNBA,
        popularNFL,
        popularCBB,
        popularMBB,
        popularWomensSoccer,
        popularMLB,
        popularNHL,
        popularSoccer
    ]

    /// Single-sport board when a sport pill is selected.
    static func sportRibbon(for pill: PlaySportPill) -> PlayPropRibbon? {
        switch pill {
        case .forYou: return nil
        case .nba: return nba
        case .nfl: return nfl
        case .mlb: return mlb
        case .nhl: return nhl
        case .cbb: return cbb
        case .mbb: return mbb
        case .womensSoccer: return womensSoccer
        case .soccer: return soccer
        }
    }

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
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Domantas Sabonis",
                matchup: "SAC @ LAC",
                propDescription: "Rebounds",
                lineText: "O/U 12.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Alperen Şengün",
                matchup: "HOU @ NOP",
                propDescription: "Points",
                lineText: "O/U 21.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
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
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Josh Allen",
                matchup: "BUF @ MIA",
                propDescription: "Pass TDs",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.94
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NFL",
                athleteOrTeam: "Christian McCaffrey",
                matchup: "SF vs ARI",
                propDescription: "Rush yards",
                lineText: "O/U 72.5",
                pickLabel: "Over",
                oddsDecimal: 1.89
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
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Corbin Burnes",
                matchup: "MIL @ STL",
                propDescription: "Strikeouts (pitching)",
                lineText: "O/U 7.5",
                pickLabel: "Under",
                oddsDecimal: 1.93
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MLB",
                athleteOrTeam: "Bobby Witt Jr.",
                matchup: "KC @ TEX",
                propDescription: "Total bases",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
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
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NHL",
                athleteOrTeam: "Alex Ovechkin",
                matchup: "WSH @ PIT",
                propDescription: "Goals",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 1.95
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
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "EPL",
                athleteOrTeam: "Match total",
                matchup: "TOT @ CHE",
                propDescription: "Yellow cards (match)",
                lineText: "O/U 4.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            )
        ]
    )

    private static let cbb: PlayPropRibbon = PlayPropRibbon(
        id: "cbb",
        title: "College basketball (CBB)",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Zach Edey",
                matchup: "PUR @ IU",
                propDescription: "Points",
                lineText: "O/U 22.5",
                pickLabel: "Over",
                oddsDecimal: 1.90
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Hunter Dickinson",
                matchup: "KU @ KST",
                propDescription: "Rebounds",
                lineText: "O/U 10.5",
                pickLabel: "Over",
                oddsDecimal: 1.84
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "RJ Davis",
                matchup: "UNC @ DUKE",
                propDescription: "Points + reb + ast",
                lineText: "O/U 32.5",
                pickLabel: "Over",
                oddsDecimal: 1.92
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Donovan Clingan",
                matchup: "UCONN @ MARQ",
                propDescription: "Blocks",
                lineText: "O/U 2.5",
                pickLabel: "Under",
                oddsDecimal: 2.00
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Kyle Filipowski",
                matchup: "DUKE vs UNC",
                propDescription: "Made threes",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Tristen Newton",
                matchup: "UCONN @ CREI",
                propDescription: "Assists",
                lineText: "O/U 6.5",
                pickLabel: "Over",
                oddsDecimal: 1.86
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "CBB",
                athleteOrTeam: "Armando Bacot",
                matchup: "UNC @ UVA",
                propDescription: "Rebounds",
                lineText: "O/U 11.5",
                pickLabel: "Over",
                oddsDecimal: 1.87
            )
        ]
    )

    private static let mbb: PlayPropRibbon = PlayPropRibbon(
        id: "mbb",
        title: "Mid-major (MBB)",
        subtitle: "Player props",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Tyson Degenhart",
                matchup: "BSU @ USU",
                propDescription: "Points",
                lineText: "O/U 19.5",
                pickLabel: "Over",
                oddsDecimal: 1.91
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Max Abmas",
                matchup: "ORU @ SDSU",
                propDescription: "Points",
                lineText: "O/U 21.5",
                pickLabel: "Under",
                oddsDecimal: 1.95
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Ajay Mitchell",
                matchup: "UCSB @ UCI",
                propDescription: "Assists",
                lineText: "O/U 5.5",
                pickLabel: "Over",
                oddsDecimal: 1.87
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Jordan Walker",
                matchup: "UAB @ FAU",
                propDescription: "Made threes",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 2.02
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Trevin Knell",
                matchup: "BYU @ GONZ",
                propDescription: "Rebounds",
                lineText: "O/U 4.5",
                pickLabel: "Over",
                oddsDecimal: 1.83
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Jaedon LeDee",
                matchup: "SDSU @ UNM",
                propDescription: "Points + reb + ast",
                lineText: "O/U 28.5",
                pickLabel: "Over",
                oddsDecimal: 1.90
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "MBB",
                athleteOrTeam: "Isaiah Stevens",
                matchup: "CSU @ WYO",
                propDescription: "Blocks",
                lineText: "O/U 0.5",
                pickLabel: "Under",
                oddsDecimal: 2.05
            )
        ]
    )

    private static let womensSoccer: PlayPropRibbon = PlayPropRibbon(
        id: "womens_soccer",
        title: "Women’s soccer",
        subtitle: "NWSL & more",
        props: [
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Sophia Smith",
                matchup: "POR @ SD",
                propDescription: "Shots on target",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 1.85
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Trinity Rodman",
                matchup: "WAS @ NC",
                propDescription: "Anytime goal",
                lineText: "Yes",
                pickLabel: "Yes",
                oddsDecimal: 2.15
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Mallory Swanson",
                matchup: "CHI @ LA",
                propDescription: "Goals",
                lineText: "O/U 0.5",
                pickLabel: "Over",
                oddsDecimal: 1.78
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Rose Lavelle",
                matchup: "GOT @ SEA",
                propDescription: "Corners (team)",
                lineText: "O/U 5.5",
                pickLabel: "Over",
                oddsDecimal: 1.92
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "WSL",
                athleteOrTeam: "Lauren James",
                matchup: "CHE @ ARS",
                propDescription: "Shots",
                lineText: "O/U 2.5",
                pickLabel: "Over",
                oddsDecimal: 1.88
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Match total",
                matchup: "POR @ LA",
                propDescription: "Yellow cards (match)",
                lineText: "O/U 3.5",
                pickLabel: "Over",
                oddsDecimal: 1.96
            ),
            PlayPropBet(
                id: UUID(),
                leagueTag: "NWSL",
                athleteOrTeam: "Total goals",
                matchup: "SD @ SEA",
                propDescription: "Total goals",
                lineText: "O/U 2.5",
                pickLabel: "Under",
                oddsDecimal: 1.90
            )
        ]
    )

    private static let popularNBA: PlayPropRibbon = PlayPropRibbon(
        id: "popular_nba",
        title: "Popular NBA",
        subtitle: "Trending basketball props",
        props: Array(nba.props.prefix(4))
    )

    private static let popularNFL: PlayPropRibbon = PlayPropRibbon(
        id: "popular_nfl",
        title: "Popular NFL",
        subtitle: "Trending football props",
        props: Array(nfl.props.prefix(4))
    )

    private static let popularCBB: PlayPropRibbon = PlayPropRibbon(
        id: "popular_cbb",
        title: "Popular CBB",
        subtitle: "Trending college hoops",
        props: Array(cbb.props.prefix(4))
    )

    private static let popularMBB: PlayPropRibbon = PlayPropRibbon(
        id: "popular_mbb",
        title: "Popular MBB",
        subtitle: "Trending mid-major lines",
        props: Array(mbb.props.prefix(4))
    )

    private static let popularWomensSoccer: PlayPropRibbon = PlayPropRibbon(
        id: "popular_wsoc",
        title: "Popular women’s soccer",
        subtitle: "Trending NWSL / WSL",
        props: Array(womensSoccer.props.prefix(4))
    )

    private static let popularMLB: PlayPropRibbon = PlayPropRibbon(
        id: "popular_mlb",
        title: "Popular MLB",
        subtitle: "Trending baseball props",
        props: Array(mlb.props.prefix(4))
    )

    private static let popularNHL: PlayPropRibbon = PlayPropRibbon(
        id: "popular_nhl",
        title: "Popular NHL",
        subtitle: "Trending hockey props",
        props: Array(nhl.props.prefix(4))
    )

    private static let popularSoccer: PlayPropRibbon = PlayPropRibbon(
        id: "popular_soccer",
        title: "Popular soccer",
        subtitle: "Trending match & player props",
        props: Array(soccer.props.prefix(4))
    )
}
