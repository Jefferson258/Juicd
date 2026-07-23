import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var playSlipsForSelectedSlate: [PlayBoardEntry] = []
    /// Slate keys available in the picker: always includes today’s slate, plus any past slate with slips.
    @Published private(set) var playSlatePickerKeys: [String] = []
    @Published var selectedPlaySlateKey: String = SlateDay.slateKey()

    /// Full tier ladder (low → high) for display — tier moves via daily pools, not point thresholds.
    var rankLadder: [RankTier] { RankTier.ladderOrder }

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        refresh()
    }

    func refresh() {
        guard let userId else {
            profile = nil
            playSlipsForSelectedSlate = []
            playSlatePickerKeys = []
            return
        }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)

        let todayKey = SlateDay.slateKey()
        var keys = Set(repository.distinctPlaySlateDayKeys(for: userId))
        keys.insert(todayKey)
        playSlatePickerKeys = keys.sorted(by: >)

        if !playSlatePickerKeys.contains(selectedPlaySlateKey) {
            selectedPlaySlateKey = todayKey
        }
        playSlipsForSelectedSlate = repository.playBoardEntries(userId: userId, slateDayKey: selectedPlaySlateKey)
        AnalyticsService.logDashboardSlipsView(
            slateKey: selectedPlaySlateKey,
            slipCount: playSlipsForSelectedSlate.count
        )
    }

    func selectPlaySlate(_ slateKey: String) {
        selectedPlaySlateKey = slateKey
        guard let userId else {
            playSlipsForSelectedSlate = []
            return
        }
        playSlipsForSelectedSlate = repository.playBoardEntries(userId: userId, slateDayKey: slateKey)
        AnalyticsService.logDashboardSlipsView(
            slateKey: slateKey,
            slipCount: playSlipsForSelectedSlate.count
        )
    }
}
