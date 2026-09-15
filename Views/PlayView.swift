import SwiftUI

struct PlayView: View {
    @ObservedObject var viewModel: PlayViewModel

    @AppStorage(JuicdAdsDev.forceCreativeIdKey) private var forceCreativeId = ""
    @AppStorage(JuicdAdsDev.forceRevisionKey) private var forceRevision = 0

    /// When set, inserts at most one ad at `insertIndex` (0...n) among ribbons.
    @State private var adInsertion: AdInsertion?

    /// After user taps dismiss on the ad, no new ad until they relaunch (or spawn one from DEBUG Profile).
    @State private var adDismissedForCurrentRibbonFeed = false
    @State private var sessionCreativeId = JuicdDevAdCreative.all[0].id
    @State private var showPlayTips = false
    @FocusState private var searchFieldFocused: Bool

    private let juicdBoostStroke = Color(red: 1, green: 0.82, blue: 0.12)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
            ScrollView {
                SectionColumn(spacing: 14) {
                    JuicdTabScreenAccent()
                    HStack(alignment: .center, spacing: 10) {
                        Text("Play")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Spacer(minLength: 8)
                        if let profile = viewModel.profile {
                            compactBalanceChip(
                                todayPoints: profile.availableDailyPoints,
                                tomorrowPoints: viewModel.tomorrowPointsRemaining
                            )
                        }
                        Button {
                            showPlayTips = true
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(JuicdTheme.brand)
                    }

                    if !viewModel.pendingSlips.isEmpty {
                        pendingSlipsCard
                    }

                    sportFilterPills

                    if viewModel.sportPill != .forYou {
                        statFilterPills
                        searchBar
                    }

                    if viewModel.displayedRibbons.isEmpty && viewModel.displayedTomorrowRibbons.isEmpty {
                        playEmptyState
                    } else {
                        if viewModel.displayedRibbons.isEmpty {
                            todayQuietBanner
                        } else {
                            ForEach(playFeedRows(ribbons: viewModel.displayedRibbons)) { row in
                                switch row {
                                case .ribbon(let ribbon):
                                    ribbonBlock(ribbon)
                                        .id(ribbon.id)
                                case .placeholder(let creative, let rowId):
                                    JuicdInFeedAdSlot(creative: creative, onDismiss: dismissCurrentAd)
                                    .id(rowId)
                                }
                            }
                        }
                        if !viewModel.displayedTomorrowRibbons.isEmpty {
                            tomorrowSectionHeader
                            ForEach(viewModel.displayedTomorrowRibbons) { ribbon in
                                ribbonBlock(ribbon)
                                    .id(ribbon.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.bottom, 8)
            }
            // New identity when sport/stat filters change so scroll offset resets to the top (no stale position from the last league).
            .id("\(viewModel.sportPill.rawValue)-\(viewModel.statFilterId)")
            .scrollIndicators(.hidden)
            .background(JuicdScreenBackground())
            .task(id: "\(viewModel.displayedRibbons.map(\.id).joined(separator: ","))-\(viewModel.displayedTomorrowRibbons.map(\.id).joined(separator: ","))-\(forceRevision)") {
                refreshAdInsertion(ribbonCount: viewModel.displayedRibbons.count)
            }

            if viewModel.pickingAdditionalLeg {
                addLegBanner
            }
            }
        .task {
            await viewModel.refreshLiveOddsLine()
            await viewModel.settlePendingSlips()
        }
        .onAppear {
            viewModel.refreshProfile()
        }
        .sheet(isPresented: $viewModel.showParlayBuilder) {
            ParlayBuilderSheet(viewModel: viewModel)
        }
        .alert("Use your daily points", isPresented: $viewModel.showFirstBetReminder) {
            Button("Place bet") {
                Task { await viewModel.executePlaceParlay() }
            }
            Button("Go back", role: .cancel) {}
        } message: {
            Text(
                "You can spend all or part of your daily points. Ranked results are normalized to a 100-point baseline."
            )
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.builderToast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(JuicdTheme.cardElevated)
                            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                    )
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.builderToast)
        .sheet(isPresented: $showPlayTips) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Play guide")
                            .font(.title2.bold())
                            .foregroundStyle(JuicdTheme.textPrimary)

                        tipRow(icon: "sparkles", text: "Popular aggregates ribbons that actually have priced props; league pills filter to one sport and unlock stat/search chips.")
                        tipRow(icon: "sportscourt.fill", text: "Tap any tile to build a slip — singles start there; Add leg stacks up to a small parlay with multiplied decimal odds.")
                        tipRow(icon: "bolt.fill", text: "Today’s bets use today’s 100 points. Tomorrow’s games use tomorrow’s 100 — the line locks when you place.")
                        tipRow(icon: "star.circle.fill", text: "Juicd boost tiles multiply decimal odds on that pick — great upside if you love the price.")
                        tipRow(icon: "arrow.clockwise", text: "Sync refreshes the board. With Supabase keys set you pull the shared Edge Function board; otherwise a fallback API line may appear.")
                        tipRow(icon: "chart.line.uptrend.xyaxis", text: "Ranked pools only care how your Play day went vs peers — low stakes get scaled so fairness holds.")
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showPlayTips = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .juicdKeyboardDoneButton { searchFieldFocused = false }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
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

    private var sportFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.sportPillsWithOdds) { pill in
                    let selected = viewModel.sportPill == pill
                    Button {
                        viewModel.sportPill = pill
                    } label: {
                        HStack(spacing: 6) {
                            if pill == .forYou {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(pill.displayTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(selected ? JuicdTheme.textPrimary : JuicdTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? JuicdTheme.brand.opacity(0.22) : JuicdTheme.card.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(selected ? Color.white.opacity(0.55) : JuicdTheme.strokeSubtle, lineWidth: selected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var statFilterPills: some View {
        let opts = viewModel.sportPill.statPillOptions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(opts, id: \.id) { opt in
                    let selected = viewModel.statFilterId == opt.id
                    Button {
                        viewModel.statFilterId = opt.id
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? JuicdTheme.textPrimary : JuicdTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selected ? JuicdTheme.cardElevated : JuicdTheme.card.opacity(0.65))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(selected ? Color.white.opacity(0.45) : JuicdTheme.strokeSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(JuicdTheme.textTertiary)
            TextField("Search player or team", text: $viewModel.searchText)
                .focused($searchFieldFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(JuicdTheme.textPrimary)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(JuicdTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                )
        )
    }

    private var playEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(JuicdTheme.textTertiary)
            Text("No games left today")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
            Text(
                viewModel.hasActiveSearch
                    ? "Try a different search or clear it."
                    : "No games left on today’s or tomorrow’s board. Check back after 4am CT."
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(JuicdTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(JuicdTheme.card.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                )
        )
    }

    private var pendingSlipsCard: some View {
        Card(title: "Pending slips", systemImage: "clock.badge.checkmark", style: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.pendingSlips) { slip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slip.legSummaries.joined(separator: " + "))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(JuicdTheme.textPrimary)
                            .lineLimit(2)
                        HStack {
                            Text("\(slip.stakePoints) pts · \(String(format: "%.2f", slip.combinedOdds))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JuicdTheme.brand)
                            Spacer()
                            if let commence = slip.commenceAt {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(GameCountdown.label(until: commence, now: context.date))
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(JuicdTheme.textSecondary)
                                }
                            } else {
                                Text("Pending")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.45)))
                }
            }
        }
    }

    private var addLegBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(juicdBoostStroke)
            Text("Tap a prop to add it to your parlay")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Cancel") {
                viewModel.cancelAddLeg()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(JuicdTheme.brand)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(JuicdTheme.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(juicdBoostStroke.opacity(0.7), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func compactBalanceChip(todayPoints: Int, tomorrowPoints: Int) -> some View {
        HStack(spacing: 8) {
            balancePill(points: todayPoints, label: "today")
            balancePill(points: tomorrowPoints, label: "tm")
        }
        .accessibilityLabel("Today \(todayPoints) points, tomorrow \(tomorrowPoints) points")
    }

    private func balancePill(points: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(JuicdTheme.brand)
            Text("\(points) \(label)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(JuicdTheme.card)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                }
        }
    }

    private var todayQuietBanner: some View {
        Text("No games left today — tomorrow is below.")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(JuicdTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private var tomorrowSectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tomorrow")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
            Text("Uses tomorrow’s 100 points. Line locks when you place.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(JuicdTheme.textSecondary)
        }
        .padding(.top, 8)
    }

    private func ribbonBlock(_ ribbon: PlayPropRibbon) -> some View {
        let applySport = viewModel.sportPillToApply(forRibbonId: ribbon.id)
        let showLeagueChevron = viewModel.sportPill == .forYou
        return VStack(alignment: .leading, spacing: 14) {
            PlayRibbonHeader(
                ribbon: ribbon,
                onChevronTap: showLeagueChevron
                    ? applySport.map { pill in { viewModel.sportPill = pill } }
                    : nil
            )

            if viewModel.sportPill == .forYou {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(ribbon.props) { prop in
                            propBetSquare(prop, ribbonId: ribbon.id)
                        }
                    }
                    .padding(.leading, 2)
                    .padding(.trailing, 16)
                    .padding(.vertical, 4)
                }
            } else {
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(ribbon.props) { prop in
                        propBetSquare(prop, ribbonId: ribbon.id)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func propBetSquare(_ prop: PlayPropBet, ribbonId: String) -> some View {
        let pillColor = JuicdTheme.leaguePillColor(tag: prop.leagueTag)
        let ribbonAccent = JuicdTheme.ribbonAccent(ribbonId: ribbonId)
        let isJuicdBoost = prop.juicdMultiplier != nil
        let needsSidePick = prop.hasOverUnderChoice || prop.hasMoneylineChoice

        if needsSidePick {
            propBetCard(prop, ribbonId: ribbonId, pillColor: pillColor, ribbonAccent: ribbonAccent, isJuicdBoost: isJuicdBoost)
        } else {
            Button {
                viewModel.handlePropTap(prop)
            } label: {
                propBetCard(prop, ribbonId: ribbonId, pillColor: pillColor, ribbonAccent: ribbonAccent, isJuicdBoost: isJuicdBoost)
            }
            .buttonStyle(.plain)
        }
    }

    private func propBetCard(
        _ prop: PlayPropBet,
        ribbonId: String,
        pillColor: Color,
        ribbonAccent: Color,
        isJuicdBoost: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text(prop.leagueTag)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [pillColor, pillColor.opacity(0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    if isJuicdBoost {
                        Text("Juicd 1.5×")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(juicdBoostStroke)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(juicdBoostStroke.opacity(0.18)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 10)

                Text(prop.athleteOrTeam)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)

                Text(prop.matchup)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                if let commence = prop.commenceTime {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(GameCountdown.phrase(until: commence, now: context.date))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(JuicdTheme.brand)
                            .padding(.top, 4)
                    }
                }

                Text(prop.propDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(prop.lineText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    if !prop.hasOverUnderChoice && !prop.hasMoneylineChoice {
                        Text(prop.pickLabel)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(JuicdTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 6)

                if prop.hasOverUnderChoice {
                    HStack(spacing: 6) {
                        if let over = prop.overOdds {
                            Button {
                                viewModel.handleOverUnder(prop, side: "Over", odds: over)
                            } label: {
                                VStack(spacing: 2) {
                                    Text("Over")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(String(format: "%.2f", over))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.9)))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(JuicdTheme.brand)
                        }
                        if let under = prop.underOdds {
                            Button {
                                viewModel.handleOverUnder(prop, side: "Under", odds: under)
                            } label: {
                                VStack(spacing: 2) {
                                    Text("Under")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(String(format: "%.2f", under))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.9)))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(JuicdTheme.brand)
                        }
                    }
                    .padding(.top, 10)
                } else if prop.hasMoneylineChoice {
                    HStack(spacing: 6) {
                        if let home = prop.homeOdds {
                            moneylineSideButton(
                                label: moneylineTeamLabel(prop.homeTeam, fallback: "Home"),
                                odds: home,
                                prop: prop
                            )
                        }
                        if let away = prop.awayOdds {
                            moneylineSideButton(
                                label: moneylineTeamLabel(prop.awayTeam, fallback: "Away"),
                                odds: away,
                                prop: prop
                            )
                        }
                    }
                    .padding(.top, 10)
                } else {
                    HStack {
                        Text(isJuicdBoost ? "Juicd odds" : "Odds")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(JuicdTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text(String(format: "%.2f", prop.juicdEffectiveDecimalOdds))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(JuicdTheme.brand)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(JuicdTheme.canvasDeep.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(12)
            .frame(
                minWidth: viewModel.sportPill == .forYou ? 168 : nil,
                idealWidth: viewModel.sportPill == .forYou ? 168 : nil,
                maxWidth: viewModel.sportPill == .forYou ? 168 : .infinity,
                alignment: .topLeading
            )
            .fixedSize(horizontal: false, vertical: true)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    JuicdTheme.cardElevated,
                                    JuicdTheme.card
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [ribbonAccent.opacity(0.35), JuicdTheme.strokeSubtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    if isJuicdBoost {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(juicdBoostStroke, lineWidth: 2.5)
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(juicdBoostStroke.opacity(0.35), lineWidth: 4)
                    }
                }
                .shadow(color: isJuicdBoost ? juicdBoostStroke.opacity(0.25) : Color.black.opacity(0.35), radius: isJuicdBoost ? 14 : 12, y: 6)
            }
    }


    private func moneylineTeamLabel(_ team: String?, fallback: String) -> String {
        let trimmed = (team ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    @ViewBuilder
    private func moneylineSideButton(label: String, odds: Double, prop: PlayPropBet) -> some View {
        Button {
            viewModel.handleMoneyline(prop, side: label, odds: odds)
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                Text(String(format: "%.2f", odds))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(JuicdTheme.brand)
    }

    // MARK: - Ad placement (Play feed)

    private enum AdInsertion {
        case placeholder(JuicdDevAdCreative, insertIndex: Int)

        var insertIndex: Int {
            switch self {
            case .placeholder(_, let i): return i
            }
        }
    }

    private enum PlayFeedRow: Identifiable {
        case ribbon(PlayPropRibbon)
        case placeholder(JuicdDevAdCreative, rowId: String)

        var id: String {
            switch self {
            case .ribbon(let r): return r.id
            case .placeholder(_, let rowId): return rowId
            }
        }
    }

    private func playFeedRows(ribbons: [PlayPropRibbon]) -> [PlayFeedRow] {
        guard let insertion = adInsertion else {
            return ribbons.map { .ribbon($0) }
        }
        let index = insertion.insertIndex
        var rows: [PlayFeedRow] = []
        func appendAd() {
            switch insertion {
            case .placeholder(let creative, _):
                rows.append(.placeholder(creative, rowId: "ad-\(creative.id)-\(index)"))
            }
        }
        for (i, r) in ribbons.enumerated() {
            if i == index { appendAd() }
            rows.append(.ribbon(r))
        }
        if index == ribbons.count { appendAd() }
        return rows
    }

    private func dismissCurrentAd() {
        adInsertion = nil
        forceCreativeId = ""
        forceRevision += 1
        adDismissedForCurrentRibbonFeed = true
    }

    private func refreshAdInsertion(ribbonCount: Int) {
        guard ribbonCount > 0 else {
            adInsertion = nil
            return
        }
        if !forceCreativeId.isEmpty,
           let c = JuicdDevAdCreative.all.first(where: { $0.id == forceCreativeId }) {
            adInsertion = .placeholder(c, insertIndex: 0)
            return
        }
        if adDismissedForCurrentRibbonFeed {
            adInsertion = nil
            return
        }
        guard JuicdAdsDev.shouldShowAd() else {
            adInsertion = nil
            return
        }
        if JuicdAdsConfig.presentation == .bottomBanner {
            adInsertion = nil
            return
        }
        let creative = JuicdDevAdCreative.all.first(where: { $0.id == sessionCreativeId })
            ?? JuicdDevAdCreative.all[0]
        // First row of the pick list so the card is on-screen and easy to dismiss.
        adInsertion = .placeholder(creative, insertIndex: 0)
    }
}
