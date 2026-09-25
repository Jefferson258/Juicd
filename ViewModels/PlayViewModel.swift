import Foundation
import Combine

@MainActor
final class PlayViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published var liveLine: LiveOddsLine?
    @Published var oddsStatus: String = "Tap to load odds"
    @Published var isLoadingOdds = false

    /// Full board after slate + boosts (before sport / stat / search filters).
    @Published private(set) var ribbons: [PlayPropRibbon] = []
    @Published private(set) var tomorrowRibbons: [PlayPropRibbon] = []
    @Published private(set) var dailyTourney: RemoteTourneyPayload?
    @Published private(set) var weeklyTourney: RemoteTourneyPayload?
    @Published private(set) var nextDailyTourney: RemoteTourneyPayload?
    @Published private(set) var nextWeeklyTourney: RemoteTourneyPayload?
    @Published var countdownNow: Date = .now

    /// When true, `ribbons` came from Supabase and must not be replaced by local stub rebuilds when switching sport filters.
    private var boardUsesRemoteFeed = false

    /// Bumps on each odds refresh start; completions from older generations are discarded (avoids overlapping `Task`s corrupting board state).
    private var oddsRefreshGeneration: UInt64 = 0
    /// Coalesces concurrent refreshes (configure + Play `.task` often fire together).
    private var inFlightOddsRefresh: Task<Void, Never>?

    @Published private(set) var isSubmittingPlayParlay = false
    @Published private(set) var tomorrowPointsRemaining: Int = JuicdBalance.dailyPlayAllowancePoints
    private var repoCancellable: AnyCancellable?

    @Published var sportPill: PlaySportPill = .forYou {
        didSet {
            if sportPill == .forYou {
                statFilterId = "all"
                searchText = ""
            } else {
                statFilterId = "popular"
            }
            rebuildRibbons()
            clampSportPillToAvailableOdds()
        }
    }

    /// Matches `PlaySportPill.statPillOptions` ids (`all`, `popular`, `points`, …).
    @Published var statFilterId: String = "all"

    @Published var searchText: String = ""

    // MARK: - Parlay builder (Play board)

    @Published var showParlayBuilder = false
    @Published var parlayLegs: [PlayPropBet] = []
    @Published var stakePoints: Int = 10
    @Published var pickingAdditionalLeg = false
    @Published var showFirstBetReminder = false
    @Published var builderToast: String?

    private static let maxParlayLegs = 8

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        repoCancellable = repository.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshProfile()
                }
            }
    }

    var maxStakePoints: Int {
        guard let userId else { return 0 }
        let slate = parlaySlateKey ?? SlateDay.slateKey()
        return repository.pointsRemaining(userId: userId, slateDayKey: slate)
    }

    var parlaySlateKey: String? {
        let keys = Set(parlayLegs.map { Self.slateKey(for: $0) })
        guard keys.count == 1, let key = keys.first else { return nil }
        return key
    }

    var isUpcomingSlateParlay: Bool {
        parlaySlateKey == SlateDay.nextSlateKey()
    }

    var impliedParlayDecimal: Double {
        guard !parlayLegs.isEmpty else { return 1 }
        return parlayLegs.map(\.juicdEffectiveDecimalOdds).reduce(1.0, *)
    }

    var estimatedSeasonPointsIfWin: Int {
        repository.estimatedNetPointsPayout(stakePoints: stakePoints, parlayOddsDecimal: impliedParlayDecimal)
    }

    /// Ribbons with props filtered for UI (search / stat / sport). Started games are dropped.
    var displayedRibbons: [PlayPropRibbon] {
        displayed(from: ribbons)
    }

    var displayedTomorrowRibbons: [PlayPropRibbon] {
        displayed(from: tomorrowRibbons)
    }

    var pendingSlips: [PlayBoardEntry] {
        guard let userId else { return [] }
        return repository.pendingPlayEntries(userId: userId)
    }

    var hasActiveSearch: Bool {
        sportPill != .forYou && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sport filter pills that currently have at least one priced prop on the board (always includes **Popular**).
    var sportPillsWithOdds: [PlaySportPill] {
        Self.sportPillsMatchingLeagues(on: propsUnionForSportToolbar())
    }

    /// Ribbon chevron: select that league’s sport filter (live ribbon infers from cached API line).
    func sportPillToApply(forRibbonId ribbonId: String) -> PlaySportPill? {
        if ribbonId == "live_api" {
            guard let line = liveLine else { return nil }
            return Self.sportPill(fromOddsSportKey: line.sportKey)
        }
        return PlaySportPill.sportPill(forRibbonId: ribbonId)
    }

    private static func sportPill(fromOddsSportKey key: String) -> PlaySportPill? {
        if key.contains("basketball_nba") { return .nba }
        if key.contains("americanfootball_nfl") { return .nfl }
        if key.contains("baseball_mlb") { return .mlb }
        if key.contains("icehockey_nhl") { return .nhl }
        if key.contains("soccer") { return .soccer }
        return .nfl
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        rebuildRibbons()
        Task {
            await refreshLiveOddsLine(bypassClientCache: false)
            await settlePendingSlips()
        }
    }

    /// Ask the Edge grader to resolve pending Play slips once games are final.
    func settlePendingSlips() async {
        guard let userId, SupabaseConfig.isConfigured else { return }
        let slips = repository.pendingPlayEntries(userId: userId)
        for slip in slips {
            guard let legs = repository.pendingLegs(for: slip.id), !legs.isEmpty else { continue }
            guard let outcomes = await SupabaseOddsService.settlePlaySlips(userId: userId, legs: legs) else {
                continue
            }
            var resolved: [(UUID, Bool)] = []
            var stillPending = false
            for leg in legs {
                guard let row = outcomes.first(where: { $0.legId.lowercased() == leg.id.uuidString.lowercased() }) else {
                    stillPending = true
                    break
                }
                if row.status == "pending" || row.didWin == nil {
                    stillPending = true
                    break
                }
                resolved.append((leg.id, row.didWin ?? false))
            }
            guard !stillPending, resolved.count == legs.count else { continue }
            _ = repository.resolvePendingPlaySlip(userId: userId, slipId: slip.id, resolved: resolved)
        }
        profile = repository.profile(userId: userId)
    }

    /// - Parameter bypassClientCache: when true (manual Sync), skip the 3‑minute client
    ///   soft cache. Edge still applies its own Odds TTL so Sync does not burn API quota.
    func refreshLiveOddsLine(bypassClientCache: Bool = false) async {
        if let existing = inFlightOddsRefresh, !bypassClientCache {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await self.performOddsRefresh(bypassClientCache: bypassClientCache)
        }
        inFlightOddsRefresh = task
        await task.value
        if inFlightOddsRefresh == task {
            inFlightOddsRefresh = nil
        }
    }

    private func performOddsRefresh(bypassClientCache: Bool) async {
        oddsRefreshGeneration &+= 1
        let generation = oddsRefreshGeneration

        if SupabaseConfig.isConfigured {
            if let serverBoard = await SupabaseOddsService.fetchPlayBoard(bypassClientCache: bypassClientCache) {
                guard generation == oddsRefreshGeneration else { return }
                liveLine = nil
                isLoadingOdds = false
                let cacheTag: String = {
                    if serverBoard.cached == true {
                        let age = serverBoard.ageSeconds.map { "\($0)s" } ?? "?"
                        return "cached \(age)"
                    }
                    return "fresh"
                }()
                oddsStatus = "Supabase \(serverBoard.mode) · \(serverBoard.source) · \(cacheTag)"
                dailyTourney = Self.usableTourney(serverBoard.dailyTourney)
                weeklyTourney = Self.usableTourney(serverBoard.weeklyTourney)
                nextDailyTourney = Self.usableTourney(serverBoard.nextDailyTourney)
                nextWeeklyTourney = Self.usableTourney(serverBoard.nextWeeklyTourney)
                if serverBoard.dailyTourney?.containsBannedPlaceholder == true {
                    AppErrorLogger.log(
                        severity: .warning,
                        message: "Discarded cached daily tourney placeholder; rebuilding from live props.",
                        screen: "tourney",
                        extra: ["kind": .string("daily"), "fallback": .string("cached_placeholder")]
                    )
                }
                if serverBoard.weeklyTourney?.containsBannedPlaceholder == true {
                    AppErrorLogger.log(
                        severity: .warning,
                        message: "Discarded cached weekly tourney placeholder; rebuilding from live props.",
                        screen: "tourney",
                        extra: ["kind": .string("weekly"), "fallback": .string("cached_placeholder")]
                    )
                }
                logTourneyDiagnostics(serverBoard.tourneyDiagnostics)
                let trimmed = Self.ribbonsDroppingEmpty(
                    Self.mapRibbons(serverBoard.ribbons, slateKey: serverBoard.slateKey)
                )
                let tomorrowTrimmed = Self.ribbonsDroppingEmpty(
                    Self.mapRibbons(
                        serverBoard.tomorrowRibbons ?? [],
                        slateKey: serverBoard.nextSlateKey ?? SlateDay.nextSlateKey()
                    )
                )
                let boardProps = trimmed.flatMap(\.props)
                let tomorrowProps = tomorrowTrimmed.flatMap(\.props)
                if dailyTourney == nil {
                    dailyTourney = TourneySlateBuilder.daily(from: boardProps, slateKey: serverBoard.slateKey)
                }
                if weeklyTourney == nil {
                    weeklyTourney = TourneySlateBuilder.weekly(
                        from: boardProps,
                        weekKey: serverBoard.weekKey ?? SlateDay.calendarWeekKey()
                    )
                }
                if nextDailyTourney == nil {
                    nextDailyTourney = TourneySlateBuilder.daily(
                        from: tomorrowProps,
                        slateKey: serverBoard.nextSlateKey ?? SlateDay.nextSlateKey()
                    )
                }
                if nextWeeklyTourney == nil, SlateDay.isSundayEarlyWeeklyWindow() {
                    nextWeeklyTourney = TourneySlateBuilder.weekly(
                        from: tomorrowProps,
                        weekKey: serverBoard.nextWeekKey ?? SlateDay.nextCalendarWeekKey()
                    )
                }
                logClientTourneyBuildFailure(
                    kind: "daily",
                    payload: dailyTourney,
                    propCount: boardProps.count,
                    source: "play_board"
                )
                logClientTourneyBuildFailure(
                    kind: "weekly",
                    payload: weeklyTourney,
                    propCount: boardProps.count,
                    source: "play_board"
                )
                repository.lastDailyTourney = dailyTourney
                repository.lastWeeklyTourney = weeklyTourney
                repository.lastNextDailyTourney = nextDailyTourney
                repository.lastNextWeeklyTourney = nextWeeklyTourney
                repository.objectWillChange.send()
                if trimmed.isEmpty && tomorrowTrimmed.isEmpty {
                    boardUsesRemoteFeed = false
                    oddsStatus = "No priced props on this slate yet."
                    AnalyticsService.logOddsSync(ok: false, source: "supabase_empty")
                    rebuildRibbons()
                } else {
                    boardUsesRemoteFeed = true
                    ribbons = trimmed
                    tomorrowRibbons = tomorrowTrimmed
                    AnalyticsService.logOddsSync(ok: true, source: "supabase_\(serverBoard.mode)")
                }
                clampSportPillToAvailableOdds()
                return
            }
            guard generation == oddsRefreshGeneration else { return }
            AnalyticsService.logOddsSync(ok: false, source: "supabase_fetch")
            logClientTourneyBuildFailure(kind: "daily", payload: dailyTourney, propCount: 0, source: "play_board_fetch_failed")
            logClientTourneyBuildFailure(kind: "weekly", payload: weeklyTourney, propCount: 0, source: "play_board_fetch_failed")
        }

        guard generation == oddsRefreshGeneration else { return }

        boardUsesRemoteFeed = false
        guard OddsAPIConfig.isConfigured else {
            oddsStatus = "Couldn't load the live board."
            liveLine = nil
            rebuildRibbons()
            clampSportPillToAvailableOdds()
            logClientTourneyBuildFailure(kind: "daily", payload: dailyTourney, propCount: 0, source: "odds_unconfigured_refused_demo")
            logClientTourneyBuildFailure(kind: "weekly", payload: weeklyTourney, propCount: 0, source: "odds_unconfigured_refused_demo")
            return
        }

        isLoadingOdds = true
        oddsStatus = "Loading one line…"
        let line = await TheOddsAPIService.fetchOneCachedLine()
        guard generation == oddsRefreshGeneration else {
            isLoadingOdds = false
            return
        }
        liveLine = line
        isLoadingOdds = false
        rebuildRibbons()
        clampSportPillToAvailableOdds()
        if let line {
            oddsStatus = "Fallback live (client) · \(line.sportKey)"
            AnalyticsService.logOddsSync(ok: true, source: "odds_api")
        } else {
            oddsStatus = "Couldn’t load odds."
            AnalyticsService.logOddsSync(ok: false, source: "odds_api")
        }
    }

    private func rebuildRibbons() {
        if boardUsesRemoteFeed { return }

        let slateKey = SlateDay.slateKey()
        var board = DailySlateBoard.ribbons(forSlateKey: slateKey, sport: sportPill)

        if let line = liveLine, liveLineMatchesSportFilter(line) {
            let liveProp = livePropBet(from: line, slateKey: slateKey)
            let liveRibbon = PlayPropRibbon(
                id: "live_api",
                title: "Live · API",
                subtitle: "Cached moneyline (h2h) — swap for player props via TheOddsAPIPlayboardHook",
                props: [liveProp]
            )
            board = [liveRibbon] + board
        }
        ribbons = Self.ribbonsDroppingEmpty(JuicdOddsNightly.applyBoosts(to: board, slateKey: slateKey))
        tomorrowRibbons = []
        // Never mint a daily/weekly tourney from the local demo board.
    }

    private func logTourneyDiagnostics(_ diags: TourneyDiagnostics?) {
        for diag in [diags?.daily, diags?.weekly].compactMap({ $0 }) where !diag.ok {
            AppErrorLogger.log(
                severity: .error,
                message: diag.detail,
                screen: "tourney",
                extra: [
                    "kind": .string(diag.kind),
                    "fallback": .string(diag.fallback),
                ]
            )
        }
    }

    private func logClientTourneyBuildFailure(
        kind: String,
        payload: RemoteTourneyPayload?,
        propCount: Int,
        source: String
    ) {
        guard payload == nil else { return }
        AppErrorLogger.log(
            severity: .error,
            message: "Could not generate \(kind) tourney from \(propCount) live props (source=\(source); local demo refused).",
            screen: "tourney",
            extra: [
                "kind": .string(kind),
                "fallback": .string("none"),
                "source": .string(source),
                "prop_count": .int(propCount),
            ]
        )
    }

    /// Props across the full cross-sport inventory (stub + optional live line), or the remote board when active.
    private func propsUnionForSportToolbar() -> [PlayPropBet] {
        if boardUsesRemoteFeed {
            return ribbons.flatMap(\.props) + tomorrowRibbons.flatMap(\.props)
        }
        let slateKey = SlateDay.slateKey()
        var inventory = JuicdOddsNightly.applyBoosts(
            to: DailySlateBoard.ribbons(forSlateKey: slateKey, sport: .forYou),
            slateKey: slateKey
        )
        if let line = liveLine {
            let liveProp = livePropBet(from: line, slateKey: slateKey)
            guard liveProp.oddsDecimal > 1.001 else {
                return Self.ribbonsDroppingEmpty(inventory).flatMap(\.props)
            }
            let liveRibbon = PlayPropRibbon(
                id: "live_api",
                title: "Live · API",
                subtitle: "Cached moneyline (h2h) — swap for player props via TheOddsAPIPlayboardHook",
                props: [liveProp]
            )
            inventory = [liveRibbon] + inventory
        }
        return Self.ribbonsDroppingEmpty(inventory).flatMap(\.props)
    }

    private func clampSportPillToAvailableOdds() {
        let allowed = Self.sportPillsMatchingLeagues(on: propsUnionForSportToolbar())
        guard !allowed.contains(sportPill) else { return }
        sportPill = .forYou
    }

    private func displayed(from source: [PlayPropRibbon]) -> [PlayPropRibbon] {
        source.compactMap { ribbon in
            var r = ribbon
            r.props = PlayLineGrouping.collapseBoardLines(ribbon.props.filter { prop in
                !prop.hasStarted && propMatchesFilters(prop)
            })
            if r.props.isEmpty { return nil }
            return r
        }
    }

    private static func usableTourney(_ payload: RemoteTourneyPayload?) -> RemoteTourneyPayload? {
        guard let payload, !payload.containsBannedPlaceholder else { return nil }
        return payload
    }

    private static func mapRibbons(
        _ dtos: [SupabasePlayBoardResponse.RibbonDTO],
        slateKey: String
    ) -> [PlayPropRibbon] {
        dtos.map { ribbon in
            let props = ribbon.props.compactMap { dto -> PlayPropBet? in
                guard dto.oddsDecimal > 1.001 else { return nil }
                let fallbackId = StableUUID.from(
                    "\(slateKey)|\(ribbon.id)|\(dto.athleteOrTeam)|\(dto.pickLabel)|\(dto.lineText)"
                )
                let commence = Self.parseISO(dto.commenceTime)
                if let commence, commence <= .now { return nil }
                return PlayPropBet(
                    id: UUID(uuidString: dto.id) ?? fallbackId,
                    leagueTag: dto.leagueTag,
                    athleteOrTeam: dto.athleteOrTeam,
                    matchup: dto.matchup,
                    propDescription: dto.propDescription,
                    lineText: dto.lineText,
                    pickLabel: dto.pickLabel,
                    oddsDecimal: dto.oddsDecimal,
                    commenceTime: commence,
                    eventId: dto.eventId,
                    sportKey: dto.sportKey,
                    homeTeam: dto.homeTeam,
                    awayTeam: dto.awayTeam,
                    pointLine: dto.pointLine,
                    overOdds: dto.overOdds,
                    underOdds: dto.underOdds
                )
            }
            return PlayPropRibbon(
                id: ribbon.id,
                title: ribbon.title,
                subtitle: ribbon.subtitle,
                props: PlayLineGrouping.collapseBoardLines(props)
            )
        }
    }

    private static func ribbonsDroppingEmpty(_ ribbons: [PlayPropRibbon]) -> [PlayPropRibbon] {
        ribbons.compactMap { ribbon in
            let props = ribbon.props.filter { $0.oddsDecimal > 1.001 }
            guard !props.isEmpty else { return nil }
            var r = ribbon
            r.props = props
            return r
        }
    }

    private static func sportPillsMatchingLeagues(on props: [PlayPropBet]) -> [PlaySportPill] {
        var pills: [PlaySportPill] = [.forYou]
        for pill in PlaySportPill.primaryRow where pill != .forYou {
            if props.contains(where: { pill.matchesLeagueTag($0.leagueTag) }) {
                pills.append(pill)
            }
        }
        return pills
    }

    private func liveLineMatchesSportFilter(_ line: LiveOddsLine) -> Bool {
        let tag = leagueTag(from: line.sportKey)
        return sportPill.matchesLeagueTag(tag)
    }

    private func propMatchesFilters(_ prop: PlayPropBet) -> Bool {
        if sportPill == .forYou { return true }
        guard sportPill.matchesLeagueTag(prop.leagueTag) else { return false }
        guard matchesStatFilter(prop) else { return false }
        return matchesSearch(prop)
    }

    private func matchesStatFilter(_ prop: PlayPropBet) -> Bool {
        guard sportPill != .forYou else { return true }
        guard statFilterId != "all" else { return true }
        if statFilterId == "popular" { return prop.isPopularStyleLine }
        return prop.statFilterKey == statFilterId
    }

    private func matchesSearch(_ prop: PlayPropBet) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return prop.athleteOrTeam.lowercased().contains(q)
            || prop.matchup.lowercased().contains(q)
            || prop.leagueTag.lowercased().contains(q)
            || prop.propDescription.lowercased().contains(q)
    }

    func refreshProfile() {
        guard let userId else { return }
        profile = repository.profile(userId: userId)
        tomorrowPointsRemaining = repository.pointsRemaining(
            userId: userId,
            slateDayKey: SlateDay.nextSlateKey()
        )
        clampStakeToBalance()
    }

    func clampStakeToBalance() {
        let m = maxStakePoints
        if m <= 0 {
            stakePoints = 0
            return
        }
        if stakePoints > m { stakePoints = m }
        if stakePoints < 1 { stakePoints = min(m, 1) }
    }


    /// When adding a parlay leg, false if this market conflicts with the slip (duplicate line / wrong slate / full).
    func isSelectableForParlay(_ prop: PlayPropBet) -> Bool {
        guard pickingAdditionalLeg else { return true }
        if parlayLegs.count >= Self.maxParlayLegs { return false }
        if let first = parlayLegs.first, !Self.sameSlate(first, prop) { return false }
        if parlayLegs.contains(where: { $0.marketLineKey == prop.marketLineKey }) { return false }
        return true
    }

    func handleOverUnder(_ prop: PlayPropBet, side: String, odds: Double) {
        handlePropTap(prop.choosingOverUnder(side: side, odds: odds))
    }

    func handleMoneyline(_ prop: PlayPropBet, side: String, odds: Double) {
        handlePropTap(prop.choosingMoneyline(side: side, odds: odds))
    }

    func handlePropTap(_ prop: PlayPropBet) {
        if prop.hasOverUnderChoice, prop.pickLabel == "O/U" {
            return
        }
        if prop.hasMoneylineChoice, prop.pickLabel == "H2H" {
            return
        }
        if prop.hasStarted {
            builderToast = "That game already started."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                self?.builderToast = nil
            }
            return
        }
        if pickingAdditionalLeg {
            if let first = parlayLegs.first, !Self.sameSlate(first, prop) {
                builderToast = "Parlay legs must be on the same Juicd day."
                pickingAdditionalLeg = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                    self?.builderToast = nil
                }
                return
            }
            if parlayLegs.contains(where: { $0.marketLineKey == prop.marketLineKey }) {
                builderToast = "That line is already on your slip."
                pickingAdditionalLeg = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                    self?.builderToast = nil
                }
                return
            }
            addParlayLeg(prop)
            pickingAdditionalLeg = false
            showParlayBuilder = true
            builderToast = "Leg added."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.builderToast = nil
            }
            return
        }
        parlayLegs = [prop]
        clampStakeToBalance()
        showParlayBuilder = true
    }

    static func sameKickoff(_ a: PlayPropBet, _ b: PlayPropBet) -> Bool {
        if let ae = a.eventId, let be = b.eventId, !ae.isEmpty, ae == be { return true }
        guard let at = a.commenceTime, let bt = b.commenceTime else { return false }
        return abs(at.timeIntervalSince(bt)) < 60
    }

    static func slateKey(for prop: PlayPropBet, now: Date = .now) -> String {
        if let commence = prop.commenceTime {
            return SlateDay.slateKey(for: commence)
        }
        return SlateDay.slateKey(for: now)
    }

    static func sameSlate(_ a: PlayPropBet, _ b: PlayPropBet, now: Date = .now) -> Bool {
        slateKey(for: a, now: now) == slateKey(for: b, now: now)
    }

    private static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    func addParlayLeg(_ prop: PlayPropBet) {
        guard parlayLegs.count < Self.maxParlayLegs else { return }
        guard !parlayLegs.contains(where: { $0.id == prop.id || $0.marketLineKey == prop.marketLineKey }) else { return }
        parlayLegs.append(prop)
    }

    func removeParlayLeg(at index: Int) {
        guard parlayLegs.indices.contains(index) else { return }
        parlayLegs.remove(at: index)
        if parlayLegs.isEmpty {
            showParlayBuilder = false
        }
    }

    func beginAddLeg() {
        guard parlayLegs.count < Self.maxParlayLegs else { return }
        pickingAdditionalLeg = true
    }

    func cancelAddLeg() {
        pickingAdditionalLeg = false
    }

    func placeBetTapped() {
        guard userId != nil else { return }
        guard !parlayLegs.isEmpty else { return }
        guard !isSubmittingPlayParlay else { return }
        clampStakeToBalance()
        guard stakePoints >= 1, stakePoints <= maxStakePoints else { return }
        Task { await executePlaceParlay() }
    }

    func executePlaceParlay() async {
        guard !isSubmittingPlayParlay else { return }
        isSubmittingPlayParlay = true
        defer { isSubmittingPlayParlay = false }

        showFirstBetReminder = false
        guard let userId else { return }
        guard !parlayLegs.isEmpty else { return }
        clampStakeToBalance()
        guard stakePoints >= 1, stakePoints <= maxStakePoints else { return }

        let legs = parlayLegs.map { $0.asBetLeg() }
        if parlayLegs.contains(where: \.hasStarted) {
            builderToast = "A selected game already started."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.builderToast = nil }
            return
        }
        if parlayLegs.count > 1 {
            let first = parlayLegs[0]
            if parlayLegs.dropFirst().contains(where: { !Self.sameSlate(first, $0) }) {
                builderToast = "Parlay legs must be on the same Juicd day."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.builderToast = nil }
                return
            }
            let keys = parlayLegs.map(\.marketLineKey)
            if Set(keys).count != keys.count {
                builderToast = "Duplicate lines are not allowed in one parlay."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.builderToast = nil }
                return
            }
        }

        let legCount = legs.count
        let stake = stakePoints
        if let outcome = repository.submitPlayParlay(
            userId: userId,
            stakePoints: stakePoints,
            legs: legs
        ) {
            profile = repository.profile(userId: userId)
            AnalyticsService.logSlipSubmitted(legCount: legCount, stakePoints: stake)
            if outcome.pending {
                builderToast = "Locked in — pending until the game ends."
            } else if outcome.didWin {
                builderToast = "Hit! +\(outcome.seasonPointsEarned) season pts"
            } else {
                builderToast = "Parlay didn’t hit — try another."
            }
            parlayLegs = []
            showParlayBuilder = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                self?.builderToast = nil
            }
        } else {
            builderToast = "Couldn’t place bet."
            AppErrorLogger.log(
                severity: .error,
                message: "submitPlayParlay returned nil",
                screen: "play",
                extra: ["leg_count": .int(legCount)]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.builderToast = nil
            }
        }
        clampStakeToBalance()
    }

    private func livePropBet(from line: LiveOddsLine, slateKey: String) -> PlayPropBet {
        let tag = leagueTag(from: line.sportKey)
        return PlayPropBet(
            id: StableUUID.from("\(slateKey)|live_api|h2h"),
            leagueTag: tag,
            athleteOrTeam: line.pickLabel,
            matchup: line.eventTitle,
            propDescription: "Head-to-head",
            lineText: "H2H",
            pickLabel: line.pickLabel,
            oddsDecimal: line.oddsDecimal,
            juicdMultiplier: nil
        )
    }

    private func leagueTag(from sportKey: String) -> String {
        if sportKey.contains("nba") { return "NBA" }
        if sportKey.contains("nfl") || sportKey.contains("americanfootball") { return "NFL" }
        if sportKey.contains("nhl") { return "NHL" }
        if sportKey.contains("mlb") || sportKey.contains("baseball_mlb") { return "MLB" }
        if sportKey.contains("soccer") { return "SOC" }
        return "LIVE"
    }
}
