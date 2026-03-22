import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 14)]

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Profile",
                    subtitle: "Your season footprint and badge shelf.",
                    centered: true,
                    kicker: "You"
                )

                if let profile = viewModel.profile {
                    Card(title: profile.displayName, systemImage: "person.crop.circle.fill", style: .hero) {
                        VStack(spacing: 12) {
                            Text(profile.currentTier.displayName)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [JuicdTheme.brand, JuicdTheme.brand2],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            VStack(spacing: 6) {
                                statRow(label: "Season pts won", value: "\(profile.seasonPointsWon)")
                                statRow(label: "All-time pts won", value: "\(profile.allTimePointsWon)")
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Card(title: "Badges", systemImage: "star.circle.fill") {
                        if viewModel.badges.isEmpty {
                            Text("Win tourneys and seasons to earn badges.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(viewModel.badges, id: \.id) { badge in
                                    VStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(JuicdTheme.card)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                                                )
                                            Image(systemName: badge.imageSystemName)
                                                .font(.system(size: 28, weight: .semibold))
                                                .foregroundStyle(JuicdTheme.brand)
                                        }
                                        .frame(height: 72)
                                        Text(badge.title)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(JuicdTheme.textPrimary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(JuicdTheme.canvasDeep.opacity(0.6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    Card(title: "Prototype tools", systemImage: "hammer.fill") {
                        VStack(spacing: 12) {
                            Button("Simulate season-end badge") {
                                viewModel.simulateSeasonEndAward()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(JuicdTheme.brand)
                            .frame(maxWidth: .infinity)

                            Button("Reset season", role: .destructive) {
                                viewModel.resetSeason()
                            }
                            .font(.system(size: 15, weight: .semibold))
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
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(JuicdTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
        }
    }
}
