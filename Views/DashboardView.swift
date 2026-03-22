import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showRankingsHelp = false

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Dashboard",
                    subtitle: "Points, season rank, and the full ladder.",
                    centered: true
                )

                if let profile = viewModel.profile {
                    Card(title: "Daily bankroll", systemImage: "bolt.fill") {
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(profile.availableDailyPoints)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.brand)
                                Text("points to play")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)

                            Text("You get 10 points each day to use on picks (prototype).")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 13, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Card(title: "Your season rank", systemImage: "trophy.fill") {
                        VStack(spacing: 12) {
                            Text(profile.currentTier.displayName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(JuicdTheme.brand)
                                .frame(maxWidth: .infinity)

                            Text("Season points won: \(profile.seasonPointsWon)")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 13, weight: .semibold))

                            ProgressView(value: Double(profile.seasonPointsWon), total: 4000)
                                .tint(JuicdTheme.brand)
                        }
                    }

                    rankingsCard(profile: profile)

                    Card(title: "Groups", systemImage: "person.3.fill") {
                        Text("You’re in \(viewModel.userGroupsCount) group(s). Open the Groups tab for standings.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Card(title: "Loading…", systemImage: "hourglass") {
                        Text("Loading profile.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea())
        .sheet(isPresented: $showRankingsHelp) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How rankings work")
                        .font(.title2.bold())
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text("Tiers are based on season points won — from picks, weekly tournaments, and bonuses. Bigger parlays and deeper tournament runs earn more. In production you’d reset seasons and lock badges.")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.body)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(JuicdTheme.slateBackground)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showRankingsHelp = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func rankingsCard(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(JuicdTheme.brand2)
                Text("Rankings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Spacer()
                Button {
                    showRankingsHelp = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(JuicdTheme.brand)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How rankings work")
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.tierRules) { rule in
                    let isCurrent = rule.tier == profile.currentTier
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.tier.displayName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isCurrent ? JuicdTheme.brand : JuicdTheme.textPrimary)
                            Text("From \(rule.minPointsWonInclusive) pts won")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Spacer()
                        if rule.tier == .challenger || rule.tier == .champion {
                            Text(rule.tier == .champion ? "Elite" : "Top tier")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.yellow.opacity(0.9))
                        }
                        if isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(JuicdTheme.brand)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(JuicdTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
