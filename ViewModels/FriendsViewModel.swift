import Foundation
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    private let repository: InMemoryJuicdRepository
    private var userId: UUID?

    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [Profile] = []

    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    @Published private(set) var leaderboard: [(rank: Int, profile: Profile)] = []

    @Published var selectedFriend: Profile?
    @Published private(set) var friendPlayEntries: [PlayBoardEntry] = []
    @Published private(set) var friendFormWins: Int = 0
    @Published private(set) var friendFormLosses: Int = 0

    @Published var errorMessage: String?

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard userId != nil else { return }
        repository.resolveDailyRankOutcomes(userId: userId!, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId!, date: .now)
        refresh()
    }

    func refresh() {
        guard let userId else { return }
        incomingRequests = repository.incomingFriendRequests(for: userId)
        outgoingRequests = repository.outgoingFriendRequests(for: userId)
        leaderboard = repository.friendLeaderboardRows(for: userId)
        runSearch()
        if let sel = selectedFriend, let updated = repository.profile(userId: sel.id) {
            selectedFriend = updated
            loadFriendDetail(updated)
        }
    }

    func runSearch() {
        guard let userId else {
            searchResults = []
            return
        }
        searchResults = repository.searchProfilesForFriendInvite(excludingUserId: userId, query: searchQuery)
    }

    func sendRequest(to profile: Profile) {
        guard let userId else { return }
        errorMessage = nil
        if repository.sendFriendRequest(from: userId, to: profile.id) {
            searchQuery = ""
            refresh()
        } else {
            errorMessage = "Couldn’t send request (already friends or pending)."
        }
    }

    func accept(_ request: FriendRequest) {
        guard let userId else { return }
        _ = repository.acceptFriendRequest(requestId: request.id, asUserId: userId)
        refresh()
    }

    func reject(_ request: FriendRequest) {
        guard let userId else { return }
        _ = repository.rejectFriendRequest(requestId: request.id, asUserId: userId)
        refresh()
    }

    func cancelOutgoing(_ request: FriendRequest) {
        guard let userId else { return }
        _ = repository.cancelOutgoingFriendRequest(requestId: request.id, asUserId: userId)
        refresh()
    }

    func displayName(for id: UUID) -> String {
        repository.profile(userId: id)?.displayName ?? "Player"
    }

    func selectFriend(_ profile: Profile) {
        selectedFriend = profile
        loadFriendDetail(profile)
    }

    func loadFriendDetail(_ profile: Profile) {
        friendPlayEntries = repository.recentPlayEntries(userId: profile.id, limit: 15)
        let f = repository.recentPlayForm(userId: profile.id, last: 7)
        friendFormWins = f.wins
        friendFormLosses = f.losses
    }

    func clearSelection() {
        selectedFriend = nil
        friendPlayEntries = []
        friendFormWins = 0
        friendFormLosses = 0
    }
}
