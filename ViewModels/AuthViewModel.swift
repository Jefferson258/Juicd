import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var authError: String?

    private let repository: InMemoryJuicdRepository

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    /// Completes sign-in with a resolved display name (Sign in with Apple or dev bypass).
    func completeSignIn(displayName: String) {
        authError = nil
        let created = repository.signIn(displayName: displayName)
        repository.resolveDailyRankOutcomes(userId: created.id, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: created.id, date: .now)
        profile = repository.profile(userId: created.id)
    }

    /// Prototype: same local “Player” profile each launch (repository matches by display name).
    func signInDevBypass() {
        completeSignIn(displayName: "Player")
    }

    func refreshDailyPoints() {
        guard let profile else { return }
        repository.resolveDailyRankOutcomes(userId: profile.id, now: .now)
        _ = repository.awardDailyPointsIfNeeded(userId: profile.id, date: .now)
        self.profile = repository.profile(userId: profile.id)
    }

    func signOut() {
        profile = nil
    }
}
