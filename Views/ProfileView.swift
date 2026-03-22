import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Profile",
                    subtitle: "Season stats & badge gallery.",
                    centered: true
                )

                if let profile = viewModel.profile {
                    Card(title: profile.displayName, systemImage: "person.crop.circle.fill") {
                        VStack(spacing: 8) {
                            Text(profile.currentTier.displayName)
                                .font(.title2.bold())
                                .foregroundStyle(JuicdTheme.brand)
                            Text("Season pts won: \(profile.seasonPointsWon)")
                                .foregroundStyle(JuicdTheme.textSecondary)
                            Text("All-time pts won: \(profile.allTimePointsWon)")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Card(title: "Badges", systemImage: "star.circle.fill") {
                        if viewModel.badges.isEmpty {
                            Text("Win tourneys and seasons to earn badges.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.subheadline)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(viewModel.badges, id: \.id) { badge in
                                    VStack(spacing: 8) {
                                        Image(systemName: badge.imageSystemName)
                                            .font(.system(size: 32))
                                            .foregroundStyle(JuicdTheme.brand)
                                        Text(badge.title)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(JuicdTheme.textPrimary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(JuicdTheme.slateBackground.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }

                    Card(title: "Dev tools", systemImage: "hammer.fill") {
                        VStack(spacing: 10) {
                            Button("Simulate season-end badge") {
                                viewModel.simulateSeasonEndAward()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(JuicdTheme.brand)

                            Button("Reset season (prototype)", role: .destructive) {
                                viewModel.resetSeason()
                            }
                        }
                    }
                } else {
                    Card(title: "Loading…", systemImage: "hourglass") {
                        Text("…")
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea())
    }
}
