import SwiftUI
import UserNotifications

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    @AppStorage("juicd_notify_daily_updates") private var notifyDailyUpdates = false
    @AppStorage("juicd_notify_tournament_updates") private var notifyTournamentUpdates = false
    @AppStorage("juicd_notify_seasonal_updates") private var notifySeasonalUpdates = false

    @State private var showRankingDetails = false
    @State private var showSeasonInfo = false

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
                    subtitle: "Your season footprint and badge shelf.",
                    centered: true,
                    kicker: "You"
                )

                if let profile = viewModel.profile {
                    Card(title: "Season record (\(JuicdSeason.shortLabel(for: seasonKey)))", systemImage: "calendar") {
                        VStack(spacing: 10) {
                            HStack {
                                Text("3-month quarter · your local calendar")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                                Spacer()
                                Button {
                                    showSeasonInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(JuicdTheme.brand)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("About seasons")
                            }
                            bettingRecordBlock(stats: season, seasonScopedFootnote: true)
                        }
                    }

                    Card(title: "Career record", systemImage: "chart.line.uptrend.xyaxis") {
                        VStack(spacing: 10) {
                            bettingRecordBlock(stats: career, seasonScopedFootnote: false)
                        }
                    }

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
    }

    @ViewBuilder
    private func bettingRecordBlock(stats: CareerBettingStats, seasonScopedFootnote: Bool) -> some View {
        HStack {
            Text("Overall W–L")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(JuicdTheme.textSecondary)
            Spacer()
            Text("\(stats.totalWins)–\(stats.totalLosses)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
        }
        Divider().overlay(JuicdTheme.strokeSubtle)
        statRow(label: "Play parlays", value: "\(stats.playWins)–\(stats.playLosses)")
        statRow(label: "Ranked daily (quarters)", value: "\(stats.rankedDailyWins)–\(stats.rankedDailyLosses)")
        statRow(label: "Daily bracket rounds", value: "\(stats.closestRoundWins)–\(stats.closestRoundLosses)")
        statRow(label: "Total points staked", value: "\(stats.totalPointsStaked)")
        statRow(label: "Returned from bets", value: "\(stats.totalPointsWonBack)")
        statRow(label: "Daily bracket wins (full run)", value: "\(stats.dailyBracketTournamentWins)")
        Text(
            seasonScopedFootnote
                ? "Season rows only count slips and ledger entries that fall in \(JuicdSeason.shortLabel(for: seasonKey)) (local calendar quarter)."
                : "Career totals include all time. Returned from bets sums payouts and daily bracket rewards from the ledger."
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(JuicdTheme.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
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
