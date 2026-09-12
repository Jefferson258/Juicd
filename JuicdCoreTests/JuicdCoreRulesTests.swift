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

        XCTAssertEqual(outcome?.didWin, true)
        XCTAssertEqual(outcome?.pending, false)
        XCTAssertEqual(outcome?.seasonPointsEarned, 25)
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

    func testSlateTreatsPre4amCentralAsPriorDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let oneAM = cal.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 1, minute: 0))!
        let fourAM = cal.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 4, minute: 0))!
        XCTAssertEqual(SlateDay.slateKey(for: oneAM), "2026-08-27")
        XCTAssertEqual(SlateDay.slateKey(for: fourAM), "2026-08-28")
    }

    func testPlayParlayStaysPendingWithoutForcedOutcomes() {
        let repo = InMemoryJuicdRepository(initialState: state(with: profile()))
        let now = Date()
        let start = now.addingTimeInterval(3600)
        var pendingLeg = leg()
        pendingLeg.commenceTime = start
        let outcome = repo.submitPlayParlay(
            userId: userId,
            stakePoints: 10,
            legs: [pendingLeg],
            date: now
        )
        XCTAssertEqual(outcome?.pending, true)
        XCTAssertEqual(repo.profile(userId: userId)?.availableDailyPoints, 90)
        XCTAssertEqual(repo.state.playBoardEntries?.first?.pending, true)
        XCTAssertEqual(repo.careerBettingStats(userId: userId).playWins, 0)
    }

    func testSameKickoffParlayRule() {
        let a = PlayPropBet(
            id: UUID(), leagueTag: "MLB", athleteOrTeam: "A", matchup: "A @ B",
            propDescription: "Moneyline", lineText: "H2H", pickLabel: "A",
            oddsDecimal: 1.9, commenceTime: Date(timeIntervalSince1970: 1000), eventId: "e1"
        )
        let b = PlayPropBet(
            id: UUID(), leagueTag: "MLB", athleteOrTeam: "C", matchup: "C @ D",
            propDescription: "Moneyline", lineText: "H2H", pickLabel: "C",
            oddsDecimal: 2.1, commenceTime: Date(timeIntervalSince1970: 8000), eventId: "e2"
        )
        let same = PlayPropBet(
            id: UUID(), leagueTag: "MLB", athleteOrTeam: "B", matchup: "A @ B",
            propDescription: "Moneyline", lineText: "H2H", pickLabel: "B",
            oddsDecimal: 2.0, commenceTime: Date(timeIntervalSince1970: 1000), eventId: "e1"
        )
        XCTAssertFalse(PlayViewModel.sameKickoff(a, b))
        XCTAssertTrue(PlayViewModel.sameKickoff(a, same))
    }

    func testClosestNumberPairingEliminatesFartherPick() {
        let a = BracketEntrant(id: "a", displayName: "A", isBot: false, slot: 0, picks: [10], eliminatedRound: nil)
        let b = BracketEntrant(id: "b", displayName: "B", isBot: true, slot: 1, picks: [20], eliminatedRound: nil)
        let graded = TourneyClosestGrading.apply(entrants: [a, b], actuals: [11])
        XCTAssertNil(graded.first { $0.id == "a" }?.eliminatedRound)
        XCTAssertEqual(graded.first { $0.id == "b" }?.eliminatedRound, 1)
    }

    func testPopularPillTitle() {
        XCTAssertEqual(PlaySportPill.forYou.displayTitle, "Popular")
    }

    func testTourneySlateBuilderUsesRealLinesNotDemoNames() {
        let start = Date().addingTimeInterval(8 * 3600)
        let props = (0..<4).map { i in
            PlayPropBet(
                id: UUID(),
                leagueTag: "NBA",
                athleteOrTeam: "Player \(i)",
                matchup: "DEN @ MIN",
                propDescription: "Points",
                lineText: "24.5",
                pickLabel: "Over",
                oddsDecimal: 1.9,
                commenceTime: start,
                eventId: "evt-1",
                sportKey: "basketball_nba",
                pointLine: 24.5
            )
        }
        let daily = TourneySlateBuilder.daily(from: props, slateKey: "2026-09-11")
        XCTAssertEqual(daily?.roundSpecs.count, 4)
        XCTAssertEqual(daily?.gameLabel, "DEN @ MIN")
        XCTAssertFalse(daily?.gameLabel.contains("HOU") == true)
        XCTAssertEqual(daily?.roundSpecs.first?.line, 24.5)
    }

    func testBracketTreeShowsR16ThroughFinal() {
        let people = (0..<16).map { i in
            BracketEntrant(
                id: "p\(i)",
                displayName: "P\(i)",
                isBot: i > 0,
                slot: i,
                picks: [10, 10, 10, 10],
                eliminatedRound: nil
            )
        }
        let columns = TourneyBracketTree.rounds(entrants: people, actuals: [10, 10, 10, 10], revealed: 4)
        XCTAssertEqual(columns.map(\.count), [8, 4, 2, 1])
        XCTAssertEqual(columns[0][0].top?.id, "p0")
        XCTAssertEqual(columns[0][0].bottom?.id, "p1")
        XCTAssertEqual(columns[3][0].winner?.id, "p0")
    }

    func testRejectsCachedCombinedScorePlaceholderLine() {
        let commence = "2026-09-12T00:00:00Z"
        let bad = RemoteTourneyPayload(
            kind: "weekly",
            periodKey: "2026-09-11",
            title: "Weekly",
            gameLabel: "NFL",
            commenceTime: commence,
            freezeAt: commence,
            roundSpecs: [
                RemoteTourneyRound(
                    round: 1,
                    propLabel: "KC @ BUF — combined score",
                    statSummary: "Closest to combined score",
                    line: 44.5,
                    eventId: "e1",
                    matchup: "KC @ BUF",
                    player: "Combined score",
                    commenceTime: commence,
                    sportKey: "americanfootball_nfl"
                )
            ]
        )
        XCTAssertTrue(bad.containsBannedPlaceholder)

        let combinedNoLine = RemoteTourneyRound(
            round: 1,
            propLabel: "KC @ BUF — combined score",
            statSummary: "Enter a number — no suggested line.",
            line: nil,
            eventId: "e1",
            matchup: "KC @ BUF",
            player: "Combined score",
            commenceTime: commence,
            sportKey: "americanfootball_nfl"
        )
        let ok = RemoteTourneyPayload(
            kind: "weekly",
            periodKey: "2026-09-11",
            title: "Weekly",
            gameLabel: "KC @ BUF",
            commenceTime: commence,
            freezeAt: commence,
            roundSpecs: [combinedNoLine]
        )
        XCTAssertFalse(ok.containsBannedPlaceholder)
    }

    func testCalendarWeekIsMondayThroughSunday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let friday = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 13))!
        XCTAssertEqual(SlateDay.calendarWeekKey(for: friday), "2026-09-07")
        XCTAssertEqual(SlateDay.nflWeekKey(for: friday), "2026-09-07")
        XCTAssertEqual(SlateDay.nextSlateKey(from: friday), "2026-09-12")
        let sunday = cal.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 16))!
        XCTAssertTrue(SlateDay.isSundayEarlyWeeklyWindow(for: sunday))
        XCTAssertEqual(SlateDay.calendarWeekKey(for: sunday), "2026-09-07")
        XCTAssertEqual(SlateDay.nextCalendarWeekKey(for: sunday), "2026-09-14")
        XCTAssertFalse(SlateDay.isSundayEarlyWeeklyWindow(for: friday))
    }

    func testTomorrowStakeDoesNotReduceTodayPoints() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let fridayNight = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 21))!
        let saturdayGame = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 19))!
        let repo = InMemoryJuicdRepository(initialState: state(with: profile()))
        var tomorrowLeg = leg()
        tomorrowLeg.commenceTime = saturdayGame
        let outcome = repo.submitPlayParlay(
            userId: userId,
            stakePoints: 30,
            legs: [tomorrowLeg],
            date: fridayNight
        )
        XCTAssertEqual(outcome?.pending, true)
        XCTAssertEqual(repo.profile(userId: userId)?.availableDailyPoints, 100)
        let tomorrowKey = SlateDay.nextSlateKey(from: fridayNight)
        XCTAssertEqual(repo.committedPlayStake(userId: userId, slateDayKey: tomorrowKey), 30)
        XCTAssertEqual(repo.pointsRemaining(userId: userId, slateDayKey: SlateDay.slateKey(for: fridayNight), date: fridayNight), 100)
        XCTAssertEqual(repo.pointsRemaining(userId: userId, slateDayKey: tomorrowKey, date: fridayNight), 70)
        XCTAssertEqual(repo.state.playBoardEntries?.first?.slateDayKey, tomorrowKey)
    }

    func testAwardAt4amSubtractsReservedTomorrowStakes() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let fridayNight = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 21))!
        let saturdayGame = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 19))!
        let saturday4am = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 4))!
        let repo = InMemoryJuicdRepository(initialState: state(with: profile()))
        var tomorrowLeg = leg()
        tomorrowLeg.commenceTime = saturdayGame
        _ = repo.submitPlayParlay(
            userId: userId,
            stakePoints: 30,
            legs: [tomorrowLeg],
            date: fridayNight
        )
        XCTAssertEqual(repo.awardDailyPointsIfNeeded(userId: userId, date: saturday4am)?.availableDailyPoints, 70)
    }

    func testMixedSlateParlayReturnsNil() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let fridayNight = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 21))!
        let fridayGame = cal.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 22))!
        let saturdayGame = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 19))!
        let repo = InMemoryJuicdRepository(initialState: state(with: profile()))
        var todayLeg = leg()
        todayLeg.commenceTime = fridayGame
        var tomorrowLeg = leg(id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!)
        tomorrowLeg.commenceTime = saturdayGame
        XCTAssertNil(
            repo.submitPlayParlay(
                userId: userId,
                stakePoints: 10,
                legs: [todayLeg, tomorrowLeg],
                date: fridayNight
            )
        )
        XCTAssertEqual(repo.profile(userId: userId)?.availableDailyPoints, 100)
        XCTAssertTrue(repo.state.playBoardEntries?.isEmpty ?? true)
    }
}
