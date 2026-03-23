import SwiftUI

struct RootView: View {
    @ObservedObject var repository: InMemoryJuicdRepository

    @StateObject private var authVM: AuthViewModel
    @StateObject private var playVM: PlayViewModel
    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var tourneyVM: TourneyViewModel
    @StateObject private var friendsVM: FriendsViewModel
    @StateObject private var profileVM: ProfileViewModel

    @AppStorage("juicd_tutorial_completed") private var tutorialCompleted = false
    @State private var showTutorial = false

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        _authVM = StateObject(wrappedValue: AuthViewModel(repository: repository))
        _playVM = StateObject(wrappedValue: PlayViewModel(repository: repository))
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(repository: repository))
        _tourneyVM = StateObject(wrappedValue: TourneyViewModel(repository: repository))
        _friendsVM = StateObject(wrappedValue: FriendsViewModel(repository: repository))
        _profileVM = StateObject(wrappedValue: ProfileViewModel(repository: repository))
    }

    var body: some View {
        SwiftUI.Group {
            if let userId = authVM.profile?.id {
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
                    playVM.configure(userId: userId)
                    dashboardVM.configure(userId: userId)
                    tourneyVM.configure(userId: userId)
                    friendsVM.configure(userId: userId)
                    profileVM.configure(userId: userId)
                    if !tutorialCompleted {
                        showTutorial = true
                    }
                }
                .onChange(of: userId) { _, newValue in
                    playVM.configure(userId: newValue)
                    dashboardVM.configure(userId: newValue)
                    tourneyVM.configure(userId: newValue)
                    friendsVM.configure(userId: newValue)
                    profileVM.configure(userId: newValue)
                }
                .fullScreenCover(isPresented: $showTutorial) {
                    TutorialView {
                        tutorialCompleted = true
                        showTutorial = false
                    }
                }
            } else {
                SignInView(viewModel: authVM)
            }
        }
    }
}
