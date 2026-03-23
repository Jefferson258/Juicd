import SwiftUI

struct RootView: View {
    @ObservedObject var repository: InMemoryJuicdRepository

    /// Only the auth VM loads on cold start so the sign-in screen (and display name field) isn’t competing with Play/Dashboard/etc.
    @StateObject private var authVM: AuthViewModel

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        _authVM = StateObject(wrappedValue: AuthViewModel(repository: repository))
    }

    @ViewBuilder
    var body: some View {
        if let userId = authVM.profile?.id {
            LoggedInTabShell(repository: repository, userId: userId)
        } else {
            SignInView(viewModel: authVM)
        }
    }
}

// MARK: - Post–sign-in shell (heavy view models created only after auth)

private struct LoggedInTabShell: View {
    @ObservedObject var repository: InMemoryJuicdRepository
    let userId: UUID

    @StateObject private var playVM: PlayViewModel
    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var tourneyVM: TourneyViewModel
    @StateObject private var friendsVM: FriendsViewModel
    @StateObject private var profileVM: ProfileViewModel

    @AppStorage("juicd_tutorial_completed") private var tutorialCompleted = false
    @State private var showTutorial = false

    init(repository: InMemoryJuicdRepository, userId: UUID) {
        self.repository = repository
        self.userId = userId
        _playVM = StateObject(wrappedValue: PlayViewModel(repository: repository))
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(repository: repository))
        _tourneyVM = StateObject(wrappedValue: TourneyViewModel(repository: repository))
        _friendsVM = StateObject(wrappedValue: FriendsViewModel(repository: repository))
        _profileVM = StateObject(wrappedValue: ProfileViewModel(repository: repository))
    }

    var body: some View {
        TabView {
            Tab("Play", systemImage: "sportscourt.fill") {
                PlayView(viewModel: playVM)
            }
            Tab("Dashboard", systemImage: "rectangle.grid.2x2.fill") {
                DashboardView(viewModel: dashboardVM)
            }
            Tab("Tourney", systemImage: "trophy.fill") {
                TourneyView(viewModel: tourneyVM)
            }
            Tab("Friends", systemImage: "person.2.fill") {
                FriendsView(viewModel: friendsVM)
            }
            Tab("Profile", systemImage: "person.crop.circle.fill") {
                ProfileView(viewModel: profileVM)
            }
        }
        .tabBarMinimizeBehavior(.never)
        .tint(JuicdTheme.brand)
        .background(JuicdTheme.canvasDeep.ignoresSafeArea())
        .onAppear {
            configureAll(userId: userId)
            if !tutorialCompleted {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView {
                tutorialCompleted = true
                showTutorial = false
            }
        }
    }

    private func configureAll(userId: UUID) {
        playVM.configure(userId: userId)
        dashboardVM.configure(userId: userId)
        tourneyVM.configure(userId: userId)
        friendsVM.configure(userId: userId)
        profileVM.configure(userId: userId)
    }
}
