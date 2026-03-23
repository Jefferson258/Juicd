import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var todaysEntries: [PlayBoardEntry] = []

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
            todaysEntries = []
            return
        }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        todaysEntries = repository.playBoardEntriesOnSlate(userId: userId)
    }
}
