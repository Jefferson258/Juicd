import SwiftUI
import UserNotifications

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    @AppStorage("juicd_notify_daily_updates") private var notifyDailyUpdates = false
    @AppStorage("juicd_notify_tournament_updates") private var notifyTournamentUpdates = false
    @AppStorage("juicd_notify_seasonal_updates") private var notifySeasonalUpdates = false

    @State private var showRankingDetails = false
    @State private var showSeasonInfo = false
    @State private var showSeasonMetrics = false
    @State private var showCareerMetrics = false

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 14)]

    private var seasonKey: String { JuicdSeason.currentSeasonKey() }

    private var season: CareerBettingStats { viewModel.seasonStats ?? .zero }
    private var career: CareerBettingStats { viewModel.careerStats ?? .zero }

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 24) {
                JuicdTabScreenAccent()
                BrandHeader(
                    title: "Profile",
                    subtitle: "Season footprint, career numbers, and badges.",
                    centered: true,
                    kicker: "You"
                )

                if let profile = viewModel.profile {
                    recordHeroCard(
                        title: "Season record",
                        subtitle: "\(JuicdSeason.shortLabel(for: seasonKey)) · local quarter",
                        stats: season,
                        onTap: { showSeasonMetrics = true },
                        onSeasonInfo: { showSeasonInfo = true }
                    )

                    recordHeroCard(
                        title: "Career record",
                        subtitle: "All-time",
                        stats: career,
                        onTap: { showCareerMetrics = true },
                        onSeasonInfo: nil
                    )

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
                                statRow(label: "Season score (wins & bonuses)", value: "\(profile.seasonPointsWon)")
                                statRow(label: "All-time pts won", value: "\(profile.allTimePointsWon)")
                            }
                            .padding(.top, 4)

                            DisclosureGroup(isExpanded: $showRankingDetails) {
                                Text("Internal skill rating used to place you in ranked pools. Your tier on Dashboard is what most players should care about.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 4)
                                statRow(label: "MMR (internal)", value: "\(Int((profile.mmr ?? MMRLogic.startingMMR).rounded()))")
                            } label: {
                                Text("Ranking details (MMR)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(JuicdTheme.brand)
                            }
                            .tint(JuicdTheme.brand)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Card(title: "Notifications", systemImage: "bell.badge.fill") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose what you’d like to hear about. Turning any option on asks for notification permission once.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Toggle("Daily updates", isOn: $notifyDailyUpdates)
                                .tint(JuicdTheme.brand)
                                .onChange(of: notifyDailyUpdates) { _, on in
                                    if on { requestNotificationAuthorizationIfNeeded() }
                                }
                            Toggle("Tournament & bracket updates", isOn: $notifyTournamentUpdates)
                                .tint(JuicdTheme.brand)
                                .onChange(of: notifyTournamentUpdates) { _, on in
                                    if on { requestNotificationAuthorizationIfNeeded() }
                                }
                            Toggle("Seasonal updates", isOn: $notifySeasonalUpdates)
                                .tint(JuicdTheme.brand)
                                .onChange(of: notifySeasonalUpdates) { _, on in
                                    if on { requestNotificationAuthorizationIfNeeded() }
                                }
                        }
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

                            Button("Reset daily closest tournament (today)") {
                                viewModel.resetDailyClosestTournamentForTesting()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)

                            Button("Refill daily Play balance") {
                                viewModel.resetDailyPlayBalanceForTesting()
                            }
                            .font(.system(size: 15, weight: .semibold))
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
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showSeasonInfo) {
            SeasonInfoSheet(seasonKey: seasonKey)
        }
        .sheet(isPresented: $showSeasonMetrics) {
            BettingRecordDetailSheet(
                title: "Season metrics",
                stats: season,
                footnote: "Season rows only count slips and ledger entries in \(JuicdSeason.shortLabel(for: seasonKey)) (local calendar quarter)."
            )
        }
        .sheet(isPresented: $showCareerMetrics) {
            BettingRecordDetailSheet(
                title: "Career metrics",
                stats: career,
                footnote: "Career totals include all time. Returned from bets sums payouts and daily bracket rewards from the ledger."
            )
        }
    }

    private func recordHeroCard(
        title: String,
        subtitle: String,
        stats: CareerBettingStats,
        onTap: @escaping () -> Void,
        onSeasonInfo: (() -> Void)?
    ) -> some View {
        let outcomeDenom = stats.totalWins + stats.totalLosses
        return Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(JuicdTheme.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(JuicdTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                    if onSeasonInfo != nil {
                        Color.clear.frame(width: 28, height: 28)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }

                Text("\(stats.totalWins)–\(stats.totalLosses)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if outcomeDenom > 0 {
                    Text(String(format: "%.1f%% · all bet outcomes", stats.overallWinPct))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(stats.overallWinPct >= 50 ? JuicdTheme.trendUp : JuicdTheme.trendDown)
                } else {
                    Text("No resolved bets in this window yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }

                Text("Tap for breakdown · leg-by-leg, pools, and ledger totals")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JuicdTheme.textTertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(JuicdTheme.card)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let onSeasonInfo {
                Button {
                    onSeasonInfo()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(JuicdTheme.brand.opacity(0.9))
                        .padding(18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About seasons")
            }
        }
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

    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}

private struct BettingRecordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let stats: CareerBettingStats
    let footnote: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Parlay legs")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    detailRow(
                        label: "All parlay legs (combined)",
                        value: "\(stats.legByLegWins)–\(stats.legByLegLosses)"
                    )
                    if stats.legByLegWins + stats.legByLegLosses > 0 {
                        detailRow(
                            label: "Leg win rate",
                            value: String(format: "%.1f%%", stats.legByLegWinPct),
                            valueColor: stats.legByLegWinPct >= 50 ? JuicdTheme.trendUp : JuicdTheme.trendDown
                        )
                    }
                    detailRow(
                        label: "· Play tab (slate parlays)",
                        value: "\(stats.playLegByLegWins)–\(stats.playLegByLegLosses)"
                    )
                    detailRow(
                        label: "· Dashboard daily tournaments",
                        value: "\(stats.rankedLegByLegWins)–\(stats.rankedLegByLegLosses)"
                    )

                    Text("Bet outcomes (slips & rounds)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.top, 8)

                    detailRow(label: "Play tab slates", value: "\(stats.playWins)–\(stats.playLosses)")
                    detailRow(label: "Dashboard daily tournaments", value: "\(stats.rankedDailyWins)–\(stats.rankedDailyLosses)")
                    detailRow(label: "Daily bracket rounds", value: "\(stats.closestRoundWins)–\(stats.closestRoundLosses)")

                    Text("Ledger")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.top, 8)

                    detailRow(label: "Total points staked", value: "\(stats.totalPointsStaked)")
                    detailRow(label: "Returned from bets", value: "\(stats.totalPointsWonBack)")
                    detailRow(label: "Daily bracket wins (full run)", value: "\(stats.dailyBracketTournamentWins)")

                    Text(
                        "“Leg” here is each pick on a parlay card. The app tracks Play tab parlays and Dashboard daily tournament parlays separately (two different flows), then adds them for the combined total. The daily closest-pick bracket uses the “Daily bracket rounds” row above — those are one result per round, not stacked parlay legs."
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .lineSpacing(3)
                    .padding(.top, 4)

                    Text(footnote)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(JuicdScreenBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(label: String, value: String, valueColor: Color = JuicdTheme.textPrimary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(JuicdTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}

private struct SeasonInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let seasonKey: String

    private static let resetDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var nextQuarterStart: Date {
        JuicdSeason.nextSeasonStart(from: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What is a season?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(
                        "A season here is a 3-month calendar quarter in your device’s local timezone (Q1–Q4). The Season record card only includes picks and ledger activity dated within \(JuicdSeason.shortLabel(for: seasonKey))."
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineSpacing(4)

                    Text("When does it reset?")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .padding(.top, 8)
                    Text(
                        "Season stats roll forward at the start of the next quarter — \(Self.resetDateFormatter.string(from: nextQuarterStart)) local time (first day of the next 3-month window). Your season score on the profile card is separate and can still be reset with the prototype Reset season button for testing."
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(JuicdScreenBackground())
            .navigationTitle("Seasons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
