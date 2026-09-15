import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?
    private var repoCancellable: AnyCancellable?

    @Published private(set) var profile: Profile?
    @Published private(set) var tomorrowPointsRemaining: Int = JuicdBalance.dailyPlayAllowancePoints
    @Published private(set) var playSlipsForSelectedSlate: [PlayBoardEntry] = []
    /// Slate keys available in the picker: always includes today + tomorrow, plus any past slate with slips.
    @Published private(set) var playSlatePickerKeys: [String] = []
    @Published var selectedPlaySlateKey: String = SlateDay.slateKey()

    /// Full tier ladder (low → high) for display — tier moves via daily pools, not point thresholds.
    var rankLadder: [RankTier] { RankTier.ladderOrder }

    var isShowingActiveSlates: Bool {
        let today = SlateDay.slateKey()
        let tomorrow = SlateDay.nextSlateKey()
        return selectedPlaySlateKey == today || selectedPlaySlateKey == tomorrow
    }

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        repoCancellable = repository.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.reloadFromRepository()
                }
            }
    }

    func configure(userId: UUID?) {
        self.userId = userId
        refresh()
    }

    func refresh() {
        guard let userId else {
            profile = nil
            tomorrowPointsRemaining = JuicdBalance.dailyPlayAllowancePoints
            playSlipsForSelectedSlate = []
            playSlatePickerKeys = []
            return
        }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        reloadFromRepository(logView: true)
    }

    func reloadFromRepository(logView: Bool = false) {
        guard let userId else {
            profile = nil
            tomorrowPointsRemaining = JuicdBalance.dailyPlayAllowancePoints
            playSlipsForSelectedSlate = []
            playSlatePickerKeys = []
            return
        }
        profile = repository.profile(userId: userId)
        let todayKey = SlateDay.slateKey()
        let tomorrowKey = SlateDay.nextSlateKey()
        tomorrowPointsRemaining = repository.pointsRemaining(userId: userId, slateDayKey: tomorrowKey)

        var keys = Set(repository.distinctPlaySlateDayKeys(for: userId))
        keys.insert(todayKey)
        keys.insert(tomorrowKey)
        playSlatePickerKeys = keys.sorted(by: >)

        if !playSlatePickerKeys.contains(selectedPlaySlateKey) {
            selectedPlaySlateKey = todayKey
        }
        playSlipsForSelectedSlate = slips(for: selectedPlaySlateKey, userId: userId)
        if logView {
            AnalyticsService.logDashboardSlipsView(
                slateKey: selectedPlaySlateKey,
                slipCount: playSlipsForSelectedSlate.count
            )
        }
    }

    func selectPlaySlate(_ slateKey: String) {
        selectedPlaySlateKey = slateKey
        guard let userId else {
            playSlipsForSelectedSlate = []
            return
        }
        playSlipsForSelectedSlate = slips(for: slateKey, userId: userId)
        AnalyticsService.logDashboardSlipsView(
            slateKey: slateKey,
            slipCount: playSlipsForSelectedSlate.count
        )
    }

    private func slips(for slateKey: String, userId: UUID) -> [PlayBoardEntry] {
        let today = SlateDay.slateKey()
        let tomorrow = SlateDay.nextSlateKey()
        if slateKey == today {
            return repository.playBoardEntriesOnActiveSlates(userId: userId)
        }
        if slateKey == tomorrow {
            return repository.playBoardEntries(userId: userId, slateDayKey: tomorrow)
        }
        return repository.playBoardEntries(userId: userId, slateDayKey: slateKey)
    }
}
