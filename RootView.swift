import SwiftUI

struct RootView: View {
    @ObservedObject var repository: InMemoryJuicdRepository

    @StateObject private var authVM: AuthViewModel
    @StateObject private var playVM: PlayViewModel
    @StateObject private var dashboardVM: DashboardViewModel
    @StateObject private var tourneyVM: TourneyViewModel
    @StateObject private var groupsVM: GroupsViewModel
    @StateObject private var profileVM: ProfileViewModel

    init(repository: InMemoryJuicdRepository) {
        self.repository = repository
        _authVM = StateObject(wrappedValue: AuthViewModel(repository: repository))
        _playVM = StateObject(wrappedValue: PlayViewModel(repository: repository))
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(repository: repository))
        _tourneyVM = StateObject(wrappedValue: TourneyViewModel(repository: repository))
        _groupsVM = StateObject(wrappedValue: GroupsViewModel(repository: repository))
        _profileVM = StateObject(wrappedValue: ProfileViewModel(repository: repository))
    }

    var body: some View {
        SwiftUI.Group {
            if let userId = authVM.profile?.id {
                TabView {
                    PlayView(viewModel: playVM)
                        .tabItem { Label("Play", systemImage: "sportscourt.fill") }

                    DashboardView(viewModel: dashboardVM)
                        .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2.fill") }

                    TourneyView(viewModel: tourneyVM)
                        .tabItem { Label("Tourney", systemImage: "calendar.badge.clock") }

                    GroupsView(viewModel: groupsVM)
                        .tabItem { Label("Groups", systemImage: "person.3.fill") }

                    ProfileView(viewModel: profileVM)
                        .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                }
                .tint(JuicdTheme.brand)
                .toolbarBackground(JuicdTheme.slateBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .onAppear {
                    playVM.configure(userId: userId)
                    dashboardVM.configure(userId: userId)
                    tourneyVM.configure(userId: userId)
                    groupsVM.configure(userId: userId)
                    profileVM.configure(userId: userId)
                }
                .onChange(of: userId) { _, newValue in
                    playVM.configure(userId: newValue)
                    dashboardVM.configure(userId: newValue)
                    tourneyVM.configure(userId: newValue)
                    groupsVM.configure(userId: newValue)
                    profileVM.configure(userId: newValue)
                }
            } else {
                SignInView(viewModel: authVM)
            }
        }
    }
}
