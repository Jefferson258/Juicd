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
    @Published private(set) var seasonLeaderboard: [JuicdSocialService.LeaderboardRow] = []
    @Published private(set) var allTimeLeaderboard: [JuicdSocialService.LeaderboardRow] = []

    @Published private(set) var groups: [Group] = []
    @Published var newGroupName: String = ""
    @Published var joinGroupCode: String = ""
    @Published var friendCode: String?

    @Published var selectedFriend: Profile?
    @Published private(set) var friendPlayEntries: [PlayBoardEntry] = []
    @Published private(set) var friendFormWins: Int = 0
    @Published private(set) var friendFormLosses: Int = 0

    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var isBusy = false

    private var useCloud: Bool {
        SupabaseConfig.isConfigured && SupabaseAuthService.isSignedIn
    }

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func configure(userId: UUID?) {
        self.userId = userId
        guard userId != nil else { return }
        repository.resolveDailyRankOutcomes(userId: userId!, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: userId!, date: .now)
        Task { await refreshAsync() }
    }

    func refresh() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        guard let userId else { return }
        errorMessage = nil
        if useCloud {
            await refreshCloud(userId: userId)
        } else {
            refreshLocal(userId: userId)
        }
        if let sel = selectedFriend {
            loadFriendDetail(sel)
        }
    }

    func runSearch() {
        Task { await runSearchAsync() }
    }

    func runSearchAsync() async {
        guard let userId else {
            searchResults = []
            return
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            searchResults = []
            return
        }
        if useCloud {
            do {
                let rows = try await JuicdSocialService.searchProfiles(query: q, excluding: userId)
                searchResults = rows.map { $0.asProfile() }
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchResults = []
                AppErrorLogger.log(
                    severity: .warning,
                    message: error.localizedDescription,
                    screen: "friends",
                    extra: ["phase": .string("search")]
                )
            }
        } else {
            searchResults = repository.searchProfilesForFriendInvite(excludingUserId: userId, query: q)
        }
    }

    func sendRequest(to profile: Profile) {
        Task {
            guard let userId else { return }
            errorMessage = nil
            statusMessage = nil
            if useCloud {
                do {
                    try await JuicdSocialService.sendFriendRequest(from: userId, to: profile.id)
                    searchQuery = ""
                    searchResults = []
                    statusMessage = "Request sent to \(profile.displayName)."
                    AnalyticsService.logFriendRequestSent()
                    await refreshAsync()
                } catch {
                    errorMessage = "Couldn’t send request: \(error.localizedDescription)"
                    AppErrorLogger.log(
                        severity: .error,
                        message: error.localizedDescription,
                        screen: "friends",
                        extra: ["phase": .string("friend_request")]
                    )
                }
            } else if repository.sendFriendRequest(from: userId, to: profile.id) {
                searchQuery = ""
                AnalyticsService.logFriendRequestSent()
                await refreshAsync()
            } else {
                errorMessage = "Couldn’t send request (already friends or pending)."
            }
        }
    }

    func accept(_ request: FriendRequest) {
        Task {
            guard let userId else { return }
            if useCloud {
                do {
                    try await JuicdSocialService.acceptFriendRequest(requestId: request.id)
                    await refreshAsync()
                } catch {
                    errorMessage = "Accept failed: \(error.localizedDescription)"
                    AppErrorLogger.log(
                        severity: .error,
                        message: error.localizedDescription,
                        screen: "friends",
                        extra: ["phase": .string("accept_request")]
                    )
                }
            } else {
                _ = repository.acceptFriendRequest(requestId: request.id, asUserId: userId)
                await refreshAsync()
            }
        }
    }

    func reject(_ request: FriendRequest) {
        Task {
            guard let userId else { return }
            if useCloud {
                do {
                    try await JuicdSocialService.deleteFriendRequest(requestId: request.id)
                    await refreshAsync()
                } catch {
                    errorMessage = "Decline failed: \(error.localizedDescription)"
                }
            } else {
                _ = repository.rejectFriendRequest(requestId: request.id, asUserId: userId)
                await refreshAsync()
            }
        }
    }

    func cancelOutgoing(_ request: FriendRequest) {
        Task {
            guard let userId else { return }
            if useCloud {
                do {
                    try await JuicdSocialService.deleteFriendRequest(requestId: request.id)
                    await refreshAsync()
                } catch {
                    errorMessage = "Cancel failed: \(error.localizedDescription)"
                }
            } else {
                _ = repository.cancelOutgoingFriendRequest(requestId: request.id, asUserId: userId)
                await refreshAsync()
            }
        }
    }

    func createGroup() {
        Task {
            let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                errorMessage = "Enter a group name."
                return
            }
            isBusy = true
            defer { isBusy = false }
            do {
                if useCloud {
                    _ = try await JuicdSocialService.createGroup(name: name)
                } else if let userId {
                    _ = repository.createGroup(name: name, createdBy: userId)
                }
                newGroupName = ""
                statusMessage = "Group created."
                AnalyticsService.logGroupCreated()
                await refreshAsync()
            } catch {
                errorMessage = "Create group failed: \(error.localizedDescription)"
                AppErrorLogger.log(
                    severity: .error,
                    message: error.localizedDescription,
                    screen: "friends",
                    extra: ["phase": .string("create_group")]
                )
            }
        }
    }

    func joinGroup() {
        Task {
            let code = joinGroupCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else {
                errorMessage = "Enter an invite code."
                return
            }
            isBusy = true
            defer { isBusy = false }
            do {
                if useCloud {
                    _ = try await JuicdSocialService.joinGroup(code: code)
                } else if let userId {
                    guard repository.joinGroup(byInviteCode: code, userId: userId) != nil else {
                        errorMessage = "Invalid invite code."
                        return
                    }
                }
                joinGroupCode = ""
                statusMessage = "Joined group."
                AnalyticsService.logGroupJoined()
                await refreshAsync()
            } catch {
                errorMessage = "Join failed: \(error.localizedDescription)"
                AppErrorLogger.log(
                    severity: .error,
                    message: error.localizedDescription,
                    screen: "friends",
                    extra: ["phase": .string("join_group")]
                )
            }
        }
    }

    func displayName(for id: UUID) -> String {
        if let p = leaderboard.first(where: { $0.profile.id == id })?.profile {
            return p.displayName
        }
        return nameCache[id]
            ?? repository.profile(userId: id)?.displayName
            ?? "Player"
    }

    private var nameCache: [UUID: String] = [:]

    func selectFriend(_ profile: Profile) {
        selectedFriend = profile
        loadFriendDetail(profile)
    }

    func loadFriendDetail(_ profile: Profile) {
        // Play slips are still local/own-only in RLS — show own device cache if present.
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

    // MARK: - Private refresh

    private func refreshLocal(userId: UUID) {
        incomingRequests = repository.incomingFriendRequests(for: userId)
        outgoingRequests = repository.outgoingFriendRequests(for: userId)
        leaderboard = repository.friendLeaderboardRows(for: userId)
        groups = repository.groupsForUser(userId)
        seasonLeaderboard = []
        allTimeLeaderboard = []
        Task { await runSearchAsync() }
    }

    private func refreshCloud(userId: UUID) async {
        isBusy = true
        defer { isBusy = false }

        // Friend code is the critical share surface — fetch it first and keep it even if
        // later social calls fail.
        do {
            if let me = try await JuicdSocialService.fetchProfile(userId: userId) {
                friendCode = me.friend_code
                nameCache[userId] = me.display_name
            }
        } catch {
            errorMessage = "Could not load friend code: \(error.localizedDescription)"
        }

        if let local = repository.profile(userId: userId) {
            await JuicdSocialService.syncLocalStats(local)
        }

        do {
            let incoming = try await JuicdSocialService.listIncomingRequests(userId: userId)
            let outgoing = try await JuicdSocialService.listOutgoingRequests(userId: userId)
            incomingRequests = incoming.map { $0.asFriendRequest() }
            outgoingRequests = outgoing.map { $0.asFriendRequest() }

            var ids = Set(incoming.map(\.from_id) + outgoing.map(\.to_id))
            ids.insert(userId)
            if let rows = try? await JuicdSocialService.fetchProfiles(ids: Array(ids)) {
                for row in rows { nameCache[row.id] = row.display_name }
            }

            leaderboard = (try? await JuicdSocialService.friendLeaderboard(userId: userId)) ?? []
            let remoteGroups = (try? await JuicdSocialService.myGroups()) ?? []
            groups = remoteGroups.map { $0.asGroup() }
            seasonLeaderboard = (try? await JuicdSocialService.seasonLeaderboard(limit: 40)) ?? []
            allTimeLeaderboard = (try? await JuicdSocialService.allTimeLeaderboard(limit: 40)) ?? []
            await runSearchAsync()
        } catch {
            errorMessage = "Social sync failed: \(error.localizedDescription)"
            AppErrorLogger.log(
                severity: .error,
                message: error.localizedDescription,
                screen: "friends",
                extra: ["phase": .string("social_sync")]
            )
            // Keep any friendCode already loaded; only fill empty local lists as fallback.
            if incomingRequests.isEmpty && groups.isEmpty {
                refreshLocal(userId: userId)
            }
        }
    }
}
