import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var badges: [RewardBadge] = []

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        profile = repository.profile(userId: userId)
        badges = repository.userBadges(userId: userId)
    }

    func simulateSeasonEndAward() {
        guard let userId else { return }
        repository.awardSeasonBadgesIfNeeded(userId: userId)
        badges = repository.userBadges(userId: userId)
    }

    func resetSeason() {
        guard let userId else { return }
        repository.resetSeason(for: userId)
        profile = repository.profile(userId: userId)
        badges = repository.userBadges(userId: userId)
    }
}
