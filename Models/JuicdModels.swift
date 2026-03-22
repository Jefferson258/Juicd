import Foundation

enum TournamentKind: String, Codable, CaseIterable, Identifiable {
    case daily
    case weeklyGroup
    case season

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily Tournament"
        case .weeklyGroup: return "Weekly Group Challenge"
        case .season: return "Season"
        }
    }
}

enum TournamentStatus: String, Codable {
    case upcoming
    case active
    case finished
}

enum BetMarketType: String, Codable, CaseIterable, Identifiable {
    case quarterOver
    case quarterUnder
    case moneylineHome
    case moneylineAway

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quarterOver: return "Over"
        case .quarterUnder: return "Under"
        case .moneylineHome: return "Home Win"
        case .moneylineAway: return "Away Win"
        }
    }
}

struct Profile: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String

    // Tier is derived from season points won (not total points).
    var currentTier: RankTier = .bronze
    var seasonPointsWon: Int
    var allTimePointsWon: Int

    // Points available today to gamble with.
    var availableDailyPoints: Int
    var lastDailyPointsAwardDateISO: String?
}

enum RankTier: String, Codable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold
    case platinum
    case emerald
    case diamond
    case challenger
    case champion

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .emerald: return "Emerald"
        case .diamond: return "Diamond"
        case .challenger: return "Challenger"
        case .champion: return "Champion"
        }
    }

    // Higher is better.
    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        rankValue(of: lhs) < rankValue(of: rhs)
    }

    private static func rankValue(of tier: RankTier) -> Int {
        switch tier {
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .platinum: return 4
        case .emerald: return 5
        case .diamond: return 6
        case .challenger: return 7
        case .champion: return 8
        }
    }
}

struct Tournament: Codable, Identifiable {
    var id: UUID
    var kind: TournamentKind
    var status: TournamentStatus
    var startAt: Date
    var endAt: Date

    // For daily quarter format: how many stages the tournament contains.
    // Typical value is 4 (quarters).
    var stageCount: Int

    var seasonYear: Int?
}

struct PointsLedgerEntry: Codable, Identifiable {
    var id: UUID
    var createdAt: Date

    var userId: UUID
    var tournamentId: UUID?
    var betSlipId: UUID?
    var deltaPoints: Int

    var reason: String
}

struct OddsChoice: Codable, Identifiable, Hashable {
    var id: UUID
    var marketType: BetMarketType
    var label: String
    var oddsDecimal: Double
}

struct OddsMarket: Codable, Identifiable {
    var id: UUID
    var eventLabel: String
    var quarterIndex: Int // 1...N
    var choices: [OddsChoice]
}

// MARK: - Play tab prop board (stub + future Odds API)

/// A single **prop bet** tile: a wager on a player or game stat (not only the final winner).
struct PlayPropBet: Identifiable, Equatable {
    var id: UUID
    var leagueTag: String
    var athleteOrTeam: String
    var matchup: String
    var propDescription: String
    var lineText: String
    var pickLabel: String
    var oddsDecimal: Double
}

struct PlayPropRibbon: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String?
    var props: [PlayPropBet]
}

struct BetLeg: Codable, Identifiable, Hashable {
    var id: UUID
    var marketId: UUID
    var choiceId: UUID
    var choiceLabel: String
    var oddsDecimalAtSubmit: Double
}

enum BetSlipStatus: String, Codable {
    case composing
    case submitted
    case resolved
    case eliminated
}

struct BetSlip: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var tournamentId: UUID
    var stageIndex: Int // 1...stageCount for daily

    var stakePoints: Int
    var legs: [BetLeg]

    // Snapshot used for payout.
    var impliedParlayOddsDecimalAtSubmit: Double
    var estimatedNetPointsPayout: Int

    // Results
    var status: BetSlipStatus
    var didWinAllLegs: Bool?
    var resolvedAt: Date?
}

struct Group: Codable, Identifiable {
    var id: UUID
    var name: String
    var inviteCode: String
    var createdAt: Date
}

struct GroupMembership: Codable, Identifiable {
    var id: UUID
    var groupId: UUID
    var userId: UUID
    var joinedAt: Date
}

struct RewardBadge: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var achievedAt: Date?
    var imageSystemName: String
}

struct RewardCatalogEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var description: String
    var imageSystemName: String
}

// MARK: - Weekly bracket (multi-day, top 50% advance)

struct WeeklyBracketDefinition: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var sportKey: String
    var roundCount: Int
    var iconSystemName: String
}

struct UserBracketProgress: Codable, Equatable {
    var definitionId: UUID
    /// Next round index to play (1...roundCount). When > roundCount, bracket is finished.
    var nextRoundToPlay: Int
    var survivedRounds: Int
    var eliminated: Bool
    var completed: Bool
    var dayScores: [Int]
    var totalBonusAwarded: Int
}

enum BracketCatalog {
    private static let nflID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    private static let nbaID = UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!
    private static let nhlID = UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!

    static let all: [WeeklyBracketDefinition] = [
        WeeklyBracketDefinition(id: nflID, name: "NFL Weekly Cup", sportKey: "americanfootball_nfl", roundCount: 7, iconSystemName: "football.fill"),
        WeeklyBracketDefinition(id: nbaID, name: "NBA Weekly Cup", sportKey: "basketball_nba", roundCount: 7, iconSystemName: "basketball.fill"),
        WeeklyBracketDefinition(id: nhlID, name: "NHL Weekly Cup", sportKey: "icehockey_nhl", roundCount: 7, iconSystemName: "sportscourt.fill")
    ]
}

