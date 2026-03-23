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
    @State private var selectedTab = 0

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
        VStack(spacing: 0) {
            ZStack {
                PlayView(viewModel: playVM)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                DashboardView(viewModel: dashboardVM)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                TourneyView(viewModel: tourneyVM)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
                FriendsView(viewModel: friendsVM)
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)
                ProfileView(viewModel: profileVM)
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            JuicdCustomTabBar(selectedTab: $selectedTab)
        }
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

// MARK: - Custom tab bar (opaque strip — no system “liquid glass” bubble)

private struct JuicdCustomTabBar: View {
    @Binding var selectedTab: Int

    private struct Item {
        let icon: String
        let title: String
        let tag: Int
    }

    private let items: [Item] = [
        Item(icon: "sportscourt.fill", title: "Play", tag: 0),
        Item(icon: "rectangle.grid.2x2.fill", title: "Dashboard", tag: 1),
        Item(icon: "trophy.fill", title: "Tourney", tag: 2),
        Item(icon: "person.2.fill", title: "Friends", tag: 3),
        Item(icon: "person.crop.circle.fill", title: "Profile", tag: 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [JuicdTheme.strokeHighlight.opacity(0.5), JuicdTheme.strokeSubtle],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(items, id: \.tag) { item in
                    tabButton(icon: item.icon, title: item.title, tag: item.tag)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? JuicdTheme.brand : JuicdTheme.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
