import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var profile: Profile?
    @Published private(set) var userGroupsCount: Int = 0

    struct TierRule: Identifiable {
        var id: RankTier { tier }
        let tier: RankTier
        let minPointsWonInclusive: Int
        let maxPointsWonExclusive: Int?
    }

    private let rules: [TierRule] = [
        TierRule(tier: .bronze, minPointsWonInclusive: 0, maxPointsWonExclusive: 100),
        TierRule(tier: .silver, minPointsWonInclusive: 100, maxPointsWonExclusive: 300),
        TierRule(tier: .gold, minPointsWonInclusive: 300, maxPointsWonExclusive: 700),
        TierRule(tier: .platinum, minPointsWonInclusive: 700, maxPointsWonExclusive: 1200),
        TierRule(tier: .emerald, minPointsWonInclusive: 1200, maxPointsWonExclusive: 1900),
        TierRule(tier: .diamond, minPointsWonInclusive: 1900, maxPointsWonExclusive: 2600),
        TierRule(tier: .challenger, minPointsWonInclusive: 2600, maxPointsWonExclusive: 3800),
        TierRule(tier: .champion, minPointsWonInclusive: 3800, maxPointsWonExclusive: nil)
    ]

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }

        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        repository.recalculateTier(for: userId)
        profile = repository.profile(userId: userId)
        userGroupsCount = repository.groupsForUser(userId).count
    }

    var tierRules: [TierRule] { rules }
}
