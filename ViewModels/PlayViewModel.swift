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

    /// Stub ribbons + optional live API ribbon (see `TheOddsAPIPlayboardHook` for player props later).
    @Published private(set) var ribbons: [PlayPropRibbon] = []

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        ribbons = JuicdOddsNightly.applyBoosts(to: Self.ribbonsWithLiveLine(nil, base: PlayBoardStubData.allRibbons), date: .now)
    }

    func refreshLiveOddsLine() async {
        guard OddsAPIConfig.isConfigured else {
            oddsStatus = "Add ODDS_API_KEY in Xcode target Info to load a live line."
            liveLine = nil
            ribbons = JuicdOddsNightly.applyBoosts(to: Self.ribbonsWithLiveLine(nil, base: PlayBoardStubData.allRibbons), date: .now)
            return
        }
        isLoadingOdds = true
        oddsStatus = "Loading one line…"
        let line = await TheOddsAPIService.fetchOneCachedLine()
        liveLine = line
        isLoadingOdds = false
        ribbons = JuicdOddsNightly.applyBoosts(to: Self.ribbonsWithLiveLine(line, base: PlayBoardStubData.allRibbons), date: .now)
        if let line {
            oddsStatus = "Live (cached up to 1h) · \(line.sportKey)"
        } else {
            oddsStatus = "Couldn’t load odds (off-season or network)."
        }
    }

    /// Inserts a **Live · API** ribbon with one moneyline tile when `TheOddsAPIService` returns data.
    private static func ribbonsWithLiveLine(_ line: LiveOddsLine?, base: [PlayPropRibbon]) -> [PlayPropRibbon] {
        guard let line else { return base }
        let liveBet = propBet(from: line)
        let liveRibbon = PlayPropRibbon(
            id: "live_api",
            title: "Live · API",
            subtitle: "Cached moneyline (h2h) — swap for player props via TheOddsAPIPlayboardHook",
            props: [liveBet]
        )
        return [liveRibbon] + base
    }

    private static func propBet(from line: LiveOddsLine) -> PlayPropBet {
        let tag = leagueTag(from: line.sportKey)
        return PlayPropBet(
            id: UUID(),
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

    private static func leagueTag(from sportKey: String) -> String {
        if sportKey.contains("nba") { return "NBA" }
        if sportKey.contains("nfl") || sportKey.contains("americanfootball") { return "NFL" }
        if sportKey.contains("nhl") { return "NHL" }
        if sportKey.contains("mlb") || sportKey.contains("baseball_mlb") { return "MLB" }
        if sportKey.contains("soccer") { return "SOC" }
        return "LIVE"
    }
}
