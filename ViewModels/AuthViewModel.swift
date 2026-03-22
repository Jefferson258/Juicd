import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var displayName: String = ""
    @Published var authError: String?

    private let repository: InMemoryJuicdRepository

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
    }

    func signIn() {
        authError = nil
        let created = repository.signIn(displayName: displayName)
        _ = repository.awardDailyPointsIfNeeded(userId: created.id, date: .now)
        repository.recalculateTier(for: created.id)
        profile = repository.profile(userId: created.id)
    }

    func refreshDailyPoints() {
        guard let profile else { return }
        _ = repository.awardDailyPointsIfNeeded(userId: profile.id, date: .now)
        self.profile = repository.profile(userId: profile.id)
    }

    func signOut() {
        profile = nil
        displayName = ""
    }
}

