import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var userGroupsCount: Int = 0

    /// Full tier ladder (low → high) for display — tier moves via daily pools, not point thresholds.
    var rankLadder: [RankTier] { RankTier.ladderOrder }

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }

        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        userGroupsCount = repository.groupsForUser(userId).count
    }
}
