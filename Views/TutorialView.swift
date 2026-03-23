import SwiftUI

struct TutorialView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [(String, String, String)] = [
        (
            "Welcome to Juicd",
            "Short sessions for picks, daily tournaments, and season ladders. Use Next to preview what each tab is for.",
            "sparkles"
        ),
        (
            "Play",
            "Build parlays from today’s board with your daily point allowance. A couple of lines may show a Juicd boost — same pick, better price. One parlay stake per slate.",
            "sportscourt.fill"
        ),
        (
            "Dashboard",
            "See today’s slips, wins and misses, and how your picks shook out. Your Play history shows up here first.",
            "rectangle.grid.2x2.fill"
        ),
        (
            "Tourney",
            "Enter the daily closest-pick bracket: preview four rounds, lock in before tip, and submit one pick per round.",
            "trophy.fill"
        ),
        (
            "Friends",
            "Send friend requests, accept or decline, compare ranks on the Friends Leaderboard, and open someone to see their recent Play form.",
            "person.2.fill"
        ),
        (
            "Profile",
            "Tier, career and season stats, badges, and notification settings. Season tools for testing live here too.",
            "person.crop.circle.fill"
        )
    ]

    var body: some View {
        ZStack {
            JuicdScreenBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onFinish()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack {
                            Spacer(minLength: 0)
                            VStack(spacing: 22) {
                                Image(systemName: pages[i].2)
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [JuicdTheme.brand, JuicdTheme.brand2],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text(pages[i].0)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(JuicdTheme.textPrimary)

                                Text(pages[i].1)
                                    .font(.system(size: 16, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 28)
                            }
                            Spacer(minLength: 0)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                VStack(spacing: 14) {
                    if page < pages.count - 1 {
                        Button {
                            withAnimation {
                                page += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                    } else {
                        Button {
                            onFinish()
                        } label: {
                            Text("Get started")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}
