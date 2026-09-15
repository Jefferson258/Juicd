import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var authError: String?
    @Published var isBusy = false
    /// True while cold-start Keychain restore (or UITest launch-arg sign-in) is in flight.
    @Published var isRestoring = true
    /// Shareable 6-char code from Supabase (shown on Friends tab).
    @Published var friendCode: String?

    private let repository: InMemoryJuicdRepository

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        Task { await restoreIfPossible() }
    }

    /// Completes Sign in with Apple. Sets `isBusy` before any async work so RootView
    /// never flashes LoggedInTabShell ahead of the Apple sheet / profile finish.
    func completeSignIn(displayName: String, appleUserId: String? = nil) {
        authError = nil
        isBusy = true
        Task {
            await signInOnline(displayName: displayName, method: "apple", appleUserId: appleUserId)
        }
    }

    /// UITests / automation only — not shown in production UI.
    /// Invoked solely via `-juicd-dev-signin` ProcessInfo launch argument.
    func signInDevBypass() {
        guard ProcessInfo.processInfo.arguments.contains("-juicd-dev-signin") else { return }
        authError = nil
        isBusy = true
        Task { await signInOnline(displayName: "Player", method: "continue_as_player") }
    }

    func refreshDailyPoints() {
        guard let profile else { return }
        repository.resolveDailyRankOutcomes(userId: profile.id, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: profile.id, date: .now)
        self.profile = repository.profile(userId: profile.id)
        if let p = self.profile {
            Task { await JuicdSocialService.syncLocalStats(p) }
        }
    }

    func signOut() {
        SupabaseAuthService.signOut()
        profile = nil
        friendCode = nil
        AnalyticsService.logSignOut()
    }

    /// Permanently deletes the server-backed account. Offline/local prototype
    /// profiles are not silently treated as deleted because they have no
    /// backend deletion semantics.
    func deleteAccount() async throws {
        guard SupabaseConfig.isConfigured else {
            throw NSError(
                domain: "JuicdAccountDeletion",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Account deletion is unavailable until Juicd’s backend is configured."]
            )
        }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let deletingUserId = SupabaseAuthService.currentSession?.userId ?? profile?.id
        try await SupabaseAuthService.deleteAccount()
        if let deletingUserId {
            repository.clearUserData(userId: deletingUserId)
        }
        profile = nil
        friendCode = nil
    }

    // MARK: - Private

    private func restoreIfPossible() async {
        defer { isRestoring = false }

        if ProcessInfo.processInfo.arguments.contains("-juicd-dev-signin") {
            let demoId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
            if ProcessInfo.processInfo.arguments.contains("-seedDemoData"),
               let seeded = repository.profile(userId: demoId) {
                profile = seeded
                return
            }
            isBusy = true
            defer { isBusy = false }
            await signInOnline(displayName: "Player", method: "dev_launch_arg")
            return
        }

        guard SupabaseConfig.isConfigured else { return }
        guard let session = await SupabaseAuthService.restoreSession() else { return }
        await finishWithSession(session, displayName: nil)
    }

    private func signInOnline(displayName: String, method: String, appleUserId: String? = nil) async {
        // completeSignIn / signInDevBypass may already have set isBusy.
        if !isBusy { isBusy = true }
        defer { isBusy = false }
        authError = nil

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Player" : trimmed

        guard SupabaseConfig.isConfigured else {
            // Offline fallback (UITests / no keys).
            let created = repository.signIn(displayName: name)
            repository.resolveDailyRankOutcomes(userId: created.id, now: .now)
            _ = repository.awardDailyPointsIfNeeded(userId: created.id, date: .now)
            profile = repository.profile(userId: created.id)
            AnalyticsService.logSignIn(method: method)
            return
        }

        do {
            let session = try await SupabaseAuthService.signInAnonymously(
                displayName: name,
                appleUserId: appleUserId
            )
            // Publish profile only after the full session + local profile finish.
            await finishWithSession(session, displayName: name)
            AnalyticsService.logSignIn(method: method)
        } catch {
            authError = "Cloud sign-in failed: \(error.localizedDescription)"
            AppErrorLogger.log(
                severity: .error,
                message: error.localizedDescription,
                screen: "auth",
                extra: ["phase": .string("cloud_sign_in"), "method": .string(method)]
            )
        }
    }

    private func finishWithSession(_ session: SupabaseSession, displayName: String?) async {
        var remoteName = displayName
        var code: String?
        if let remote = try? await JuicdSocialService.fetchProfile(userId: session.userId) {
            remoteName = remoteName ?? remote.display_name
            code = remote.friend_code
        }

        let name = (remoteName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Player"
        let created = repository.signIn(displayName: name, preferredId: session.userId)
        repository.resolveDailyRankOutcomes(userId: created.id, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: created.id, date: .now)
        // Set profile last so RootView only enters LoggedInTabShell when ready.
        friendCode = code
        profile = repository.profile(userId: created.id)
        if let p = profile {
            await JuicdSocialService.syncLocalStats(p)
            if friendCode == nil, let again = try? await JuicdSocialService.fetchProfile(userId: p.id) {
                friendCode = again.friend_code
            }
        }
    }
}
