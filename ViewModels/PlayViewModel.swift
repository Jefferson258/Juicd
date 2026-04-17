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

    @Published var sportPill: PlaySportPill = .forYou {
        didSet {
            if sportPill == .forYou {
                statFilterId = "all"
                searchText = ""
            } else {
                statFilterId = "popular"
            }
            rebuildRibbons()
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
        return min(InMemoryJuicdRepository.dailyPlayAllowancePoints, profile.availableDailyPoints)
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
    }

    func refreshLiveOddsLine() async {
        guard OddsAPIConfig.isConfigured else {
            oddsStatus = "Add ODDS_API_KEY in Xcode target Info to load a live line."
            liveLine = nil
            rebuildRibbons()
            return
        }
        isLoadingOdds = true
        oddsStatus = "Loading one line…"
        let line = await TheOddsAPIService.fetchOneCachedLine()
        liveLine = line
        isLoadingOdds = false
        rebuildRibbons()
        if let line {
            oddsStatus = "Live (cached up to 1h) · \(line.sportKey)"
        } else {
            oddsStatus = "Couldn’t load odds (off-season or network)."
        }
    }

    private func rebuildRibbons() {
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
        ribbons = JuicdOddsNightly.applyBoosts(to: board, slateKey: slateKey)
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
        clampStakeToBalance()
        guard stakePoints >= 1, stakePoints <= maxStakePoints else { return }
        executePlaceParlay()
    }

    func executePlaceParlay() {
        showFirstBetReminder = false
        guard let userId else { return }
        guard !parlayLegs.isEmpty else { return }
        clampStakeToBalance()
        guard stakePoints >= 1, stakePoints <= maxStakePoints else { return }

        let legs = parlayLegs.map { $0.asBetLeg() }
        if let outcome = repository.submitPlayParlay(userId: userId, stakePoints: stakePoints, legs: legs) {
            profile = repository.profile(userId: userId)
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
