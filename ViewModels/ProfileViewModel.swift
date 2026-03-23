import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var badges: [RewardBadge] = []
    @Published private(set) var careerStats: CareerBettingStats?
    @Published private(set) var seasonStats: CareerBettingStats?

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        refresh()
    }

    func refresh() {
        guard let userId else { return }
        profile = repository.profile(userId: userId)
        badges = repository.userBadges(userId: userId)
        careerStats = repository.careerBettingStats(userId: userId)
        seasonStats = repository.seasonBettingStats(userId: userId)
    }

    func simulateSeasonEndAward() {
        guard let userId else { return }
        repository.awardSeasonBadgesIfNeeded(userId: userId)
        refresh()
    }

    func resetSeason() {
        guard let userId else { return }
        repository.resetSeason(for: userId)
        refresh()
    }

    func resetDailyClosestTournamentForTesting() {
        guard let userId else { return }
        repository.resetDailyClosestTournamentForTesting(userId: userId)
        refresh()
    }

    func resetDailyPlayBalanceForTesting() {
        guard let userId else { return }
        repository.resetDailyPlayBalanceForTesting(userId: userId)
        refresh()
    }
}
