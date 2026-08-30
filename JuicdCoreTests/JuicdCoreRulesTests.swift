import XCTest
@testable import Juicd

@MainActor
final class JuicdCoreRulesTests: XCTestCase {
    private let userId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    private func profile(available: Int = 100) -> Profile {
        Profile(
            id: userId,
            displayName: "Test Player",
            mmr: 1500,
            currentTier: .silver,
            seasonPointsWon: 0,
            allTimePointsWon: 0,
            availableDailyPoints: available,
            lastDailyPointsAwardDateISO: nil
        )
    }

    private func state(with profile: Profile? = nil) -> InMemoryJuicdRepository.PersistedState {
        var state = InMemoryJuicdRepository.PersistedState()
        if let profile {
            state.profiles[profile.id] = profile
        }
        return state
    }

    private func leg(
        id: UUID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
        odds: Double = 2
    ) -> BetLeg {
        BetLeg(
            id: id,
            marketId: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            choiceId: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            choiceLabel: "Over",
            oddsDecimalAtSubmit: odds
        )
    }

    func testCachePolicyAcceptsFreshEntriesAndBoundsStaleFallback() {
        let policy = SupabasePlayBoardCachePolicy(
            clientTTLSeconds: 180,
            maxStaleFallbackSeconds: 3600
        )
        let now = Date(timeIntervalSince1970: 10_000)
        let response = SupabasePlayBoardResponse(
            mode: "simulated",
            source: "simulated",
            slateKey: "2026-08-30",
            ribbons: []
        )

        XCTAssertTrue(policy.isFresh(savedAt: now.addingTimeInterval(-179), now: now))
        XCTAssertFalse(policy.isFresh(savedAt: now.addingTimeInterval(-180), now: now))
        XCTAssertFalse(policy.isFresh(savedAt: now.addingTimeInterval(1), now: now))

        let stale = policy.staleResponse(
            response,
            savedAt: now.addingTimeInterval(-90),
            now: now
        )
        XCTAssertEqual(stale?.cached, true)
        XCTAssertEqual(stale?.ageSeconds, 90)
        XCTAssertNil(policy.staleResponse(response, savedAt: now.addingTimeInterval(-3601), now: now))
    }

    func testSettlementResponseMustCoverExactlySubmittedLegs() throws {
        let first = leg()
        let second = leg(
            id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        )
        let payload = """
        {
          "slateKey": "2026-08-30",
          "outcomes": [
            {"legId": "\(first.id.uuidString)", "didWin": true},
            {"legId": "\(second.id.uuidString)", "didWin": false}
          ]
        }
        """
        let response = try JSONDecoder().decode(
            SupabaseResolveSlipResponse.self,
            from: Data(payload.utf8)
        )

        let map = SupabaseOddsService.validatedOutcomeMap(response, for: [first, second])
        XCTAssertEqual(map?[first.id], true)
        XCTAssertEqual(map?[second.id], false)

        let incomplete = SupabaseResolveSlipResponse(
            slateKey: response.slateKey,
            outcomes: [response.outcomes[0]]
        )
        XCTAssertNil(SupabaseOddsService.validatedOutcomeMap(incomplete, for: [first, second]))
    }

    func testDailyAllowanceIsIdempotentAndWritesOneLedgerLine() {
        let repo = InMemoryJuicdRepository(initialState: state(with: profile(available: 3)))
        let date = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(repo.awardDailyPointsIfNeeded(userId: userId, date: date)?.availableDailyPoints, 100)
        XCTAssertEqual(repo.awardDailyPointsIfNeeded(userId: userId, date: date.addingTimeInterval(60))?.availableDailyPoints, 100)
        XCTAssertEqual(repo.state.ledger.count, 1)
        XCTAssertEqual(repo.state.ledger[0].deltaPoints, 100)
        XCTAssertEqual(repo.state.ledger[0].userId, userId)
    }

    func testPlayParlayLedgerCreditsPayoutAndSeasonPointsOnlyOnWin() {
        let repo = InMemoryJuicdRepository(initialState: state(with: profile()))
        let outcome = repo.submitPlayParlay(
            userId: userId,
            stakePoints: 25,
            legs: [leg()],
            date: Date(timeIntervalSince1970: 1_000_000),
            forcedLegOutcomesByLegId: [leg().id: true]
        )

        XCTAssertEqual(outcome, PlayParlayOutcome(didWin: true, seasonPointsEarned: 25))
        XCTAssertEqual(repo.profile(userId: userId)?.availableDailyPoints, 125)
        XCTAssertEqual(repo.state.ledger.map(\.deltaPoints), [-25, 50])
        XCTAssertEqual(repo.careerBettingStats(userId: userId).totalPointsStaked, 25)
        XCTAssertEqual(repo.careerBettingStats(userId: userId).totalPointsWonBack, 50)
    }

    func testResolverIsDeterministicAndReturnsOneOutcomePerLeg() {
        let repo = InMemoryJuicdRepository(initialState: state())
        let firstLeg = leg()
        let secondLeg = leg(
            id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
            odds: 3
        )

        let first = repo.resolvePlayParlayLegs(
            parlayLegs: [firstLeg, secondLeg],
            seedKey: "resolver-test"
        )
        let second = repo.resolvePlayParlayLegs(
            parlayLegs: [firstLeg, secondLeg],
            seedKey: "resolver-test"
        )

        XCTAssertEqual(first.map(\.legId), [firstLeg.id, secondLeg.id])
        XCTAssertEqual(first.map(\.didWin), second.map(\.didWin))
    }

    func testClearUserDataRemovesOwnedRecordsButRetainsSharedGroups() {
        let group = Group(id: UUID(), name: "Shared", inviteCode: "ABC123", createdAt: .now)
        let friendId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        var initial = state(with: profile())
        initial.groups = [group]
        initial.memberships = [GroupMembership(id: UUID(), groupId: group.id, userId: userId, joinedAt: .now)]
        initial.rewards[userId] = [
            RewardBadge(id: UUID(), title: "Badge", description: "Test", achievedAt: .now, imageSystemName: "star")
        ]
        initial.ledger = [
            PointsLedgerEntry(id: UUID(), createdAt: .now, userId: userId, tournamentId: nil, betSlipId: nil, deltaPoints: 1, reason: "test")
        ]
        let tournament = Tournament(
            id: UUID(), kind: .daily, status: .active, startAt: .now,
            endAt: .now.addingTimeInterval(3600), stageCount: 4, seasonYear: 2026
        )
        initial.activeDailyByUser[userId] = InMemoryJuicdRepository.DailyProgress(
            tournamentId: tournament.id, currentStageIndex: 1, eliminatedAtStageIndex: nil, qualifiedStages: []
        )
        let betSlip = BetSlip(
            id: UUID(), userId: userId, tournamentId: tournament.id, stageIndex: 1,
            stakePoints: 5, legs: [leg()], impliedParlayOddsDecimalAtSubmit: 2,
            estimatedNetPointsPayout: 5, status: .eliminated, didWinAllLegs: false, resolvedAt: .now
        )
        initial.dailyBets[betSlip.id] = betSlip
        initial.dailyRankParticipationByDay = ["2026-08-30": [userId]]
        initial.dailyRankResolvedByDay = ["2026-08-30": [userId]]
        let closest = DailyClosestTournamentState(
            tournamentId: tournament.id, dayISO: "2026-08-30", gameId: "game",
            gameLabel: "Test game", tournamentName: "Test tournament", tipOffAt: .now,
            entryClosesAt: .now.addingTimeInterval(3600), bracketSize: 16, userSlot: 1,
            nextQuarter: 1, eliminated: false, completed: false, roundsCompleted: [], roundSpecs: []
        )
        initial.dailyClosestByKey = ["\(userId.uuidString)|2026-08-30": closest]
        initial.friendRequests = [FriendRequest(id: UUID(), fromUserId: userId, toUserId: friendId, createdAt: .now)]
        initial.friendships = [Friendship(lowerUserId: userId, higherUserId: friendId, createdAt: .now)]
        initial.weeklySubmissions = [
            InMemoryJuicdRepository.WeeklySubmission(
                id: UUID(), userId: userId, groupId: group.id, weekIndex: 1, pointsEarned: 5, submittedAt: .now
            )
        ]
        initial.playBoardEntries = [
            PlayBoardEntry(
                id: UUID(), userId: userId, slateDayKey: "2026-08-30", createdAt: .now,
                stakePoints: 5, legSummaries: ["Over"], combinedOdds: 2, didWin: false,
                seasonPointsEarned: 0, playLegWins: 0, playLegLosses: 1
            )
        ]

        let repo = InMemoryJuicdRepository(initialState: initial)
        XCTAssertTrue(repo.clearUserData(userId: userId))
        XCTAssertNil(repo.profile(userId: userId))
        XCTAssertTrue(repo.state.ledger.isEmpty)
        XCTAssertNil(repo.state.rewards[userId])
        XCTAssertNil(repo.state.activeDailyByUser[userId])
        XCTAssertTrue(repo.state.dailyBets.isEmpty)
        XCTAssertTrue(repo.state.memberships.isEmpty)
        XCTAssertTrue(repo.state.friendRequests?.isEmpty == true)
        XCTAssertTrue(repo.state.friendships?.isEmpty == true)
        XCTAssertTrue(repo.state.weeklySubmissions.isEmpty)
        XCTAssertTrue(repo.state.playBoardEntries?.isEmpty == true)
        XCTAssertTrue(repo.state.dailyRankParticipationByDay.isEmpty)
        XCTAssertTrue(repo.state.dailyRankResolvedByDay.isEmpty)
        XCTAssertTrue(repo.state.dailyClosestByKey?.isEmpty == true)
        XCTAssertEqual(repo.state.groups.count, 1)
        XCTAssertEqual(repo.state.groups.first?.id, group.id)
        XCTAssertFalse(repo.clearUserData(userId: userId))
    }
}
