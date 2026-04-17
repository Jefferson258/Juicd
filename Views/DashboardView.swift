import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showRankingsHelp = false
    @State private var showDashboardTips = false

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 24) {
                JuicdTabScreenAccent()
                BrandHeader(
                    title: "Dashboard",
                    subtitle: "Daily points, rank, and where you stand.",
                    centered: true,
                    kicker: "Overview"
                )
                HStack {
                    Spacer()
                    Button {
                        showDashboardTips = true
                    } label: {
                        Label("Quick help", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(JuicdTheme.brand)
                }

                if let profile = viewModel.profile {
                    todaysEntriesSection

                    lastRankedMatchCard(profile: profile)

                    Card(title: "Daily balance", systemImage: "bolt.fill", style: .hero) {
                        VStack(spacing: 16) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(profile.availableDailyPoints)")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Text("pts")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            Text("Your balance resets to \(JuicdBalance.dailyPlayAllowancePoints) each new slate. Refill points are not season score.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Card(title: "Rank tier", systemImage: "trophy.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Current tier")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(JuicdTheme.textTertiary)
                                        .textCase(.uppercase)
                                        .tracking(0.8)
                                    Text(profile.currentTier.displayName)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(JuicdTheme.textPrimary)
                                }
                                Spacer()
                                tierBadge(for: profile.currentTier)
                            }

                            Text("Tier comes from your MMR, based on daily ranked results.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 13, weight: .medium))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider().overlay(JuicdTheme.strokeSubtle)

                            Text("Season score")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(profile.seasonPointsWon) pts from wins and bonuses.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ProgressView(value: Double(min(profile.seasonPointsWon, 4000)), total: 4000)
                                .tint(JuicdTheme.brand)
                                .scaleEffect(x: 1, y: 1.4, anchor: .center)
                        }
                    }

                    rankingsCard(profile: profile)
                    mmrCalculationCard
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
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showRankingsHelp) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How rank & score work")
                        .font(.title2.bold())
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text(
                        """
                        Daily points reset to 100 each slate. Refill points are not season score.

                        Season score only includes points from wins and bonuses.

                        Ranked play: each day you bet, you enter a 10-player group. Top 5 gain MMR; bottom 5 lose MMR.

                        If you spend fewer than 100 points, your result is scaled to a 100-point baseline for fair ranking.

                        MMR updates use a moving average, so one day does not over-swing your rank.
                        """
                    )
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
        .sheet(isPresented: $showDashboardTips) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dashboard tips")
                        .font(.title3.bold())
                    Text("• Daily points reset to 100 each slate.")
                    Text("• Rank/MMR is based on Play bets only.")
                    Text("• Daily groups are 10 players: top 5 gain, bottom 5 lose.")
                    Text("• MMR movement is smoothed with a moving average.")
                    Text("• Tier distribution is bell-curved around Platinum.")
                    Spacer()
                }
                .foregroundStyle(JuicdTheme.textSecondary)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showDashboardTips = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var todaysEntriesSection: some View {
        Card(title: "Today’s entries", systemImage: "list.bullet.clipboard.fill", style: .hero) {
            if viewModel.todaysEntries.isEmpty {
                Text("No slips yet on today’s slate. Place picks on the Play tab — they’ll show here with stake, combined odds, and season points.")
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.todaysEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(JuicdTheme.strokeSubtle).padding(.vertical, 8)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.legSummaries.count <= 1 ? "Single" : "Parlay ×\(entry.legSummaries.count)")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                                Spacer()
                                Text(entry.didWin ? "Won" : "Missed")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(entry.didWin ? Color(red: 0.35, green: 0.95, blue: 0.55) : JuicdTheme.textTertiary)
                            }
                            Text("Stake \(entry.stakePoints) pts · Combined \(String(format: "%.2f", entry.combinedOdds))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JuicdTheme.textPrimary)
                            Text(entry.legSummaries.joined(separator: " · "))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .lineLimit(3)
                            if entry.didWin {
                                Text("+\(entry.seasonPointsEarned) season pts")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JuicdTheme.brand)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lastRankedMatchCard(profile: Profile) -> some View {
        let snapshot = profile.lastDailyMatch ?? DailyMatchSnapshot.devPreview
        let isSample = profile.lastDailyMatch == nil

        Card(title: "Last ranked match", systemImage: "chart.line.uptrend.xyaxis", style: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                if isSample {
                    Text("Sample preview")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(JuicdTheme.brand)
                }
                Text(formattedRankPoolDay(snapshot.dayISO))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JuicdTheme.textTertiary)
                Text("Placement \(snapshot.placement) / \(snapshot.poolSize)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)
                if snapshot.tierBefore != snapshot.tierAfter {
                    Text("Tier \(snapshot.tierBefore.displayName) → \(snapshot.tierAfter.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                } else {
                    Text("Tier unchanged at \(snapshot.tierAfter.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                }
                if isSample {
                    Text("Your real result appears after the slate resolves.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }
            }
        }
    }

    private func formattedRankPoolDay(_ iso: String) -> String {
        let inDF = DateFormatter()
        inDF.calendar = Calendar.current
        inDF.timeZone = TimeZone.current
        inDF.dateFormat = "yyyy-MM-dd"
        guard let d = inDF.date(from: iso) else { return "Pool day \(iso)" }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: d)
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
                ForEach(Array(viewModel.rankLadder.enumerated()), id: \.offset) { index, tier in
                    let isCurrent = tier == profile.currentTier
                    if index > 0 {
                        Divider()
                            .overlay(JuicdTheme.strokeSubtle)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tier.displayName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(isCurrent ? JuicdTheme.brand : JuicdTheme.textPrimary)
                            Text("Based on MMR")
                                .foregroundStyle(JuicdTheme.textTertiary)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        if tier == .challenger || tier == .champion {
                            Text(tier == .champion ? "Elite" : "Top")
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

    private var mmrCalculationCard: some View {
        Card(title: "MMR each day", systemImage: "function", style: .hero) {
            VStack(alignment: .leading, spacing: 8) {
                Text("1) Grouping")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Text("You are matched into a daily group of 10 similar players.")
                    .font(.caption)
                    .foregroundStyle(JuicdTheme.textSecondary)

                Text("2) Fair scaling")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Text("Your daily net is scaled to a 100-point baseline, so spending fewer points does not punish rank quality.")
                    .font(.caption)
                    .foregroundStyle(JuicdTheme.textSecondary)

                Text("3) Placement")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Text("Top 5 gain MMR. Bottom 5 lose MMR. #1 gains the most, #10 loses the most.")
                    .font(.caption)
                    .foregroundStyle(JuicdTheme.textSecondary)

                Text("4) Moving average")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Text("Daily changes are smoothed with a moving average to keep rank movement stable.")
                    .font(.caption)
                    .foregroundStyle(JuicdTheme.textSecondary)

                Text("5) Bell-curve tiers")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                Text("Tier cutoffs follow a bell curve centered near Platinum, with fewer players in farther tiers.")
                    .font(.caption)
                    .foregroundStyle(JuicdTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
