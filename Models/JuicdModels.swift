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

    /// Hidden skill rating; tier is derived from MMR bands (see `MMRLogic`).
    var mmr: Double?
    /// Visible tier — updated from MMR after daily ranked pools resolve.
    var currentTier: RankTier = .bronze
    var seasonPointsWon: Int
    var allTimePointsWon: Int

    // Points available today to gamble with.
    var availableDailyPoints: Int
    var lastDailyPointsAwardDateISO: String?

    /// Most recent **resolved** daily ranked pool (date in `lastDailyMatch.dayISO`).
    var lastDailyMatch: DailyMatchSnapshot?

    enum CodingKeys: String, CodingKey {
        case id, displayName, mmr, currentTier, seasonPointsWon, allTimePointsWon
        case availableDailyPoints, lastDailyPointsAwardDateISO, lastDailyMatch
    }

    init(
        id: UUID,
        displayName: String,
        mmr: Double?,
        currentTier: RankTier,
        seasonPointsWon: Int,
        allTimePointsWon: Int,
        availableDailyPoints: Int,
        lastDailyPointsAwardDateISO: String?,
        lastDailyMatch: DailyMatchSnapshot? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.mmr = mmr
        self.currentTier = currentTier
        self.seasonPointsWon = seasonPointsWon
        self.allTimePointsWon = allTimePointsWon
        self.availableDailyPoints = availableDailyPoints
        self.lastDailyPointsAwardDateISO = lastDailyPointsAwardDateISO
        self.lastDailyMatch = lastDailyMatch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        mmr = try c.decodeIfPresent(Double.self, forKey: .mmr)
        currentTier = try c.decodeIfPresent(RankTier.self, forKey: .currentTier) ?? .bronze
        seasonPointsWon = try c.decodeIfPresent(Int.self, forKey: .seasonPointsWon) ?? 0
        allTimePointsWon = try c.decodeIfPresent(Int.self, forKey: .allTimePointsWon) ?? 0
        availableDailyPoints = try c.decodeIfPresent(Int.self, forKey: .availableDailyPoints) ?? 0
        lastDailyPointsAwardDateISO = try c.decodeIfPresent(String.self, forKey: .lastDailyPointsAwardDateISO)
        lastDailyMatch = try c.decodeIfPresent(DailyMatchSnapshot.self, forKey: .lastDailyMatch)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(mmr, forKey: .mmr)
        try c.encode(currentTier, forKey: .currentTier)
        try c.encode(seasonPointsWon, forKey: .seasonPointsWon)
        try c.encode(allTimePointsWon, forKey: .allTimePointsWon)
        try c.encode(availableDailyPoints, forKey: .availableDailyPoints)
        try c.encodeIfPresent(lastDailyPointsAwardDateISO, forKey: .lastDailyPointsAwardDateISO)
        try c.encodeIfPresent(lastDailyMatch, forKey: .lastDailyMatch)
    }
}

struct DailyMatchSnapshot: Codable, Equatable {
    var dayISO: String
    var placement: Int
    var poolSize: Int
    var mmrBefore: Double
    var mmrDelta: Double
    var mmrAfter: Double
    var tierBefore: RankTier
    var tierAfter: RankTier
}

// MARK: - Daily closest-pick tournament (one entry per UTC day)

/// A slate game the user can choose for the daily bracket (dev data; production comes from the schedule service).
struct DailyGameOption: Identifiable, Equatable, Codable {
    var id: String
    var label: String
    /// Game start (used for display).
    var tipOffAt: Date
    /// Entry closes one hour before tip-off so the backend can finalize brackets.
    var entryClosesAt: Date
}

struct DailyClosestTournamentState: Codable, Equatable {
    var tournamentId: UUID
    var dayISO: String
    var gameId: String
    /// e.g. "LAL @ BOS"
    var gameLabel: String
    var tipOffAt: Date
    var entryClosesAt: Date
    var bracketSize: Int
    /// Single-elim index 0..<bracketSize
    var userSlot: Int
    /// Next quarter to play (1...4 for 16 players).
    var nextQuarter: Int
    var eliminated: Bool
    var completed: Bool
    var roundsCompleted: [DailyClosestQuarterResult]

    enum CodingKeys: String, CodingKey {
        case tournamentId, dayISO, gameId, gameLabel, tipOffAt, entryClosesAt
        case bracketSize, userSlot, nextQuarter, eliminated, completed, roundsCompleted
    }

    init(
        tournamentId: UUID,
        dayISO: String,
        gameId: String,
        gameLabel: String,
        tipOffAt: Date,
        entryClosesAt: Date,
        bracketSize: Int,
        userSlot: Int,
        nextQuarter: Int,
        eliminated: Bool,
        completed: Bool,
        roundsCompleted: [DailyClosestQuarterResult]
    ) {
        self.tournamentId = tournamentId
        self.dayISO = dayISO
        self.gameId = gameId
        self.gameLabel = gameLabel
        self.tipOffAt = tipOffAt
        self.entryClosesAt = entryClosesAt
        self.bracketSize = bracketSize
        self.userSlot = userSlot
        self.nextQuarter = nextQuarter
        self.eliminated = eliminated
        self.completed = completed
        self.roundsCompleted = roundsCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tournamentId = try c.decode(UUID.self, forKey: .tournamentId)
        dayISO = try c.decode(String.self, forKey: .dayISO)
        gameId = try c.decodeIfPresent(String.self, forKey: .gameId) ?? ""
        gameLabel = try c.decode(String.self, forKey: .gameLabel)
        tipOffAt = try c.decodeIfPresent(Date.self, forKey: .tipOffAt) ?? .distantFuture
        entryClosesAt = try c.decodeIfPresent(Date.self, forKey: .entryClosesAt) ?? .distantPast
        bracketSize = try c.decode(Int.self, forKey: .bracketSize)
        userSlot = try c.decode(Int.self, forKey: .userSlot)
        nextQuarter = try c.decode(Int.self, forKey: .nextQuarter)
        eliminated = try c.decode(Bool.self, forKey: .eliminated)
        completed = try c.decode(Bool.self, forKey: .completed)
        roundsCompleted = try c.decode([DailyClosestQuarterResult].self, forKey: .roundsCompleted)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tournamentId, forKey: .tournamentId)
        try c.encode(dayISO, forKey: .dayISO)
        try c.encode(gameId, forKey: .gameId)
        try c.encode(gameLabel, forKey: .gameLabel)
        try c.encode(tipOffAt, forKey: .tipOffAt)
        try c.encode(entryClosesAt, forKey: .entryClosesAt)
        try c.encode(bracketSize, forKey: .bracketSize)
        try c.encode(userSlot, forKey: .userSlot)
        try c.encode(nextQuarter, forKey: .nextQuarter)
        try c.encode(eliminated, forKey: .eliminated)
        try c.encode(completed, forKey: .completed)
        try c.encode(roundsCompleted, forKey: .roundsCompleted)
    }
}

struct DailyClosestQuarterResult: Codable, Equatable {
    var quarter: Int
    var propLabel: String
    var userPick: Double
    var opponentPick: Double
    var opponentLabel: String
    var actualTotalPoints: Double
    var userWon: Bool
    var userError: Double
    var opponentError: Double
    var rewardSeasonPoints: Int
}

struct DailyClosestPickResult: Equatable {
    var quarter: DailyClosestQuarterResult
    var eliminated: Bool
    var wonTournament: Bool
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

    /// Display order low → high (used for daily tier up/down).
    static let ladderOrder: [RankTier] = [
        .bronze, .silver, .gold, .platinum, .emerald, .diamond, .challenger, .champion
    ]

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

    func tierAbove() -> RankTier? {
        guard let i = Self.ladderOrder.firstIndex(of: self), i + 1 < Self.ladderOrder.count else { return nil }
        return Self.ladderOrder[i + 1]
    }

    func tierBelow() -> RankTier? {
        guard let i = Self.ladderOrder.firstIndex(of: self), i > 0 else { return nil }
        return Self.ladderOrder[i - 1]
    }

    /// SF Symbol for the daily tournament win badge at this rank.
    var tournamentWinBadgeSystemImage: String {
        switch self {
        case .bronze: return "leaf.circle.fill"
        case .silver: return "moon.circle.fill"
        case .gold: return "star.circle.fill"
        case .platinum: return "square.fill.on.circle.fill"
        case .emerald: return "diamond.fill"
        case .diamond: return "sparkles"
        case .challenger: return "flame.fill"
        case .champion: return "trophy.fill"
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
    /// When set (e.g. `1.5`), displayed decimal odds use `oddsDecimal * juicdMultiplier` for the nightly Juicd boost.
    var juicdMultiplier: Double?

    var juicdEffectiveDecimalOdds: Double {
        oddsDecimal * (juicdMultiplier ?? 1)
    }

    init(
        id: UUID,
        leagueTag: String,
        athleteOrTeam: String,
        matchup: String,
        propDescription: String,
        lineText: String,
        pickLabel: String,
        oddsDecimal: Double,
        juicdMultiplier: Double? = nil
    ) {
        self.id = id
        self.leagueTag = leagueTag
        self.athleteOrTeam = athleteOrTeam
        self.matchup = matchup
        self.propDescription = propDescription
        self.lineText = lineText
        self.pickLabel = pickLabel
        self.oddsDecimal = oddsDecimal
        self.juicdMultiplier = juicdMultiplier
    }
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
