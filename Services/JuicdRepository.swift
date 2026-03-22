import Foundation
import Combine

@MainActor
final class InMemoryJuicdRepository: ObservableObject {
    static let shared = InMemoryJuicdRepository()

    struct PersistedState: Codable {
        var profiles: [UUID: Profile] = [:]
        var ledger: [PointsLedgerEntry] = []
        var groups: [Group] = []
        var memberships: [GroupMembership] = []
        var rewards: [UUID: [RewardBadge]] = [:] // userId -> badges

        var dailyTournamentByDayISO: [String: Tournament] = [:]
        var dailyBets: [UUID: BetSlip] = [:]

        var activeDailyByUser: [UUID: DailyProgress] = [:] // userId -> progress

        var weeklySubmissions: [WeeklySubmission] = []

        /// UTC day `yyyy-MM-dd` → user IDs who placed at least one daily bet (enters that day’s ranked pool).
        var dailyRankParticipationByDay: [String: [UUID]] = [:]
        /// UTC day → user IDs for whom daily tier movement has already been applied.
        var dailyRankResolvedByDay: [String: [UUID]] = [:]

        /// Key `userId|yyyy-MM-dd` → closest-pick daily tournament state.
        var dailyClosestByKey: [String: DailyClosestTournamentState]?
    }

    struct DailyProgress: Codable, Hashable {
        var tournamentId: UUID
        var currentStageIndex: Int // 1..stageCount, next stage to play
        var eliminatedAtStageIndex: Int? // if eliminated in a stage
        var qualifiedStages: [Int] // stages won in order
    }

    struct WeeklySubmission: Codable, Hashable, Identifiable {
        var id: UUID
        var userId: UUID
        var groupId: UUID
        var weekIndex: Int
        var pointsEarned: Int
        var submittedAt: Date
    }

    private let storageKey = "juicd_persisted_state_v2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published private(set) var state: PersistedState

    private init() {
        self.state = Self.load()
        if state.groups.isEmpty {
            seedGroups()
        }
    }

    // MARK: - Auth (prototype)

    func signIn(displayName: String) -> Profile {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? "Demo Player" : trimmed

        // Create a new local user if none exists.
        if let existing = state.profiles.values.first(where: { $0.displayName.caseInsensitiveCompare(safeName) == .orderedSame }) {
            return existing
        }

        let start = MMRLogic.startingMMR
        let profile = Profile(
            id: UUID(),
            displayName: safeName,
            mmr: start,
            currentTier: MMRLogic.tier(for: start),
            seasonPointsWon: 0,
            allTimePointsWon: 0,
            availableDailyPoints: 0,
            lastDailyPointsAwardDateISO: nil,
            lastDailyMatch: nil
        )

        state.profiles[profile.id] = profile
        state.rewards[profile.id] = []
        persist()
        return profile
    }

    func profile(userId: UUID) -> Profile? {
        state.profiles[userId]
    }

    // MARK: - Daily points

    /// Playable balance refilled each day — **does not** affect rank tier or season score.
    static let dailyPlayAllowancePoints = 100

    func awardDailyPointsIfNeeded(userId: UUID, date: Date = .now) -> Profile? {
        guard var profile = state.profiles[userId] else { return nil }
        if profile.mmr == nil {
            profile.mmr = MMRLogic.startingMMR
            profile.currentTier = MMRLogic.tier(for: MMRLogic.startingMMR)
            state.profiles[userId] = profile
            persist()
        }

        let dayISO = Self.isoDay(date)
        if profile.lastDailyPointsAwardDateISO == dayISO {
            return profile
        }

        profile.availableDailyPoints += Self.dailyPlayAllowancePoints
        profile.lastDailyPointsAwardDateISO = dayISO

        let entry = PointsLedgerEntry(
            id: UUID(),
            createdAt: date,
            userId: userId,
            tournamentId: nil,
            betSlipId: nil,
            deltaPoints: Self.dailyPlayAllowancePoints,
            reason: "Daily play allowance (wallet only — not rank score)"
        )

        state.profiles[userId] = profile
        state.ledger.append(entry)
        persist()
        return profile
    }

    // MARK: - Rank tier (daily skill pool — not from point totals)

    /// Tier is **not** derived from `seasonPointsWon`. It moves in daily ranked pools (see `resolveDailyRankOutcomes`).
    /// `tier(forSeasonPointsWon:)` remains for legacy / display curves only.
    func tier(forSeasonPointsWon pointsWon: Int) -> RankTier {
        switch pointsWon {
        case ..<100: return .bronze
        case ..<300: return .silver
        case ..<700: return .gold
        case ..<1200: return .platinum
        case ..<1900: return .emerald
        case ..<2600: return .diamond
        case ..<3800: return .challenger
        default: return .champion
        }
    }

    func recordDailyRankParticipation(userId: UUID, date: Date = .now) {
        let dayISO = Self.isoDay(date)
        var set = Set(state.dailyRankParticipationByDay[dayISO] ?? [])
        set.insert(userId)
        state.dailyRankParticipationByDay[dayISO] = Array(set)
        persist()
    }

    /// Resolves the **previous UTC day** if the user entered a ranked match (placed a bet) and outcomes weren’t applied yet.
    /// No bet that day → no tier change (no decay).
    func resolveDailyRankOutcomes(userId: UUID, now: Date = .now) {
        guard state.profiles[userId] != nil else { return }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let yesterday = utc.date(byAdding: .day, value: -1, to: now) else { return }
        let yISO = Self.isoDay(yesterday)

        let participated = (state.dailyRankParticipationByDay[yISO] ?? []).contains(userId)
        guard participated else { return }

        var resolved = Set(state.dailyRankResolvedByDay[yISO] ?? [])
        guard !resolved.contains(userId) else { return }

        guard var profile = state.profiles[userId] else { return }

        let netProfit = netLedgerDeltaForDailyBets(userId: userId, dayISO: yISO)
        let baseMMR = profile.mmr ?? MMRLogic.startingMMR
        let tierBefore = profile.currentTier

        let poolSize = 100
        var rng = SeededRNG(seed: "\(userId.uuidString)-\(yISO)-pool".hashValueAsUInt64)

        var scores: [(Bool, Double)] = []
        scores.reserveCapacity(poolSize)
        for i in 0..<(poolSize - 1) {
            var r2 = SeededRNG(seed: "\(yISO)-bot-\(i)".hashValueAsUInt64)
            let botMMR = baseMMR + (Double(i % 17) - 8) * 14 + r2.nextDouble() * 6 - 3
            let botId = UUID()
            let perf = MMRLogic.dailyPerformanceScore(
                userId: botId,
                dayISO: yISO,
                baseMMR: botMMR,
                netProfitFromBets: Int(r2.nextDouble() * 20) - 10,
                rng: &r2
            )
            scores.append((false, perf))
        }
        let userPerf = MMRLogic.dailyPerformanceScore(
            userId: userId,
            dayISO: yISO,
            baseMMR: baseMMR,
            netProfitFromBets: netProfit,
            rng: &rng
        )
        scores.append((true, userPerf))
        scores.sort { $0.1 > $1.1 }

        guard let rankIdx = scores.firstIndex(where: { $0.0 }) else { return }
        let placement = rankIdx + 1

        let delta = MMRLogic.mmrDelta(rank: placement, poolSize: poolSize)
        let mmrAfter = baseMMR + delta
        profile.mmr = mmrAfter
        profile.currentTier = MMRLogic.tier(for: mmrAfter)
        profile.lastDailyMatch = DailyMatchSnapshot(
            dayISO: yISO,
            placement: placement,
            poolSize: poolSize,
            mmrBefore: baseMMR,
            mmrDelta: delta,
            mmrAfter: mmrAfter,
            tierBefore: tierBefore,
            tierAfter: profile.currentTier
        )
        state.profiles[userId] = profile

        resolved.insert(userId)
        state.dailyRankResolvedByDay[yISO] = Array(resolved)
        persist()
    }

    /// Net ledger change from daily tournament bets on that UTC day (stakes + payouts).
    private func netLedgerDeltaForDailyBets(userId: UUID, dayISO: String) -> Int {
        state.ledger.reduce(0) { partial, entry in
            guard entry.userId == userId else { return partial }
            guard Self.isoDay(entry.createdAt) == dayISO else { return partial }
            guard entry.reason.contains("Daily bet") || entry.reason.contains("Daily closest") else { return partial }
            return partial + entry.deltaPoints
        }
    }

    // MARK: - Daily closest-pick tournament (16 players, 4 quarters)

    /// Dev slate: each game has tip-off staggered from `now`; entry closes **1 hour before** tip-off.
    func dailyGameOptions(now: Date = .now) -> [DailyGameOption] {
        let catalog: [(String, String)] = [
            ("nba_lal_bos", "LAL @ BOS"),
            ("nba_phx_den", "PHX @ DEN"),
            ("nfl_kc_buf", "KC @ BUF"),
            ("nhl_edm_col", "EDM @ COL")
        ]
        return catalog.enumerated().map { i, item in
            let hoursAhead = 3 + i * 2
            let tip = now.addingTimeInterval(TimeInterval(hoursAhead * 3600))
            let entry = tip.addingTimeInterval(-3600)
            return DailyGameOption(id: item.0, label: item.1, tipOffAt: tip, entryClosesAt: entry)
        }
    }

    private func dailyClosestStorageKey(userId: UUID, dayISO: String) -> String {
        "\(userId.uuidString)|\(dayISO)"
    }

    func dailyClosestState(userId: UUID, date: Date = .now) -> DailyClosestTournamentState? {
        let k = dailyClosestStorageKey(userId: userId, dayISO: Self.isoDay(date))
        return state.dailyClosestByKey?[k]
    }

    @discardableResult
    func enterDailyClosestTournament(userId: UUID, gameId: String, date: Date = .now) -> DailyClosestTournamentState? {
        guard state.profiles[userId] != nil else { return nil }
        let dayISO = Self.isoDay(date)
        let k = dailyClosestStorageKey(userId: userId, dayISO: dayISO)
        if let existing = state.dailyClosestByKey?[k] { return existing }

        guard let game = dailyGameOptions(now: date).first(where: { $0.id == gameId }) else { return nil }
        guard date < game.entryClosesAt else { return nil }

        let t = dailyTournament(for: date)
        var rng = SeededRNG(seed: "\(userId.uuidString)-\(dayISO)-closest".hashValueAsUInt64)
        let slot = Int(rng.nextDouble() * 16)

        let st = DailyClosestTournamentState(
            tournamentId: t.id,
            dayISO: dayISO,
            gameId: game.id,
            gameLabel: game.label,
            tipOffAt: game.tipOffAt,
            entryClosesAt: game.entryClosesAt,
            bracketSize: 16,
            userSlot: slot,
            nextQuarter: 1,
            eliminated: false,
            completed: false,
            roundsCompleted: []
        )
        var map = state.dailyClosestByKey ?? [:]
        map[k] = st
        state.dailyClosestByKey = map
        recordDailyRankParticipation(userId: userId, date: date)
        persist()
        return st
    }

    func submitDailyClosestPick(userId: UUID, pick: Double, date: Date = .now) -> DailyClosestPickResult? {
        guard state.profiles[userId] != nil else { return nil }
        let dayISO = Self.isoDay(date)
        let k = dailyClosestStorageKey(userId: userId, dayISO: dayISO)
        guard var st = state.dailyClosestByKey?[k] else { return nil }
        guard !st.eliminated, !st.completed else { return nil }
        let q = st.nextQuarter
        guard q >= 1, q <= 4 else { return nil }

        var rng = SeededRNG(seed: "\(st.tournamentId.uuidString)-\(dayISO)-Q\(q)-\(st.userSlot)".hashValueAsUInt64)
        let actual = 36 + rng.nextDouble() * 38
        let frac = floor(rng.nextDouble() * 10) / 10
        let actualTotal = (actual + frac).rounded(toPlaces: 1)

        let oppSlot = st.userSlot ^ 1
        let oppLabel = MMRLogic.opponentName(seed: rng.nextUInt64(), index: oppSlot + q * 17)
        var rOpp = SeededRNG(seed: "\(dayISO)-opp-\(oppSlot)-\(q)".hashValueAsUInt64)
        let opponentPick = actualTotal + (rOpp.nextDouble() - 0.5) * 24

        let uErr = abs(pick - actualTotal)
        let oErr = abs(opponentPick - actualTotal)
        let userWon: Bool
        if abs(uErr - oErr) > 1e-6 {
            userWon = uErr < oErr
        } else {
            let ut = (pick * 1337).truncatingRemainder(dividingBy: 1)
            let vt = (opponentPick * 1337).truncatingRemainder(dividingBy: 1)
            if abs(ut - vt) > 1e-9 {
                userWon = ut < vt
            } else {
                userWon = pick < opponentPick
            }
        }

        let reward = max(
            0,
            min(45, Int(48 * (1 - min(1, uErr / 18))))
        )

        let propLabel = "Combined points scored (Q\(q))"
        let round = DailyClosestQuarterResult(
            quarter: q,
            propLabel: propLabel,
            userPick: pick,
            opponentPick: opponentPick,
            opponentLabel: oppLabel,
            actualTotalPoints: actualTotal,
            userWon: userWon,
            userError: uErr,
            opponentError: oErr,
            rewardSeasonPoints: reward
        )

        st.roundsCompleted.append(round)

        if userWon {
            var profile = state.profiles[userId]!
            profile.seasonPointsWon += reward
            profile.allTimePointsWon += reward
            state.profiles[userId] = profile
            state.ledger.append(
                PointsLedgerEntry(
                    id: UUID(),
                    createdAt: date,
                    userId: userId,
                    tournamentId: st.tournamentId,
                    betSlipId: nil,
                    deltaPoints: reward,
                    reason: "Daily closest reward (Q\(q))"
                )
            )

            st.userSlot >>= 1
            st.nextQuarter += 1
            if st.nextQuarter > 4 {
                st.completed = true
                let cupBonus = 120
                profile = state.profiles[userId]!
                let tierAtWin = profile.currentTier
                profile.seasonPointsWon += cupBonus
                profile.allTimePointsWon += cupBonus
                state.profiles[userId] = profile
                state.ledger.append(
                    PointsLedgerEntry(
                        id: UUID(),
                        createdAt: date,
                        userId: userId,
                        tournamentId: st.tournamentId,
                        betSlipId: nil,
                        deltaPoints: cupBonus,
                        reason: "Daily closest — win bracket"
                    )
                )
                awardDailyTournamentWinBadge(userId: userId, tier: tierAtWin)
            }
        } else {
            st.eliminated = true
        }

        var map = state.dailyClosestByKey ?? [:]
        map[k] = st
        state.dailyClosestByKey = map
        persist()

        return DailyClosestPickResult(
            quarter: round,
            eliminated: !userWon,
            wonTournament: st.completed
        )
    }

    // MARK: - Tournament lifecycle

    func dailyTournament(for date: Date = .now) -> Tournament {
        let dayISO = Self.isoDay(date)
        if let existing = state.dailyTournamentByDayISO[dayISO] {
            return existing
        }

        let startAt = Calendar.current.startOfDay(for: date).addingTimeInterval(8 * 3600) // 8am local
        let endAt = startAt.addingTimeInterval(6 * 3600) // 6h window

        let t = Tournament(
            id: UUID(),
            kind: .daily,
            status: .active,
            startAt: startAt,
            endAt: endAt,
            stageCount: 4,
            seasonYear: Calendar.current.component(.year, from: date)
        )
        state.dailyTournamentByDayISO[dayISO] = t
        persist()
        return t
    }

    func dailyProgress(for userId: UUID, date: Date = .now) -> DailyProgress? {
        let t = dailyTournament(for: date)
        return state.activeDailyByUser[userId].flatMap { $0.tournamentId == t.id ? $0 : nil }
    }

    func ensureDailyProgress(for userId: UUID, date: Date = .now) -> DailyProgress? {
        guard let _ = state.profiles[userId] else { return nil }
        let t = dailyTournament(for: date)
        if let progress = state.activeDailyByUser[userId], progress.tournamentId == t.id {
            return progress
        }

        let created = DailyProgress(tournamentId: t.id, currentStageIndex: 1, eliminatedAtStageIndex: nil, qualifiedStages: [])
        state.activeDailyByUser[userId] = created
        persist()
        return created
    }

    struct QuarterResult {
        var didWinAllLegs: Bool
        var stageIndex: Int
        var pointsDelta: Int
        var eliminated: Bool
        var nextStageIndex: Int?
    }

    // Resolves a quarter stage: user must win all legs to qualify.
    func submitDailyQuarterParlay(
        userId: UUID,
        stageIndex: Int,
        stakePoints: Int,
        legs: [BetLeg],
        oddsImpliedParlayOddsDecimalAtSubmit: Double,
        estimatedNetPointsPayout: Int,
        date: Date = .now
    ) -> QuarterResult? {
        guard var profile = state.profiles[userId] else { return nil }
        let tournament = dailyTournament(for: date)
        guard stageIndex >= 1 && stageIndex <= tournament.stageCount else { return nil }
        guard profile.availableDailyPoints >= stakePoints else { return nil }

        recordDailyRankParticipation(userId: userId, date: date)

        // Deduct stake immediately.
        profile.availableDailyPoints -= stakePoints
        state.profiles[userId] = profile
        let stakeEntry = PointsLedgerEntry(
            id: UUID(),
            createdAt: date,
            userId: userId,
            tournamentId: tournament.id,
            betSlipId: nil,
            deltaPoints: -stakePoints,
            reason: "Daily bet stake (Q\(stageIndex))"
        )
        state.ledger.append(stakeEntry)

        // Resolve with implied probability model: p(win) ~ 1 / oddsDecimal.
        let resolved = resolveLegs(parlayLegs: legs, seedKey: "\(userId.uuidString)-\(tournament.id.uuidString)-Q\(stageIndex)")
        let didWinAllLegs = resolved.allSatisfy { $0.didWin }

        var pointsDelta = -stakePoints
        if didWinAllLegs {
            // Add back payout including stake.
            let payoutIncludingStake = Int(Double(stakePoints) * oddsImpliedParlayOddsDecimalAtSubmit.rounded(toPlaces: 4))
            profile.availableDailyPoints += payoutIncludingStake

            state.profiles[userId] = profile

            let profit = max(0, estimatedNetPointsPayout)
            pointsDelta = profit
            // Award "points won" toward season ranking.
            profile.seasonPointsWon += profit
            profile.allTimePointsWon += profit
            state.profiles[userId] = profile

            let winEntry = PointsLedgerEntry(
                id: UUID(),
                createdAt: date,
                userId: userId,
                tournamentId: tournament.id,
                betSlipId: nil,
                deltaPoints: payoutIncludingStake,
                reason: "Daily bet payout (Q\(stageIndex))"
            )
            state.ledger.append(winEntry)
        }

        // Persist bet slip record.
        let betSlip = BetSlip(
            id: UUID(),
            userId: userId,
            tournamentId: tournament.id,
            stageIndex: stageIndex,
            stakePoints: stakePoints,
            legs: legs,
            impliedParlayOddsDecimalAtSubmit: oddsImpliedParlayOddsDecimalAtSubmit,
            estimatedNetPointsPayout: estimatedNetPointsPayout,
            status: didWinAllLegs ? .resolved : .eliminated,
            didWinAllLegs: didWinAllLegs,
            resolvedAt: date
        )
        state.dailyBets[betSlip.id] = betSlip

        // Update progression.
        var progress: DailyProgress
        if let existing = state.activeDailyByUser[userId], existing.tournamentId == tournament.id {
            progress = existing
        } else {
            progress = DailyProgress(tournamentId: tournament.id, currentStageIndex: stageIndex, eliminatedAtStageIndex: nil, qualifiedStages: [])
        }

        let eliminated = !didWinAllLegs
        if eliminated {
            progress.eliminatedAtStageIndex = stageIndex
        } else {
            progress.qualifiedStages.append(stageIndex)
        }

        let nextStageIndex = (!eliminated && stageIndex < tournament.stageCount) ? (stageIndex + 1) : nil
        progress.currentStageIndex = nextStageIndex ?? (stageIndex + 1)
        state.activeDailyByUser[userId] = progress
        persist()

        return QuarterResult(
            didWinAllLegs: didWinAllLegs,
            stageIndex: stageIndex,
            pointsDelta: pointsDelta,
            eliminated: eliminated,
            nextStageIndex: nextStageIndex
        )
    }

    private func resolveLegs(parlayLegs: [BetLeg], seedKey: String) -> [(legId: UUID, didWin: Bool)] {
        var rng = SeededRNG(seed: seedKey.hashValueAsUInt64)
        var outcomes: [(legId: UUID, didWin: Bool)] = []
        outcomes.reserveCapacity(parlayLegs.count)
        for leg in parlayLegs {
            // Odds are "decimal". Approx implied probability = 1/odds.
            let p = min(max(1.0 / max(1.01, leg.oddsDecimalAtSubmit), 0.05), 0.95)
            let roll = rng.nextDouble()
            outcomes.append((legId: leg.id, didWin: roll < p))
        }
        return outcomes
    }

    // MARK: - Parlay math

    func parlayOddsDecimal(for legs: [BetLeg]) -> Double {
        guard !legs.isEmpty else { return 1.0 }
        return legs.reduce(1.0) { $0 * $1.oddsDecimalAtSubmit }
    }

    func estimatedNetPointsPayout(stakePoints: Int, parlayOddsDecimal: Double) -> Int {
        guard stakePoints > 0 else { return 0 }
        let profit = Double(stakePoints) * (parlayOddsDecimal - 1.0)
        return max(0, Int(profit.rounded()))
    }

    // MARK: - Groups + Weekly mock

    func groupsForUser(_ userId: UUID) -> [Group] {
        let groupIds = Set(state.memberships.filter { $0.userId == userId }.map { $0.groupId })
        return state.groups.filter { groupIds.contains($0.id) }
    }

    func createGroup(name: String, createdBy userId: UUID) -> Group {
        let group = Group(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Group" : name,
            inviteCode: Self.generateInviteCode(),
            createdAt: .now
        )
        state.groups.append(group)
        state.memberships.append(GroupMembership(id: UUID(), groupId: group.id, userId: userId, joinedAt: .now))
        persist()
        return group
    }

    func joinGroup(byInviteCode code: String, userId: UUID) -> Group? {
        let match = state.groups.first(where: { $0.inviteCode.caseInsensitiveCompare(code) == .orderedSame })
        guard let group = match else { return nil }
        if state.memberships.contains(where: { $0.userId == userId && $0.groupId == group.id }) {
            return group
        }
        state.memberships.append(GroupMembership(id: UUID(), groupId: group.id, userId: userId, joinedAt: .now))
        persist()
        return group
    }

    func submitWeeklyPicks(groupId: UUID, weekIndex: Int, userId: UUID) -> Int {
        // Prototype: converts a user's weekly picks into points earned.
        let points = mockWeeklyPoints(userId: userId, groupId: groupId, weekIndex: weekIndex)

        if let idx = state.weeklySubmissions.firstIndex(where: { $0.userId == userId && $0.groupId == groupId && $0.weekIndex == weekIndex }) {
            state.weeklySubmissions[idx].pointsEarned = points
            state.weeklySubmissions[idx].submittedAt = .now
        } else {
            state.weeklySubmissions.append(
                WeeklySubmission(
                    id: UUID(),
                    userId: userId,
                    groupId: groupId,
                    weekIndex: weekIndex,
                    pointsEarned: points,
                    submittedAt: .now
                )
            )
        }

        persist()
        return points
    }

    func weeklyGroupScoreboard(for groupId: UUID, weekIndex: Int) -> [(userName: String, points: Int)] {
        let members = state.memberships.filter { $0.groupId == groupId }
        return members.compactMap { membership in
            guard let profile = state.profiles[membership.userId] else { return nil }
            let points = state.weeklySubmissions.first(where: { $0.userId == membership.userId && $0.groupId == groupId && $0.weekIndex == weekIndex })?.pointsEarned
                ?? mockWeeklyPoints(userId: membership.userId, groupId: groupId, weekIndex: weekIndex)
            return (profile.displayName, points)
        }.sorted { $0.points > $1.points }
    }

    private func mockWeeklyPoints(userId: UUID, groupId: UUID, weekIndex: Int) -> Int {
        var rng = SeededRNG(seed: "\(groupId.uuidString)-w\(weekIndex)-\(userId.uuidString)".hashValueAsUInt64)
        let p = 5 + Int(rng.nextDouble() * 30)
        return p
    }

    func weeklyPointsForUser(userId: UUID, groupId: UUID, weekIndex: Int) -> Int {
        state.weeklySubmissions.first(where: { $0.userId == userId && $0.groupId == groupId && $0.weekIndex == weekIndex })?.pointsEarned
            ?? mockWeeklyPoints(userId: userId, groupId: groupId, weekIndex: weekIndex)
    }

    func weeklySubmittedPointsForUser(userId: UUID, groupId: UUID, weekIndex: Int) -> Int? {
        state.weeklySubmissions.first(where: { $0.userId == userId && $0.groupId == groupId && $0.weekIndex == weekIndex })?.pointsEarned
    }

    // MARK: - Rewards (badges)

    func userBadges(userId: UUID) -> [RewardBadge] {
        state.rewards[userId] ?? []
    }

    func awardDailyQuarterBadgesIfNeeded(userId: UUID, after stageIndex: Int) {
        // Prototype: award a badge for winning Q1 and Q4.
        guard let progress = dailyProgress(for: userId), progress.tournamentId == dailyTournament(for: .now).id else { return }
        guard state.profiles[userId] != nil else { return }
        let earned = progress.qualifiedStages.contains(stageIndex)
        guard earned else { return }

        let badgeTitle: String
        let badgeImage: String
        switch stageIndex {
        case 1: badgeTitle = "First Quarter Finisher"; badgeImage = "1.circle"
        case 4: badgeTitle = "Quarter King"; badgeImage = "4.circle"
        default: return
        }

        let badge = RewardBadge(
            id: UUID(),
            title: badgeTitle,
            description: "Win a parlay to qualify at stage Q\(stageIndex).",
            achievedAt: .now,
            imageSystemName: badgeImage
        )
        if !(state.rewards[userId] ?? []).contains(where: { $0.title == badge.title }) {
            state.rewards[userId, default: []].append(badge)
            persist()
        }
    }

    func awardDailyTournamentWinBadge(userId: UUID, tier: RankTier) {
        let title = "\(tier.displayName) Daily Cup"
        let badge = RewardBadge(
            id: UUID(),
            title: title,
            description: "Won the daily closest-pick tournament at \(tier.displayName) rank.",
            achievedAt: .now,
            imageSystemName: tier.tournamentWinBadgeSystemImage
        )
        if !(state.rewards[userId] ?? []).contains(where: { $0.title == badge.title }) {
            state.rewards[userId, default: []].append(badge)
            persist()
        }
    }

    func awardSeasonBadgesIfNeeded(userId: UUID) {
        // Prototype: badge tiers based on current tier.
        guard let profile = state.profiles[userId] else { return }
        let tier = profile.currentTier
        let badge = RewardBadge(
            id: UUID(),
            title: "\(tier.displayName) Season Badge",
            description: "Earned from points won during the season.",
            achievedAt: .now,
            imageSystemName: "rosette"
        )
        if !(state.rewards[userId] ?? []).contains(where: { $0.title == badge.title }) {
            state.rewards[userId, default: []].append(badge)
            persist()
        }
    }

    func resetSeason(for userId: UUID) {
        guard var profile = state.profiles[userId] else { return }
        profile.seasonPointsWon = 0
        profile.mmr = MMRLogic.startingMMR
        profile.currentTier = MMRLogic.tier(for: MMRLogic.startingMMR)
        profile.lastDailyMatch = nil
        state.profiles[userId] = profile
        // Prototype: keep existing badges; only the season points reset.
        persist()
    }

    // MARK: - Local persistence helpers

    private func seedGroups() {
        let g1 = Group(id: UUID(), name: "Underdog Squad", inviteCode: Self.generateInviteCode(), createdAt: .now.addingTimeInterval(-86400 * 2))
        let g2 = Group(id: UUID(), name: "Rocket Quarterbacks", inviteCode: Self.generateInviteCode(), createdAt: .now.addingTimeInterval(-86400 * 5))
        state.groups = [g1, g2]
        persist()
    }

    private static func load() -> PersistedState {
        let defaults = UserDefaults.standard
        let keys = ["juicd_persisted_state_v2", "juicd_persisted_state_v1"]
        for key in keys {
            guard let data = defaults.data(forKey: key) else { continue }
            do {
                return try JSONDecoder().decode(PersistedState.self, from: data)
            } catch {
                continue
            }
        }
        return PersistedState()
    }

    private func persist() {
        do {
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Prototype: ignore persistence errors.
        }
    }

    // MARK: - Utilities

    private static func isoDay(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private static func generateInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var rng = SystemRandomNumberGenerator()
        return String((0..<6).map { _ in alphabet.randomElement(using: &rng)! })
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

private extension UInt64 {
    func toInt() -> Int { Int(self) }
}

private extension Int {
    var hashValueAsUInt64: UInt64 { UInt64(bitPattern: Int64(self)) }
}

private extension String {
    var hashValueAsUInt64: UInt64 { self.hashValue.hashValueAsUInt64 }
}

private extension Int64 {
    var hashValueAsUInt64: UInt64 { UInt64(bitPattern: self) }
}

