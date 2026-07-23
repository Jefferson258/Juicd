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

    /// When true, `ribbons` came from Supabase and must not be replaced by local stub rebuilds when switching sport filters.
    private var boardUsesRemoteFeed = false

    /// Bumps on each odds refresh start; completions from older generations are discarded (avoids overlapping `Task`s corrupting board state).
    private var oddsRefreshGeneration: UInt64 = 0

    @Published private(set) var isSubmittingPlayParlay = false

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
    }

    var maxStakePoints: Int {
        guard let profile else { return 0 }
        return min(JuicdBalance.dailyPlayAllowancePoints, profile.availableDailyPoints)
    }

    var impliedParlayDecimal: Double {
        guard !parlayLegs.isEmpty else { return 1 }
        return parlayLegs.map(\.juicdEffectiveDecimalOdds).reduce(1.0, *)
    }

    var estimatedSeasonPointsIfWin: Int {
        repository.estimatedNetPointsPayout(stakePoints: stakePoints, parlayOddsDecimal: impliedParlayDecimal)
    }

    /// Ribbons with props filtered for UI (search / stat / sport).
    var displayedRibbons: [PlayPropRibbon] {
        ribbons.compactMap { ribbon in
            var r = ribbon
            r.props = ribbon.props.filter { propMatchesFilters($0) }
            if r.props.isEmpty { return nil }
            return r
        }
    }

    var hasActiveSearch: Bool {
        sportPill != .forYou && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sport filter pills that currently have at least one priced prop on the board (always includes **For You**).
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
        Task { await refreshLiveOddsLine() }
    }

    func refreshLiveOddsLine() async {
        oddsRefreshGeneration &+= 1
        let generation = oddsRefreshGeneration

        if SupabaseConfig.isConfigured {
            if let serverBoard = await SupabaseOddsService.fetchPlayBoard() {
                guard generation == oddsRefreshGeneration else { return }
                liveLine = nil
                isLoadingOdds = false
                oddsStatus = "Supabase \(serverBoard.mode) · \(serverBoard.source)"
                let mapped = serverBoard.ribbons.map { ribbon in
                    PlayPropRibbon(
                        id: ribbon.id,
                        title: ribbon.title,
                        subtitle: ribbon.subtitle,
                        props: ribbon.props.compactMap { dto in
                            guard dto.oddsDecimal > 1.001 else { return nil }
                            let fallbackId = StableUUID.from(
                                "\(serverBoard.slateKey)|\(ribbon.id)|\(dto.athleteOrTeam)|\(dto.pickLabel)|\(dto.lineText)"
                            )
                            return PlayPropBet(
                                id: UUID(uuidString: dto.id) ?? fallbackId,
                                leagueTag: dto.leagueTag,
                                athleteOrTeam: dto.athleteOrTeam,
                                matchup: dto.matchup,
                                propDescription: dto.propDescription,
                                lineText: dto.lineText,
                                pickLabel: dto.pickLabel,
                                oddsDecimal: dto.oddsDecimal
                            )
                        }
                    )
                }
                let trimmed = Self.ribbonsDroppingEmpty(mapped)
                if trimmed.isEmpty {
                    boardUsesRemoteFeed = false
                    oddsStatus = "Supabase \(serverBoard.mode) · no priced props — showing local board"
                    AnalyticsService.logOddsSync(ok: false, source: "supabase_empty")
                    rebuildRibbons()
                } else {
                    boardUsesRemoteFeed = true
                    ribbons = trimmed
                    AnalyticsService.logOddsSync(ok: true, source: "supabase_\(serverBoard.mode)")
                }
                clampSportPillToAvailableOdds()
                return
            }
            guard generation == oddsRefreshGeneration else { return }
            AnalyticsService.logOddsSync(ok: false, source: "supabase_fetch")
            AppErrorLogger.log(
                severity: .warning,
                message: "play-board fetch returned nil",
                screen: "play",
                extra: ["source": .string("supabase_fetch")]
            )
        }

        guard generation == oddsRefreshGeneration else { return }

        boardUsesRemoteFeed = false
        guard OddsAPIConfig.isConfigured else {
            oddsStatus = "Local demo odds available"
            liveLine = nil
            rebuildRibbons()
            clampSportPillToAvailableOdds()
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
            AppErrorLogger.log(
                severity: .warning,
                message: "Odds API returned no line",
                screen: "play",
                extra: ["source": .string("odds_api")]
            )
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
    }

    /// Props across the full cross-sport inventory (stub + optional live line), or the remote board when active.
    private func propsUnionForSportToolbar() -> [PlayPropBet] {
        if boardUsesRemoteFeed {
            return ribbons.flatMap(\.props)
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

    func handlePropTap(_ prop: PlayPropBet) {
        if pickingAdditionalLeg {
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

    func addParlayLeg(_ prop: PlayPropBet) {
        guard parlayLegs.count < Self.maxParlayLegs else { return }
        guard !parlayLegs.contains(where: { $0.id == prop.id }) else { return }
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
        let serverOutcomeMap: [UUID: Bool]? = await {
            guard SupabaseConfig.isConfigured else { return nil }
            guard let remote = await SupabaseOddsService.resolvePlaySlip(userId: userId, legs: legs) else { return nil }
            var map: [UUID: Bool] = [:]
            for legOutcome in remote.outcomes {
                if let id = UUID(uuidString: legOutcome.legId) {
                    map[id] = legOutcome.didWin
                }
            }
            return map.isEmpty ? nil : map
        }()

        let legCount = legs.count
        let stake = stakePoints
        if let outcome = repository.submitPlayParlay(
            userId: userId,
            stakePoints: stakePoints,
            legs: legs,
            forcedLegOutcomesByLegId: serverOutcomeMap
        ) {
            profile = repository.profile(userId: userId)
            AnalyticsService.logSlipSubmitted(legCount: legCount, stakePoints: stake)
            AnalyticsService.logSlipResolved(won: outcome.didWin, legCount: legCount)
            if outcome.didWin {
                builderToast = "Hit! +\(outcome.seasonPointsEarned) season pts"
            } else {
                builderToast = "Parlay didn’t hit — try another."
            }
            parlayLegs = []
            showParlayBuilder = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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
            propDescription: "Moneyline (head-to-head)",
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
