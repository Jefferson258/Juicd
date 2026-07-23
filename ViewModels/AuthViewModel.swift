import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var authError: String?
    @Published var isBusy = false
    /// Shareable 6-char code from Supabase (shown on Friends tab).
    @Published var friendCode: String?

    private let repository: InMemoryJuicdRepository

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        Task { await restoreIfPossible() }
    }

    /// Completes sign-in with Apple display name (or typed name) via Supabase anonymous auth.
    func completeSignIn(displayName: String) {
        Task { await signInOnline(displayName: displayName, method: "apple") }
    }

    /// Prototype shortcut — still creates a cloud session so friends/groups work.
    func signInDevBypass() {
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

    // MARK: - Private

    private func restoreIfPossible() async {
        guard SupabaseConfig.isConfigured else { return }
        guard let session = await SupabaseAuthService.restoreSession() else { return }
        await finishWithSession(session, displayName: nil)
    }

    private func signInOnline(displayName: String, method: String) async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

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
            let session = try await SupabaseAuthService.signInAnonymously(displayName: name)
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
        profile = repository.profile(userId: created.id)
        friendCode = code
        if let p = profile {
            await JuicdSocialService.syncLocalStats(p)
            if friendCode == nil, let again = try? await JuicdSocialService.fetchProfile(userId: p.id) {
                friendCode = again.friend_code
            }
        }
    }
}
