import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showRankingsHelp = false
    @State private var showDashboardTips = false

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 30) {
                JuicdTabScreenAccent()
                BrandHeader(
                    title: "Dashboard",
                    subtitle: "Points, rank, progress.",
                    centered: true,
                    kicker: "Overview"
                )
                HStack(spacing: 10) {
                    compactTopIcon(systemName: "chart.bar.fill")
                    compactTopIcon(systemName: "trophy.fill")
                    compactTopIcon(systemName: "bolt.fill")
                    Button {
                        showDashboardTips = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(JuicdTheme.brand)
                }

                if let profile = viewModel.profile {
                    playSlipsSection

                    lastRankedMatchCard(profile: profile)

                    Card(title: "Daily balance", systemImage: "bolt.fill", style: .hero) {
                        VStack(spacing: 18) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(profile.availableDailyPoints)")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Text("pts")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            Text("Resets to \(JuicdBalance.dailyPlayAllowancePoints) each slate.")
                                .foregroundStyle(JuicdTheme.textSecondary)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Card(title: "Rank tier", systemImage: "trophy.fill") {
                        VStack(spacing: 18) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
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

                            Divider().overlay(JuicdTheme.strokeSubtle).padding(.vertical, 2)

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
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showRankingsHelp) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("How rank & score work")
                            .font(.title2.bold())
                            .foregroundStyle(JuicdTheme.textPrimary)

                        helpSectionTitle("Two different numbers")
                        Text("Daily balance is spendable points this slate (refills each slate — prototype uses up to 100). It is not your skill rating.\n\nSeason score only grows from wins and bonuses — it’s your long-run trophy progress on Profile.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.body)
                            .lineSpacing(5)

                        helpSectionTitle("Ranked pools (MMR)")
                        Text("When you place Play bets on a slate, you enter a simulated 10-player skill pool after that slate resolves. Placement (#1–#10) shifts MMR, which drives your tier on the ladder.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.body)
                            .lineSpacing(5)

                        helpSectionTitle("Fair staking")
                        Text("If you risk fewer points than the daily allowance, your net result is scaled to a 100-point baseline before ranking. That way cautious staking doesn’t tank your placement unfairly.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.body)
                            .lineSpacing(5)

                        helpSectionTitle("Smoothing")
                        Text("MMR uses a moving average so one lucky or unlucky slate doesn’t swing your tier wildly.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.body)
                            .lineSpacing(5)

                        helpSectionTitle("This ladder")
                        Text("The list is every tier in order. Your row shows a checkmark. Challenger/Champion sport small badges — they’re cosmetic flair on top of MMR.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.body)
                            .lineSpacing(5)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showRankingsHelp = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDashboardTips) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Dashboard guide")
                            .font(.title2.bold())
                            .foregroundStyle(JuicdTheme.textPrimary)

                        tipRow(icon: "list.bullet.clipboard.fill", text: "Play slips: pick a slate chip (Today or a past day) to review singles and parlays — stake, combined odds, result, and season points earned.")
                        tipRow(icon: "chart.line.uptrend.xyaxis", text: "Last ranked match summarizes how you placed in the prior slate’s 10-player pool once results apply.")
                        tipRow(icon: "bolt.fill", text: "Daily balance refills each slate; spending it doesn’t directly move tier — ranked outcomes from Play do.")
                        tipRow(icon: "trophy.fill", text: "Rank tier card shows your current band; open Ranking help (?) on Rank ladder for the full MMR story.")
                        tipRow(icon: "function", text: "MMR each day breaks down grouping, scaling, placement, smoothing, and tier curves in plain language.")
                    }
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showDashboardTips = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var playSlipsSection: some View {
        Card(title: "Play slips", systemImage: "list.bullet.clipboard.fill", style: .hero) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Singles and parlays by slate day (resets at 6:00 local).")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineSpacing(3)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.playSlatePickerKeys, id: \.self) { key in
                            let isSelected = viewModel.selectedPlaySlateKey == key
                            Button {
                                viewModel.selectPlaySlate(key)
                            } label: {
                                Text(slateChipLabel(key))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? JuicdTheme.textPrimary : JuicdTheme.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(isSelected ? JuicdTheme.brand.opacity(0.28) : JuicdTheme.cardElevated)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(isSelected ? Color.white.opacity(0.45) : JuicdTheme.strokeSubtle, lineWidth: isSelected ? 1.5 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if viewModel.playSlipsForSelectedSlate.isEmpty {
                    Text(emptyPlaySlipsCopy)
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.system(size: 14, weight: .medium))
                        .lineSpacing(3)
                } else {
                    playSlipRows
                }
            }
        }
    }

    private var emptyPlaySlipsCopy: String {
        let today = SlateDay.slateKey()
        if viewModel.selectedPlaySlateKey == today {
            return "No slips on today’s slate yet. Place picks on the Play tab — they’ll show here with stake, combined odds, and season points."
        }
        return "No slips on this slate. Pick another day above, or place new picks on Play."
    }

    private var playSlipRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.playSlipsForSelectedSlate.enumerated()), id: \.element.id) { index, entry in
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

    private func slateChipLabel(_ slateKey: String) -> String {
        let today = SlateDay.slateKey()
        if slateKey == today { return "Today" }
        let inDF = DateFormatter()
        inDF.calendar = Calendar.current
        inDF.timeZone = TimeZone.current
        inDF.dateFormat = "yyyy-MM-dd"
        guard let d = inDF.date(from: slateKey) else { return slateKey }
        let out = DateFormatter()
        out.dateFormat = "EEE MMM d"
        return out.string(from: d)
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
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.rankLadder.enumerated()), id: \.offset) { index, tier in
                    let isCurrent = tier == profile.currentTier
                    if index > 0 {
                        Divider()
                            .overlay(JuicdTheme.strokeSubtle)
                            .padding(.vertical, 2)
                    }
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(tier.displayName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
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
                    .padding(.vertical, 16)
                    .padding(.horizontal, 2)
                    .background(
                        isCurrent
                            ? JuicdTheme.brand.opacity(0.06)
                            : Color.clear
                    )
                }
            }
        }
        .padding(22)
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
            VStack(alignment: .leading, spacing: 12) {
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

    private func compactTopIcon(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(JuicdTheme.brand.opacity(0.2))
                .overlay(Circle().stroke(JuicdTheme.brand.opacity(0.55), lineWidth: 1))
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22, alignment: .center)
                .foregroundStyle(JuicdTheme.brand)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(JuicdTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func helpSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(JuicdTheme.brand)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}
