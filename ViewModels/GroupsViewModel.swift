import Foundation
import Combine

@MainActor
final class GroupsViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published private(set) var myGroups: [Group] = []
    @Published var newGroupName: String = ""
    @Published var joinInviteCode: String = ""

    @Published var selectedGroupId: UUID?
    @Published var weekIndex: Int = 1
    @Published private(set) var weeklyScoreboard: [(userName: String, points: Int)] = []
    @Published private(set) var myWeeklyPoints: Int?

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard let userId else { return }
        repository.resolveDailyRankOutcomes(userId: userId, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId, date: .now)
        myGroups = repository.groupsForUser(userId)
        selectedGroupId = myGroups.first?.id
        refreshWeeklyScoreboard()
    }

    func refreshWeeklyScoreboard() {
        guard let gid = selectedGroupId else {
            weeklyScoreboard = []
            myWeeklyPoints = nil
            return
        }
        weeklyScoreboard = repository.weeklyGroupScoreboard(for: gid, weekIndex: weekIndex)
        if let userId {
            myWeeklyPoints = repository.weeklySubmittedPointsForUser(userId: userId, groupId: gid, weekIndex: weekIndex)
        }
    }

    func submitWeeklyPicks() {
        guard let userId else { return }
        guard let gid = selectedGroupId else { return }
        let points = repository.submitWeeklyPicks(groupId: gid, weekIndex: weekIndex, userId: userId)
        myWeeklyPoints = points
        refreshWeeklyScoreboard()
    }

    func createGroup() {
        guard let userId else { return }
        let group = repository.createGroup(name: newGroupName, createdBy: userId)
        newGroupName = ""
        myGroups = repository.groupsForUser(userId)
        selectedGroupId = group.id
        refreshWeeklyScoreboard()
    }

    func joinGroup() {
        guard let userId else { return }
        guard let group = repository.joinGroup(byInviteCode: joinInviteCode, userId: userId) else {
            return
        }
        joinInviteCode = ""
        myGroups = repository.groupsForUser(userId)
        selectedGroupId = group.id
        refreshWeeklyScoreboard()
    }
}

