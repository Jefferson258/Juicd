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

        /// One active weekly bracket per user (prototype).
        var userBracket: [UUID: UserBracketProgress] = [:]
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

        let profile = Profile(
            id: UUID(),
            displayName: safeName,
            currentTier: tier(forSeasonPointsWon: 0),
            seasonPointsWon: 0,
            allTimePointsWon: 0,
            availableDailyPoints: 0,
            lastDailyPointsAwardDateISO: nil
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

    func awardDailyPointsIfNeeded(userId: UUID, date: Date = .now) -> Profile? {
        guard var profile = state.profiles[userId] else { return nil }

        let dayISO = Self.isoDay(date)
        if profile.lastDailyPointsAwardDateISO == dayISO {
            return profile
        }

        // Exactly 10 points daily to gamble.
        profile.availableDailyPoints += 10
        profile.lastDailyPointsAwardDateISO = dayISO

        let entry = PointsLedgerEntry(
            id: UUID(),
            createdAt: date,
            userId: userId,
            tournamentId: nil,
            betSlipId: nil,
            deltaPoints: 10,
            reason: "Daily points award"
        )

        state.profiles[userId] = profile
        state.ledger.append(entry)
        persist()
        return profile
    }

    // MARK: - Rankings (tiers from season points won)

    func recalculateTier(for userId: UUID) {
        guard var profile = state.profiles[userId] else { return }
        profile.currentTier = tier(forSeasonPointsWon: profile.seasonPointsWon)
        state.profiles[userId] = profile
        persist()
    }

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

            recalculateTier(for: userId)

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
        profile.currentTier = tier(forSeasonPointsWon: 0)
        state.profiles[userId] = profile
        // Prototype: keep existing badges; only the season points reset.
        persist()
    }

    // MARK: - Weekly bracket tournament (top 50% of 100 advance each day)

    func bracketDefinitions() -> [WeeklyBracketDefinition] {
        BracketCatalog.all
    }

    func bracketProgress(for userId: UUID) -> UserBracketProgress? {
        state.userBracket[userId]
    }

    func joinBracket(userId: UUID, definitionId: UUID) {
        guard BracketCatalog.all.contains(where: { $0.id == definitionId }) else { return }
        let progress = UserBracketProgress(
            definitionId: definitionId,
            nextRoundToPlay: 1,
            survivedRounds: 0,
            eliminated: false,
            completed: false,
            dayScores: [],
            totalBonusAwarded: 0
        )
        state.userBracket[userId] = progress
        persist()
    }

    struct BracketRoundResult {
        var roundIndex: Int
        var userScore: Int
        var rank: Int
        var advanced: Bool
        var eliminated: Bool
        var completedTournament: Bool
        var bonusAwarded: Int
    }

    func simulateNextBracketRound(userId: UUID, date: Date = .now) -> BracketRoundResult? {
        guard var progress = state.userBracket[userId], var profile = state.profiles[userId] else { return nil }
        guard let def = BracketCatalog.all.first(where: { $0.id == progress.definitionId }) else { return nil }
        if progress.completed || progress.eliminated { return nil }

        let roundIndex = progress.nextRoundToPlay
        guard roundIndex >= 1, roundIndex <= def.roundCount else { return nil }

        var rng = SeededRNG(seed: "\(userId.uuidString)-\(def.id.uuidString)-r\(roundIndex)".hashValueAsUInt64)
        let userScore = 40 + Int(rng.nextDouble() * 60)

        var entries: [(Bool, Int)] = (0..<99).map { i in
            var r = SeededRNG(seed: "\(userId.uuidString)-bot\(i)-r\(roundIndex)".hashValueAsUInt64)
            return (false, Int(r.nextDouble() * 100))
        }
        entries.append((true, userScore))
        let sorted = entries.sorted { $0.1 > $1.1 }
        guard let rankIdx = sorted.firstIndex(where: { $0.0 }) else { return nil }
        let rank = rankIdx + 1
        let advanced = rank <= 50

        var bonus = 0
        if advanced {
            progress.dayScores.append(userScore)
            progress.survivedRounds += 1
            progress.nextRoundToPlay += 1
            if progress.nextRoundToPlay > def.roundCount {
                progress.completed = true
                bonus = 500
                progress.totalBonusAwarded += bonus
                profile.seasonPointsWon += bonus
                profile.allTimePointsWon += bonus
                recalculateTier(for: userId)
            }
        } else {
            progress.eliminated = true
            bonus = max(0, 15 * progress.survivedRounds)
            if bonus > 0 {
                progress.totalBonusAwarded += bonus
                profile.seasonPointsWon += bonus
                profile.allTimePointsWon += bonus
                recalculateTier(for: userId)
            }
        }

        state.userBracket[userId] = progress
        state.profiles[userId] = profile
        persist()

        return BracketRoundResult(
            roundIndex: roundIndex,
            userScore: userScore,
            rank: rank,
            advanced: advanced,
            eliminated: progress.eliminated,
            completedTournament: progress.completed,
            bonusAwarded: bonus
        )
    }

    func leaveBracket(userId: UUID) {
        state.userBracket[userId] = nil
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
        guard let data = defaults.data(forKey: "juicd_persisted_state_v1") else {
            return PersistedState()
        }
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            return PersistedState()
        }
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

