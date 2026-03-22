import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showRankingsHelp = false

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Dashboard",
                    subtitle: "Your daily balance, season tier, and how you stack up.",
                    centered: true,
                    kicker: "Overview"
                )

                if let profile = viewModel.profile {
                    Card(title: "Daily balance", systemImage: "bolt.fill", style: .hero) {
                        VStack(spacing: 16) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(profile.availableDailyPoints)")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, JuicdTheme.brand],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Text("pts")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            Text("Resets with your daily allowance — spend them on picks in Play.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Card(title: "Season tier", systemImage: "trophy.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Current rank")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(JuicdTheme.textTertiary)
                                        .textCase(.uppercase)
                                        .tracking(0.8)
                                    Text(profile.currentTier.displayName)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [JuicdTheme.brand, JuicdTheme.brand2],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                                Spacer()
                                tierBadge(for: profile.currentTier)
                            }

                            Text("Season points won: \(profile.seasonPointsWon)")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ProgressView(value: Double(profile.seasonPointsWon), total: 4000)
                                .tint(JuicdTheme.brand)
                                .scaleEffect(x: 1, y: 1.4, anchor: .center)
                        }
                    }

                    rankingsCard(profile: profile)

                    Card(title: "Groups", systemImage: "person.3.fill") {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(JuicdTheme.brand)
                            HStack(spacing: 0) {
                                Text("You’re in \(viewModel.userGroupsCount) group(s). Open the ")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                Text("Groups")
                                    .fontWeight(.bold)
                                    .foregroundStyle(JuicdTheme.brand)
                                Text(" tab for standings.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                            .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Card(title: "Loading…", systemImage: "hourglass") {
                        Text("Loading profile.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
        .sheet(isPresented: $showRankingsHelp) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How rankings work")
                        .font(.title2.bold())
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text("Tiers are based on season points won — from picks, weekly tournaments, and bonuses. Bigger parlays and deeper tournament runs earn more. In production you’d reset seasons and lock badges.")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.body)
                        .lineSpacing(4)
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showRankingsHelp = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func tierBadge(for tier: RankTier) -> some View {
        let symbol: String = {
            switch tier {
            case .bronze: return "shield.fill"
            case .silver: return "star.fill"
            case .gold: return "crown.fill"
            case .platinum: return "diamond.fill"
            case .emerald: return "leaf.fill"
            case .diamond: return "sparkles"
            case .challenger: return "flame.fill"
            case .champion: return "trophy.fill"
            }
        }()
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [JuicdTheme.brand.opacity(0.35), JuicdTheme.brand2.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(JuicdTheme.brand)
        }
    }

    @ViewBuilder
    private func rankingsCard(profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(JuicdTheme.brand.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JuicdTheme.brand)
                }
                Text("Rank ladder")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Spacer()
                Button {
                    showRankingsHelp = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(JuicdTheme.brand.opacity(0.9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How rankings work")
            }
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.tierRules.enumerated()), id: \.element.id) { index, rule in
                    let isCurrent = rule.tier == profile.currentTier
                    if index > 0 {
                        Divider()
                            .overlay(JuicdTheme.strokeSubtle)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.tier.displayName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(isCurrent ? JuicdTheme.brand : JuicdTheme.textPrimary)
                            Text("From \(rule.minPointsWonInclusive) pts won")
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        if rule.tier == .challenger || rule.tier == .champion {
                            Text(rule.tier == .champion ? "Elite" : "Top")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.35))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 1, green: 0.75, blue: 0.2).opacity(0.15))
                                )
                        }
                        if isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(JuicdTheme.brand)
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.vertical, 12)
                    .background(
                        isCurrent
                            ? JuicdTheme.brand.opacity(0.06)
                            : Color.clear
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [JuicdTheme.cardElevated, JuicdTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [JuicdTheme.strokeHighlight, JuicdTheme.strokeSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}
