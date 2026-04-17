import SwiftUI

struct PlayView: View {
    @ObservedObject var viewModel: PlayViewModel

    @AppStorage("juicd_ads_enabled") private var adsEnabled = false
    @AppStorage(JuicdAdsDev.forceCreativeIdKey) private var forceCreativeId = ""
    @AppStorage(JuicdAdsDev.forceRevisionKey) private var forceRevision = 0

    /// When set, inserts at most one dev ad at `insertIndex` (0...n) among ribbons.
    @State private var adInsertion: (creative: JuicdDevAdCreative, insertIndex: Int)?

    /// After user taps dismiss on the ad, no new random ad until ribbons change (spawn still works).
    @State private var adDismissedForCurrentRibbonFeed = false
    @State private var previousRibbonSig = ""
    @State private var showPlayTips = false
    @FocusState private var searchFieldFocused: Bool

    private let juicdBoostStroke = Color(red: 1, green: 0.82, blue: 0.12)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
            ScrollView {
                SectionColumn(spacing: 24) {
                    JuicdTabScreenAccent()
                    BrandHeader(
                        title: "Play",
                        subtitle: "Find picks, build slips, and place bets.",
                        centered: true,
                        kicker: "Today’s board"
                    )
                    HStack {
                        Spacer()
                        Button {
                            showPlayTips = true
                        } label: {
                            Label("How Play works", systemImage: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(JuicdTheme.brand)
                    }

                    if let profile = viewModel.profile {
                        bankrollHero(points: profile.availableDailyPoints)
                    }

                    sportFilterPills

                    if viewModel.sportPill != .forYou {
                        statFilterPills
                        searchBar
                    }

                    oddsToolbar

                    if viewModel.displayedRibbons.isEmpty {
                        playEmptyState
                    } else {
                        ForEach(playFeedRows(ribbons: viewModel.displayedRibbons)) { row in
                            switch row {
                            case .ribbon(let ribbon):
                                ribbonBlock(ribbon)
                                    .id(ribbon.id)
                            case .ad(let creative, let rowId):
                                JuicdNativeAdPlaceholder(creative: creative) {
                                    JuicdAdsDev.recordImpression()
                                } onDismiss: {
                                    dismissCurrentAd()
                                }
                                .id(rowId)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
            }
            // New identity when sport/stat filters change so scroll offset resets to the top (no stale position from the last league).
            .id("\(viewModel.sportPill.rawValue)-\(viewModel.statFilterId)")
            .scrollIndicators(.hidden)
            .background(JuicdScreenBackground())
            .task(id: "\(viewModel.displayedRibbons.map(\.id).joined(separator: ","))-\(forceRevision)") {
                refreshAdInsertion(ribbonCount: viewModel.displayedRibbons.count)
            }
            .onChange(of: adsEnabled) { _, on in
                if on {
                    refreshAdInsertion(ribbonCount: viewModel.displayedRibbons.count)
                } else {
                    adInsertion = nil
                }
            }

            if viewModel.pickingAdditionalLeg {
                addLegBanner
            }
            }
        .task {
            await viewModel.refreshLiveOddsLine()
        }
        .onAppear {
            viewModel.refreshProfile()
        }
        .sheet(isPresented: $viewModel.showParlayBuilder) {
            ParlayBuilderSheet(viewModel: viewModel)
        }
        .alert("Use your daily points", isPresented: $viewModel.showFirstBetReminder) {
            Button("Place bet") {
                viewModel.executePlaceParlay()
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
                VStack(alignment: .leading, spacing: 14) {
                    Text("Play tips")
                        .font(.title3.bold())
                    Text("• Your daily points reset to 100 each slate.")
                    Text("• You can spend all or part of the 100.")
                    Text("• Daily rank performance uses Play bets only.")
                    Text("• If you spend less than 100, results are normalized to a 100-point baseline.")
                    Text("• Daily quarter tourneys are tracked separately for season winner badges.")
                    Spacer()
                }
                .foregroundStyle(JuicdTheme.textSecondary)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showPlayTips = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .juicdKeyboardDoneButton { searchFieldFocused = false }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var sportFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlaySportPill.primaryRow) { pill in
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
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(JuicdTheme.textTertiary)
            Text("No picks found")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
            Text(
                viewModel.hasActiveSearch
                    ? "Try a different search or clear it."
                    : "Try another filter or sync again."
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

    private var oddsToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.oddsStatus)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(.leading, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.refreshLiveOddsLine() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoadingOdds {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(JuicdTheme.brand)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text("Sync")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(JuicdTheme.brand)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(JuicdTheme.brand.opacity(0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(JuicdTheme.brand.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .disabled(viewModel.isLoadingOdds)
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(JuicdTheme.card.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                )
        )
    }

    private var statusDotColor: Color {
        if viewModel.isLoadingOdds { return JuicdTheme.brand }
        if viewModel.liveLine != nil { return Color(red: 0.3, green: 0.95, blue: 0.55) }
        return JuicdTheme.textTertiary
    }

    private func bankrollHero(points: Int) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [JuicdTheme.brand.opacity(0.5), JuicdTheme.brand2.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(points)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text("pts")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(JuicdTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
        }
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

    private func propBetSquare(_ prop: PlayPropBet, ribbonId: String) -> some View {
        let pillColor = JuicdTheme.leaguePillColor(tag: prop.leagueTag)
        let ribbonAccent = JuicdTheme.ribbonAccent(ribbonId: ribbonId)
        let isJuicdBoost = prop.juicdMultiplier != nil

        return Button {
            viewModel.handlePropTap(prop)
        } label: {
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
                    .lineLimit(1)
                    .padding(.top, 4)

                Text(prop.propDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 6)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(prop.lineText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textSecondary)
                    Text(prop.pickLabel)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(JuicdTheme.textPrimary)
                }
                .padding(.top, 8)

                Spacer(minLength: 10)

                HStack {
                    Text(isJuicdBoost ? "Juicd odds" : "Odds")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textTertiary)
                    Spacer()
                    Text(String(format: "%.2f", prop.juicdEffectiveDecimalOdds))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.brand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)
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
            .padding(14)
            .frame(width: 160, alignment: .leading)
            .frame(minHeight: 210, alignment: .topLeading)
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
        .buttonStyle(.plain)
    }

    // MARK: - Dev ad placement (Play feed)

    private enum PlayFeedRow: Identifiable {
        case ribbon(PlayPropRibbon)
        case ad(JuicdDevAdCreative, rowId: String)

        var id: String {
            switch self {
            case .ribbon(let r): return r.id
            case .ad(_, let rowId): return rowId
            }
        }
    }

    private func playFeedRows(ribbons: [PlayPropRibbon]) -> [PlayFeedRow] {
        guard let insertion = adInsertion else {
            return ribbons.map { .ribbon($0) }
        }
        let creative = insertion.creative
        let index = insertion.insertIndex
        let rowId = "ad-\(creative.id)-\(index)"
        var rows: [PlayFeedRow] = []
        for (i, r) in ribbons.enumerated() {
            if i == index {
                rows.append(.ad(creative, rowId: rowId))
            }
            rows.append(.ribbon(r))
        }
        if index == ribbons.count {
            rows.append(.ad(creative, rowId: rowId))
        }
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
            adInsertion = (c, 0)
            return
        }
        if adDismissedForCurrentRibbonFeed {
            adInsertion = nil
            return
        }
        guard adsEnabled else {
            adInsertion = nil
            return
        }
        guard JuicdAdsDev.shouldShowAd(adsEnabled: true) else {
            adInsertion = nil
            return
        }
        let idx = Int.random(in: 0...ribbonCount)
        adInsertion = (JuicdDevAdCreative.random(), idx)
    }
}
