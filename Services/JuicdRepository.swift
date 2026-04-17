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

    /// UTC day `yyyy-MM-dd` → user IDs who placed at least one Play bet (enters that day’s ranked pool).
        var dailyRankParticipationByDay: [String: [UUID]] = [:]
        /// UTC day → user IDs for whom daily tier movement has already been applied.
        var dailyRankResolvedByDay: [String: [UUID]] = [:]

        /// Key `userId|yyyy-MM-dd` → closest-pick daily tournament state.
        var dailyClosestByKey: [String: DailyClosestTournamentState]?

        /// Play-board slips (single or parlay) for dashboard history.
        var playBoardEntries: [PlayBoardEntry]?

        /// Pending friend invites (prototype persistence; mirror `friend_requests` in Supabase).
        var friendRequests: [FriendRequest]?
        /// Accepted friendships — canonical `(min UUID, max UUID)` pair per edge.
        var friendships: [Friendship]?
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

    func awardDailyPointsIfNeeded(userId: UUID, date: Date = .now) -> Profile? {
        guard var profile = state.profiles[userId] else { return nil }
        if profile.mmr == nil {
            profile.mmr = MMRLogic.startingMMR
            profile.currentTier = MMRLogic.tier(for: MMRLogic.startingMMR)
            state.profiles[userId] = profile
            persist()
        }

        let slateKey = SlateDay.slateKey(for: date)
        if profile.lastDailyPointsAwardDateISO == slateKey {
            return profile
        }

        profile.availableDailyPoints = JuicdBalance.dailyPlayAllowancePoints
        profile.lastDailyPointsAwardDateISO = slateKey

        let entry = PointsLedgerEntry(
            id: UUID(),
            createdAt: date,
            userId: userId,
            tournamentId: nil,
            betSlipId: nil,
            deltaPoints: JuicdBalance.dailyPlayAllowancePoints,
            reason: "Daily play allowance reset (wallet only — not rank score)"
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
        let slateKey = SlateDay.slateKey(for: date)
        var set = Set(state.dailyRankParticipationByDay[slateKey] ?? [])
        set.insert(userId)
        state.dailyRankParticipationByDay[slateKey] = Array(set)
        persist()
    }

    /// Resolves the **previous local slate** (6am boundary) if the user entered a ranked match and outcomes weren’t applied yet.
    func resolveDailyRankOutcomes(userId: UUID, now: Date = .now) {
        guard state.profiles[userId] != nil else { return }
        let prevSlate = SlateDay.previousSlateKey(from: now)

        let participated = (state.dailyRankParticipationByDay[prevSlate] ?? []).contains(userId)
        guard participated else { return }

        var resolved = Set(state.dailyRankResolvedByDay[prevSlate] ?? [])
        guard !resolved.contains(userId) else { return }

        guard var profile = state.profiles[userId] else { return }

        let normalizedNetAtHundred = normalizedNetPerformanceAtHundredOnSlate(userId: userId, slateKey: prevSlate)
        let baseMMR = profile.mmr ?? MMRLogic.startingMMR
        let tierBefore = profile.currentTier

        let poolSize = MMRLogic.dailyRankGroupSize
        var rng = SeededRNG(seed: "\(userId.uuidString)-\(prevSlate)-pool".hashValueAsUInt64)

        var scores: [(Bool, Double)] = []
        scores.reserveCapacity(poolSize)
        for i in 0..<(poolSize - 1) {
            var r2 = SeededRNG(seed: "\(prevSlate)-bot-\(i)".hashValueAsUInt64)
            let botMMR = baseMMR + (Double(i % 17) - 8) * 14 + r2.nextDouble() * 6 - 3
            let botId = UUID()
            let botScaled = (r2.nextDouble() * 120) - 60
            let perf = MMRLogic.dailyPerformanceScore(
                userId: botId,
                dayISO: prevSlate,
                baseMMR: botMMR,
                normalizedNetAtHundred: botScaled,
                rng: &r2
            )
            scores.append((false, perf))
        }
        let userPerf = MMRLogic.dailyPerformanceScore(
            userId: userId,
            dayISO: prevSlate,
            baseMMR: baseMMR,
            normalizedNetAtHundred: normalizedNetAtHundred,
            rng: &rng
        )
        scores.append((true, userPerf))
        scores.sort { $0.1 > $1.1 }

        guard let rankIdx = scores.firstIndex(where: { $0.0 }) else { return }
        let placement = rankIdx + 1

        let rawDelta = MMRLogic.mmrDelta(rank: placement, poolSize: poolSize)
        let mmrAfter = MMRLogic.smoothedMMR(currentMMR: baseMMR, rawDelta: rawDelta)
        let appliedDelta = mmrAfter - baseMMR
        profile.mmr = mmrAfter
        profile.currentTier = MMRLogic.tier(for: mmrAfter)
        profile.lastDailyMatch = DailyMatchSnapshot(
            dayISO: prevSlate,
            placement: placement,
            poolSize: poolSize,
            mmrBefore: baseMMR,
            mmrDelta: appliedDelta,
            mmrAfter: mmrAfter,
            tierBefore: tierBefore,
            tierAfter: profile.currentTier
        )
        state.profiles[userId] = profile

        resolved.insert(userId)
        state.dailyRankResolvedByDay[prevSlate] = Array(resolved)
        persist()
    }

    /// Scales Play-only daily results to a 100-point baseline so users are ranked by quality, not by spending all points.
    /// Example: spending 10 points for +5 net => +50 at 100.
    private func normalizedNetPerformanceAtHundredOnSlate(userId: UUID, slateKey: String) -> Double {
        var staked = 0
        var net = 0
        for entry in state.ledger where entry.userId == userId {
            guard SlateDay.slateKey(for: entry.createdAt) == slateKey else { continue }
            if entry.reason == "Play parlay stake" {
                staked += abs(entry.deltaPoints)
                net += entry.deltaPoints
            } else if entry.reason == "Play parlay payout" {
                net += entry.deltaPoints
            }
        }
        guard staked > 0 else { return 0 }
        let roi = Double(net) / Double(staked)
        return roi * Double(JuicdBalance.dailyPlayAllowancePoints)
    }

    func playBoardEntriesOnSlate(userId: UUID, date: Date = .now) -> [PlayBoardEntry] {
        let sk = SlateDay.slateKey(for: date)
        return (state.playBoardEntries ?? [])
            .filter { $0.userId == userId && $0.slateDayKey == sk }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Daily closest-pick tournament (16 players, 4 quarters)

    /// Dev slate: several tournament *variants* with four distinct round previews; tip times stagger from `now`; entry closes **1 hour before** lock.
    func dailyGameOptions(now: Date = .now) -> [DailyGameOption] {
        let nflRounds: [DailyRoundPreview] = [
            DailyRoundPreview(
                round: 1,
                title: "Stefon Diggs — Q1 receiving yards",
                subtitle: "Total receiving yards in the first quarter (simulated).",
                simMin: 0,
                simMax: 52
            ),
            DailyRoundPreview(
                round: 2,
                title: "Josh Allen — Q2 passing TDs",
                subtitle: "Passing touchdowns in the second quarter (tenths allowed).",
                simMin: 0,
                simMax: 3.5
            ),
            DailyRoundPreview(
                round: 3,
                title: "Combined points — Q3",
                subtitle: "Total points scored by both teams in the third quarter only.",
                simMin: 10,
                simMax: 28
            ),
            DailyRoundPreview(
                round: 4,
                title: "Full game — total points",
                subtitle: "Combined points for both teams over the full regulation game.",
                simMin: 38,
                simMax: 62
            )
        ]
        let nbaRounds: [DailyRoundPreview] = [
            DailyRoundPreview(
                round: 1,
                title: "Jaylen Brown — Q1 points",
                subtitle: "Points scored in the opening quarter.",
                simMin: 0,
                simMax: 18
            ),
            DailyRoundPreview(
                round: 2,
                title: "LeBron James — first-half assists",
                subtitle: "Assists in the first two quarters.",
                simMin: 0,
                simMax: 12
            ),
            DailyRoundPreview(
                round: 3,
                title: "Combined three-pointers — Q3",
                subtitle: "Total made threes by both teams in Q3.",
                simMin: 4,
                simMax: 22
            ),
            DailyRoundPreview(
                round: 4,
                title: "Second half — combined points",
                subtitle: "Total points by both teams in the third and fourth quarters.",
                simMin: 48,
                simMax: 118
            )
        ]
        let mashRounds: [DailyRoundPreview] = [
            DailyRoundPreview(
                round: 1,
                title: "[NFL] Tyreek Hill — Q1 receiving yards",
                subtitle: "NFL leg: first-quarter receiving yards.",
                simMin: 0,
                simMax: 55
            ),
            DailyRoundPreview(
                round: 2,
                title: "[NBA] Shai Gilgeous-Alexander — 1H assists",
                subtitle: "NBA leg: first-half assist total.",
                simMin: 0,
                simMax: 11
            ),
            DailyRoundPreview(
                round: 3,
                title: "[NHL] Connor McDavid — P1 shots on goal",
                subtitle: "Round 3 of this bracket (NHL): first-period shots on goal.",
                simMin: 0,
                simMax: 9
            ),
            DailyRoundPreview(
                round: 4,
                title: "[NFL] Q4 — combined points",
                subtitle: "Final round: both teams’ scoring total in the fourth quarter only.",
                simMin: 10,
                simMax: 34
            )
        ]
        let catalog: [(String, String, String, Int, [DailyRoundPreview])] = [
            ("tourney_nfl_prime", "NFL prime-time sprint", "KC @ BUF", 3, nflRounds),
            ("tourney_nba_night", "NBA night ladder", "LAL @ BOS", 5, nbaRounds),
            ("tourney_cross_sport", "Cross-sport four-round draft", "MIXED SLATE", 7, mashRounds)
        ]
        return catalog.enumerated().map { i, row in
            let hoursAhead = row.3 + i
            let tip = now.addingTimeInterval(TimeInterval(hoursAhead * 3600))
            let entry = tip.addingTimeInterval(-3600)
            return DailyGameOption(
                id: row.0,
                label: row.2,
                tournamentName: row.1,
                tipOffAt: tip,
                entryClosesAt: entry,
                roundPreviews: row.4
            )
        }
    }

    private func dailyClosestStorageKey(userId: UUID, slateKey: String) -> String {
        "\(userId.uuidString)|\(slateKey)"
    }

    func dailyClosestState(userId: UUID, date: Date = .now) -> DailyClosestTournamentState? {
        let k = dailyClosestStorageKey(userId: userId, slateKey: SlateDay.slateKey(for: date))
        return state.dailyClosestByKey?[k]
    }

    @discardableResult
    func enterDailyClosestTournament(userId: UUID, gameId: String, date: Date = .now) -> DailyClosestTournamentState? {
        guard state.profiles[userId] != nil else { return nil }
        let dayISO = SlateDay.slateKey(for: date)
        let k = dailyClosestStorageKey(userId: userId, slateKey: dayISO)
        if let existing = state.dailyClosestByKey?[k] { return existing }

        guard let game = dailyGameOptions(now: date).first(where: { $0.id == gameId }) else { return nil }
        guard date < game.entryClosesAt else { return nil }

        let t = dailyTournament(for: date)
        var rng = SeededRNG(seed: Self.stableHashFNV1a64("\(userId.uuidString)-\(dayISO)-closest"))
        let slot = Int(rng.nextDouble() * 16)

        let roundSpecs: [DailyRoundPropSpec] = game.roundPreviews.map {
            DailyRoundPropSpec(
                round: $0.round,
                propLabel: $0.title,
                statSummary: $0.subtitle,
                simMin: $0.simMin,
                simMax: $0.simMax
            )
        }

        let st = DailyClosestTournamentState(
            tournamentId: t.id,
            dayISO: dayISO,
            gameId: game.id,
            gameLabel: game.label,
            tournamentName: game.tournamentName,
            tipOffAt: game.tipOffAt,
            entryClosesAt: game.entryClosesAt,
            bracketSize: 16,
            userSlot: slot,
            nextQuarter: 1,
            eliminated: false,
            completed: false,
            roundsCompleted: [],
            roundSpecs: roundSpecs.isEmpty
                ? (1...4).map { q in
                    DailyRoundPropSpec(
                        round: q,
                        propLabel: "Combined points scored (Q\(q))",
                        statSummary: "Total points both teams this quarter.",
                        simMin: 36,
                        simMax: 74
                    )
                }
                : roundSpecs
        )
        var map = state.dailyClosestByKey ?? [:]
        map[k] = st
        state.dailyClosestByKey = map
        persist()
        return st
    }

    /// - Parameter playthrough: When `true` (demo “simulate full bracket”), losses do not end the run until four rounds are recorded so you can see every round. Competitive play uses `false`.
    func submitDailyClosestPick(userId: UUID, pick: Double, date: Date = .now, playthrough: Bool = false) -> DailyClosestPickResult? {
        guard state.profiles[userId] != nil else { return nil }
        let dayISO = SlateDay.slateKey(for: date)
        let k = dailyClosestStorageKey(userId: userId, slateKey: dayISO)
        guard var st = state.dailyClosestByKey?[k] else { return nil }
        guard !st.eliminated, !st.completed else { return nil }
        let q = st.nextQuarter
        guard q >= 1, q <= 4 else { return nil }

        let spec = st.roundSpecs.first(where: { $0.round == q })
            ?? DailyRoundPropSpec(
                round: q,
                propLabel: "Combined points scored (Q\(q))",
                statSummary: "Total points both teams this quarter.",
                simMin: 36,
                simMax: 74
            )
        let span = max(spec.simMax - spec.simMin, 1)

        var rng = SeededRNG(seed: Self.stableHashFNV1a64("\(st.tournamentId.uuidString)-\(dayISO)-Q\(q)-\(st.userSlot)"))
        let actual = spec.simMin + rng.nextDouble() * span
        let frac = floor(rng.nextDouble() * 10) / 10
        let actualTotal = (actual + frac).rounded(toPlaces: 1)

        let oppSlot = st.userSlot ^ 1
        let oppLabel = MMRLogic.opponentName(seed: rng.nextUInt64(), index: oppSlot + q * 17)
        var rOpp = SeededRNG(seed: Self.stableHashFNV1a64("\(dayISO)-opp-\(oppSlot)-\(q)"))
        let oppJitter = min(span * 0.65, 32)
        let opponentPick = actualTotal + (rOpp.nextDouble() - 0.5) * oppJitter

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

        let errScale = max(span * 0.45, 2)
        let reward = max(
            0,
            min(45, Int(48 * (1 - min(1, uErr / errScale))))
        )

        let propLabel = spec.propLabel
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

        if !playthrough {
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
                    applyDailyClosestBracketWin(userId: userId, date: date, st: &st)
                }
            } else {
                st.eliminated = true
            }
        } else {
            // Demo playthrough: play all four rounds even after a loss so the full slate is visible.
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
            }
            st.nextQuarter += 1
            if st.nextQuarter > 4 {
                let swept = st.roundsCompleted.allSatisfy(\.userWon)
                if swept {
                    applyDailyClosestBracketWin(userId: userId, date: date, st: &st)
                } else {
                    st.eliminated = true
                }
            }
        }

        var map = state.dailyClosestByKey ?? [:]
        map[k] = st
        state.dailyClosestByKey = map
        persist()

        let resultEliminated: Bool
        if playthrough {
            resultEliminated = st.eliminated
        } else {
            resultEliminated = !userWon
        }

        return DailyClosestPickResult(
            quarter: round,
            eliminated: resultEliminated,
            wonTournament: st.completed
        )
    }

    private func applyDailyClosestBracketWin(userId: UUID, date: Date, st: inout DailyClosestTournamentState) {
        st.completed = true
        let cupBonus = 120
        var profile = state.profiles[userId]!
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

    // MARK: - Tournament lifecycle

    func dailyTournament(for date: Date = .now) -> Tournament {
        let dayISO = SlateDay.slateKey(for: date)
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

            pointsDelta = payoutIncludingStake - stakePoints

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
            if stageIndex == tournament.stageCount {
                state.ledger.append(
                    PointsLedgerEntry(
                        id: UUID(),
                        createdAt: date,
                        userId: userId,
                        tournamentId: tournament.id,
                        betSlipId: nil,
                        deltaPoints: 0,
                        reason: "Daily quarter tournament win"
                    )
                )
                awardSeasonTournamentWinnerBadges(userId: userId, date: date)
            }
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

    /// FNV-1a over UTF-8 — stable across launches (Swift `String.hashValue` is salted per process).
    private static func stableHashFNV1a64(_ string: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for b in string.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        return hash == 0 ? 1 : hash
    }

    /// Per-leg outcomes for ranked daily slips (same RNG as `submitDailyQuarterParlay`).
    func rankedSlipLegCounts(_ slip: BetSlip) -> (wins: Int, losses: Int) {
        guard !slip.legs.isEmpty else { return (0, 0) }
        let resolved = resolveLegs(
            parlayLegs: slip.legs,
            seedKey: "\(slip.userId.uuidString)-\(slip.tournamentId.uuidString)-Q\(slip.stageIndex)"
        )
        let w = resolved.filter(\.didWin).count
        return (w, resolved.count - w)
    }

    private func resolveLegs(parlayLegs: [BetLeg], seedKey: String) -> [(legId: UUID, didWin: Bool)] {
        var rng = SeededRNG(seed: Self.stableHashFNV1a64(seedKey))
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

    /// Softer per-leg win rates so multi-leg Play parlays are not almost always losses in local/dev.
    private func resolvePlayParlayLegs(parlayLegs: [BetLeg], seedKey: String) -> [(legId: UUID, didWin: Bool)] {
        var rng = SeededRNG(seed: Self.stableHashFNV1a64(seedKey))
        var outcomes: [(legId: UUID, didWin: Bool)] = []
        outcomes.reserveCapacity(parlayLegs.count)
        for leg in parlayLegs {
            let implied = 1.0 / max(1.01, leg.oddsDecimalAtSubmit)
            let p = min(0.78, max(0.38, implied * 1.32))
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
        let net = Double(stakePoints) * (parlayOddsDecimal - 1.0)
        return max(0, Int(net.rounded()))
    }

    /// Whether the user already placed at least one Play-board parlay stake on the **current slate** (local 6am day).
    func hasPlayParlayStakeToday(userId: UUID, date: Date = .now) -> Bool {
        let day = SlateDay.slateKey(for: date)
        return state.ledger.contains { entry in
            entry.userId == userId
                && SlateDay.slateKey(for: entry.createdAt) == day
                && entry.reason == "Play parlay stake"
        }
    }

    /// Single pick or parlay from the Play board: deducts stake, resolves all legs, credits payout + season points on win.
    func submitPlayParlay(userId: UUID, stakePoints: Int, legs: [BetLeg], date: Date = .now) -> PlayParlayOutcome? {
        guard stakePoints > 0, !legs.isEmpty else { return nil }
        guard var profile = state.profiles[userId] else { return nil }
        let maxStake = min(JuicdBalance.dailyPlayAllowancePoints, profile.availableDailyPoints)
        guard stakePoints <= maxStake else { return nil }
        guard profile.availableDailyPoints >= stakePoints else { return nil }

        recordDailyRankParticipation(userId: userId, date: date)

        profile.availableDailyPoints -= stakePoints
        state.profiles[userId] = profile
        state.ledger.append(
            PointsLedgerEntry(
                id: UUID(),
                createdAt: date,
                userId: userId,
                tournamentId: nil,
                betSlipId: nil,
                deltaPoints: -stakePoints,
                reason: "Play parlay stake"
            )
        )

        let implied = parlayOddsDecimal(for: legs)
        let slateKey = SlateDay.slateKey(for: date)
        let seedKey = "\(userId.uuidString)-play-\(slateKey)-\(legs.map { "\($0.marketId.uuidString)|\($0.choiceId.uuidString)|\($0.oddsDecimalAtSubmit)" }.joined(separator: ";"))"
        let resolved = resolvePlayParlayLegs(parlayLegs: legs, seedKey: seedKey)
        let didWinAll = resolved.allSatisfy { $0.didWin }

        var seasonPointsEarned = 0
        if didWinAll {
            profile = state.profiles[userId]!
            let payoutIncludingStake = Int((Double(stakePoints) * implied).rounded())
            profile.availableDailyPoints += payoutIncludingStake
            seasonPointsEarned = max(0, Int((Double(stakePoints) * (implied - 1.0)).rounded()))
            profile.seasonPointsWon += seasonPointsEarned
            profile.allTimePointsWon += seasonPointsEarned
            state.profiles[userId] = profile
            state.ledger.append(
                PointsLedgerEntry(
                    id: UUID(),
                    createdAt: date,
                    userId: userId,
                    tournamentId: nil,
                    betSlipId: nil,
                    deltaPoints: payoutIncludingStake,
                    reason: "Play parlay payout"
                )
            )
        }

        let slipId = UUID()
        let legWins = resolved.filter(\.didWin).count
        let legLosses = resolved.count - legWins
        var entries = state.playBoardEntries ?? []
        entries.append(
            PlayBoardEntry(
                id: slipId,
                userId: userId,
                slateDayKey: slateKey,
                createdAt: date,
                stakePoints: stakePoints,
                legSummaries: legs.map(\.choiceLabel),
                combinedOdds: implied,
                didWin: didWinAll,
                seasonPointsEarned: seasonPointsEarned,
                playLegWins: legWins,
                playLegLosses: legLosses
            )
        )
        state.playBoardEntries = entries

        persist()
        return PlayParlayOutcome(didWin: didWinAll, seasonPointsEarned: seasonPointsEarned)
    }

    // MARK: - Career & season stats

    func careerBettingStats(userId: UUID) -> CareerBettingStats {
        periodBettingStats(userId: userId, seasonKey: nil)
    }

    func seasonBettingStats(userId: UUID) -> CareerBettingStats {
        seasonBettingStats(userId: userId, seasonKey: JuicdSeason.currentSeasonKey())
    }

    func seasonBettingStats(userId: UUID, seasonKey: String) -> CareerBettingStats {
        periodBettingStats(userId: userId, seasonKey: seasonKey)
    }

    private func periodBettingStats(userId: UUID, seasonKey: String?) -> CareerBettingStats {
        func inSeason(_ date: Date) -> Bool {
            guard let sk = seasonKey else { return true }
            return JuicdSeason.contains(date, seasonKey: sk)
        }

        let mine = (state.playBoardEntries ?? []).filter { entry in
            entry.userId == userId && inSeason(entry.createdAt)
        }
        let playWins = mine.filter(\.didWin).count
        let playLosses = mine.count - playWins

        let dailySlips = state.dailyBets.values.filter { slip in
            guard slip.userId == userId, let t = slip.resolvedAt else { return false }
            return inSeason(t)
        }
        let rankedDailyWins = dailySlips.filter { $0.didWinAllLegs == true }.count
        let rankedDailyLosses = dailySlips.count - rankedDailyWins

        var rankedDailyLegWins = 0
        var rankedDailyLegLosses = 0
        for slip in dailySlips {
            let leg = rankedSlipLegCounts(slip)
            rankedDailyLegWins += leg.wins
            rankedDailyLegLosses += leg.losses
        }

        let playLegWinsTotal = mine.reduce(0) { $0 + $1.playLegWins }
        let playLegLossesTotal = mine.reduce(0) { $0 + $1.playLegLosses }

        var closestRoundWins = 0
        var closestRoundLosses = 0
        for (key, st) in state.dailyClosestByKey ?? [:] {
            guard key.hasPrefix(userId.uuidString) else { continue }
            if let sk = seasonKey {
                guard let d = Self.dateFromLocalDayISO(st.dayISO), JuicdSeason.contains(d, seasonKey: sk) else { continue }
            }
            for r in st.roundsCompleted {
                if r.userWon { closestRoundWins += 1 } else { closestRoundLosses += 1 }
            }
        }

        var totalPointsStaked = 0
        var totalPointsWonBack = 0
        var dailyBracketTournamentWins = 0

        for entry in state.ledger where entry.userId == userId {
            guard inSeason(entry.createdAt) else { continue }
            if entry.reason == "Play parlay stake" || entry.reason.hasPrefix("Daily bet stake") {
                totalPointsStaked += abs(entry.deltaPoints)
            }
            if entry.deltaPoints > 0 {
                if entry.reason == "Play parlay payout"
                    || entry.reason.contains("Daily bet payout")
                    || entry.reason.contains("Daily closest reward")
                    || entry.reason == "Daily closest — win bracket"
                {
                    totalPointsWonBack += entry.deltaPoints
                }
            }
            if entry.reason == "Daily closest — win bracket" {
                dailyBracketTournamentWins += 1
            }
        }

        return CareerBettingStats(
            playWins: playWins,
            playLosses: playLosses,
            rankedDailyWins: rankedDailyWins,
            rankedDailyLosses: rankedDailyLosses,
            closestRoundWins: closestRoundWins,
            closestRoundLosses: closestRoundLosses,
            playLegByLegWins: playLegWinsTotal,
            playLegByLegLosses: playLegLossesTotal,
            rankedLegByLegWins: rankedDailyLegWins,
            rankedLegByLegLosses: rankedDailyLegLosses,
            totalPointsStaked: totalPointsStaked,
            totalPointsWonBack: totalPointsWonBack,
            dailyBracketTournamentWins: dailyBracketTournamentWins
        )
    }

    // MARK: - Friends

    private func friendshipsList() -> [Friendship] { state.friendships ?? [] }

    private func friendRequestsList() -> [FriendRequest] { state.friendRequests ?? [] }

    private static func sortedUserPair(_ a: UUID, _ b: UUID) -> (UUID, UUID) {
        a.uuidString < b.uuidString ? (a, b) : (b, a)
    }

    private func areFriends(_ a: UUID, _ b: UUID) -> Bool {
        let (l, h) = Self.sortedUserPair(a, b)
        return friendshipsList().contains { $0.lowerUserId == l && $0.higherUserId == h }
    }

    func friendUserIds(of userId: UUID) -> [UUID] {
        var ids: [UUID] = []
        for f in friendshipsList() {
            if f.lowerUserId == userId { ids.append(f.higherUserId) }
            else if f.higherUserId == userId { ids.append(f.lowerUserId) }
        }
        return ids
    }

    func sendFriendRequest(from fromUserId: UUID, to toUserId: UUID) -> Bool {
        guard fromUserId != toUserId else { return false }
        guard state.profiles[fromUserId] != nil, state.profiles[toUserId] != nil else { return false }
        if areFriends(fromUserId, toUserId) { return false }
        var reqs = friendRequestsList()
        let duplicate = reqs.contains { r in
            (r.fromUserId == fromUserId && r.toUserId == toUserId)
                || (r.fromUserId == toUserId && r.toUserId == fromUserId)
        }
        if duplicate { return false }
        reqs.append(FriendRequest(id: UUID(), fromUserId: fromUserId, toUserId: toUserId, createdAt: .now))
        state.friendRequests = reqs
        persist()
        return true
    }

    func acceptFriendRequest(requestId: UUID, asUserId: UUID) -> Bool {
        var reqs = friendRequestsList()
        guard let idx = reqs.firstIndex(where: { $0.id == requestId }) else { return false }
        let r = reqs[idx]
        guard r.toUserId == asUserId else { return false }
        reqs.remove(at: idx)
        state.friendRequests = reqs
        let pair = Self.sortedUserPair(r.fromUserId, r.toUserId)
        var friends = friendshipsList()
        if !friends.contains(where: { $0.lowerUserId == pair.0 && $0.higherUserId == pair.1 }) {
            friends.append(Friendship(lowerUserId: pair.0, higherUserId: pair.1, createdAt: .now))
        }
        state.friendships = friends
        persist()
        return true
    }

    func rejectFriendRequest(requestId: UUID, asUserId: UUID) -> Bool {
        var reqs = friendRequestsList()
        guard let idx = reqs.firstIndex(where: { $0.id == requestId }) else { return false }
        guard reqs[idx].toUserId == asUserId else { return false }
        reqs.remove(at: idx)
        state.friendRequests = reqs
        persist()
        return true
    }

    func cancelOutgoingFriendRequest(requestId: UUID, asUserId: UUID) -> Bool {
        var reqs = friendRequestsList()
        guard let idx = reqs.firstIndex(where: { $0.id == requestId }) else { return false }
        guard reqs[idx].fromUserId == asUserId else { return false }
        reqs.remove(at: idx)
        state.friendRequests = reqs
        persist()
        return true
    }

    func incomingFriendRequests(for userId: UUID) -> [FriendRequest] {
        friendRequestsList().filter { $0.toUserId == userId }
    }

    func outgoingFriendRequests(for userId: UUID) -> [FriendRequest] {
        friendRequestsList().filter { $0.fromUserId == userId }
    }

    func searchProfilesForFriendInvite(excludingUserId: UUID, query: String) -> [Profile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let friends = Set(friendUserIds(of: excludingUserId))
        let reqs = friendRequestsList()
        return state.profiles.values.filter { p in
            guard p.id != excludingUserId else { return false }
            guard !friends.contains(p.id) else { return false }
            let pending = reqs.contains { r in
                (r.fromUserId == excludingUserId && r.toUserId == p.id)
                    || (r.fromUserId == p.id && r.toUserId == excludingUserId)
            }
            guard !pending else { return false }
            return p.displayName.lowercased().contains(q)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func friendLeaderboardRows(for userId: UUID) -> [(rank: Int, profile: Profile)] {
        var rows: [Profile] = []
        if let me = state.profiles[userId] { rows.append(me) }
        for fid in friendUserIds(of: userId) {
            if let p = state.profiles[fid] { rows.append(p) }
        }
        let sorted = rows.sorted { lhs, rhs in
            let ml = lhs.mmr ?? MMRLogic.startingMMR
            let mr = rhs.mmr ?? MMRLogic.startingMMR
            if ml != mr { return ml > mr }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return sorted.enumerated().map { (i, p) in (rank: i + 1, profile: p) }
    }

    func recentPlayEntries(userId: UUID, limit: Int = 20) -> [PlayBoardEntry] {
        Array(
            (state.playBoardEntries ?? [])
                .filter { $0.userId == userId }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
    }

    func recentPlayForm(userId: UUID, last n: Int) -> (wins: Int, losses: Int) {
        let slice = recentPlayEntries(userId: userId, limit: n)
        let w = slice.filter(\.didWin).count
        return (w, slice.count - w)
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

    private func awardSeasonTournamentWinnerBadges(userId: UUID, date: Date = .now) {
        let seasonKey = JuicdSeason.currentSeasonKey(at: date)
        let seasonLabel = JuicdSeason.shortLabel(for: seasonKey)
        let singleTitle = "\(seasonLabel) Tourney Winner"
        let fiveTitle = "\(seasonLabel) 5x Tourney Winner"

        func inSeason(_ d: Date) -> Bool { JuicdSeason.contains(d, seasonKey: seasonKey) }
        let seasonWins = state.ledger.reduce(0) { partial, entry in
            guard entry.userId == userId, inSeason(entry.createdAt), entry.reason == "Daily quarter tournament win" else {
                return partial
            }
            return partial + 1
        }

        if !(state.rewards[userId] ?? []).contains(where: { $0.title == singleTitle }) {
            state.rewards[userId, default: []].append(
                RewardBadge(
                    id: UUID(),
                    title: singleTitle,
                    description: "Won a daily quarter tournament in \(seasonLabel).",
                    achievedAt: date,
                    imageSystemName: "trophy.fill"
                )
            )
        }
        if seasonWins >= 5, !(state.rewards[userId] ?? []).contains(where: { $0.title == fiveTitle }) {
            state.rewards[userId, default: []].append(
                RewardBadge(
                    id: UUID(),
                    title: fiveTitle,
                    description: "Won 5+ daily quarter tournaments in \(seasonLabel).",
                    achievedAt: date,
                    imageSystemName: "rosette"
                )
            )
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

    /// Prototype: clear today’s daily closest tournament so you can re-enter and test flows.
    func resetDailyClosestTournamentForTesting(userId: UUID, date: Date = .now) {
        let k = dailyClosestStorageKey(userId: userId, slateKey: SlateDay.slateKey(for: date))
        var map = state.dailyClosestByKey ?? [:]
        map.removeValue(forKey: k)
        state.dailyClosestByKey = map
        persist()
    }

    /// Prototype: refill daily Play balance to the full allowance for the current slate (no extra ledger “refill” line).
    func resetDailyPlayBalanceForTesting(userId: UUID, date: Date = .now) {
        guard var profile = state.profiles[userId] else { return }
        let slateKey = SlateDay.slateKey(for: date)
        profile.availableDailyPoints = JuicdBalance.dailyPlayAllowancePoints
        profile.lastDailyPointsAwardDateISO = slateKey
        state.profiles[userId] = profile
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

    private static func dateFromLocalDayISO(_ iso: String) -> Date? {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.timeZone = Calendar.current.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: iso)
    }

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

