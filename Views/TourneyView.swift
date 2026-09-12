import SwiftUI

struct TourneyView: View {
    @ObservedObject var viewModel: TourneyViewModel
    @AppStorage(JuicdAdsConfig.enabledStorageKey) private var adsEnabled = true
    @State private var showTourneyTips = false
    @State private var adDismissed = false
    @FocusState private var pickFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                SectionColumn(spacing: 26) {
                    JuicdTabScreenAccent()
                    BrandHeader(
                        title: "Tourney",
                        subtitle: "Daily is 4am–4am CT. Weekly runs Monday through Sunday night.",
                        centered: true,
                        kicker: viewModel.kind.title
                    )
                    HStack(spacing: 10) {
                        compactTopIcon(systemName: "trophy.fill")
                        compactTopIcon(systemName: "person.3.fill")
                        compactTopIcon(systemName: "clock.fill")
                        Button { showTourneyTips = true } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(JuicdTheme.brand)
                    }

                    Picker("Kind", selection: $viewModel.kind) {
                        ForEach(TourneyViewModel.Kind.allCases) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.kind) { _, new in
                        viewModel.select(new)
                    }

                    if viewModel.hasUpcomingBoard {
                        Picker("Board", selection: $viewModel.boardWindow) {
                            ForEach(TourneyViewModel.BoardWindow.allCases) { window in
                                Text(window.title(for: viewModel.kind)).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.boardWindow) { _, new in
                            viewModel.selectWindow(new)
                        }
                    }

                    if adsEnabled && !adDismissed && JuicdAdsConfig.presentation != .bottomBanner {
                        JuicdInFeedAdSlot(creative: JuicdDevAdCreative.all[1], onDismiss: {
                            adDismissed = true
                        })
                    }

                    if let payload = viewModel.payload {
                        eventCard(payload)
                        picksCard(payload)
                        bracketCard(payload)
                    } else {
                        Text(emptyTourneyCopy)
                            .font(.subheadline)
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
            .background(JuicdScreenBackground())
            .juicdKeyboardDoneButton { pickFocused = false }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.refreshFromBoard()
            Task { await viewModel.refreshRemoteBracket() }
        }
        .sheet(isPresented: $showTourneyTips) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tourney guide")
                            .font(.title2.bold())
                        tipRow(icon: "calendar", text: "Daily runs with the 4am CT board. Weekly is Monday through Sunday night. On Sunday you can enter next week early.")
                        tipRow(icon: "clock.fill", text: "Lock all four closest-number picks before freeze — one hour before the featured game starts.")
                        tipRow(icon: "person.crop.circle.badge.questionmark", text: "Empty slots fill with labeled bots (fun names like AmazingTackler54) at freeze.")
                        tipRow(icon: "eye.fill", text: "Everyone’s picks are visible before a round is scored. Rounds reveal after the game.")
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(JuicdScreenBackground())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showTourneyTips = false }.fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var emptyTourneyCopy: String {
        switch viewModel.kind {
        case .daily:
            return "No daily tournament on the board yet. Check back after 4am CT."
        case .weekly:
            return "No weekly tournament on the board yet. The week runs Monday through Sunday."
        }
    }

    private func eventCard(_ payload: RemoteTourneyPayload) -> some View {
        Card(title: payload.title, systemImage: "sportscourt.fill", style: .hero) {
            VStack(alignment: .leading, spacing: 8) {
                Text(payload.gameLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JuicdTheme.brand)
                if let commence = payload.commenceDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Starts in \(GameCountdown.label(until: commence, now: context.date))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                }
                if let freeze = payload.freezeDate {
                    Text(viewModel.isFrozen ? "Entry frozen" : "Entry freezes \(freeze.formatted(date: .omitted, time: .shortened)) CT window")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }
                Text("16-person bracket · bots pad empty slots")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JuicdTheme.textTertiary)
            }
        }
    }

    private func picksCard(_ payload: RemoteTourneyPayload) -> some View {
        Card(title: "Your four picks", systemImage: "target", style: .hero) {
            VStack(alignment: .leading, spacing: 12) {
                if let submitted = viewModel.submittedPicks {
                    Text("Locked in.")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(JuicdTheme.brand)
                    ForEach(Array(payload.roundSpecs.enumerated()), id: \.element.id) { idx, spec in
                        pickRow(spec: spec, value: submitted.indices.contains(idx) ? String(format: "%.1f", submitted[idx]) : "—", editable: false)
                    }
                } else {
                    ForEach(Array(payload.roundSpecs.enumerated()), id: \.element.id) { idx, spec in
                        pickRow(spec: spec, index: idx, editable: !viewModel.isFrozen)
                    }
                    Button {
                        viewModel.submitPicks()
                    } label: {
                        Text(viewModel.isFrozen ? "Entry closed" : "Lock four picks")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                    .disabled(viewModel.isFrozen)
                }
            }
        }
    }

    private func pickRow(spec: RemoteTourneyRound, index: Int? = nil, value: String? = nil, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("R\(spec.round) · \(spec.propLabel)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(spec.statSummary)
                .font(.caption)
                .foregroundStyle(JuicdTheme.textTertiary)
            if editable, let index {
                TextField(spec.line.map { "Line \($0.formatted())" } ?? "Your number", text: $viewModel.pickTexts[index])
                    .focused($pickFocused)
                    .keyboardType(.decimalPad)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.card))
            } else {
                Text(value ?? "—")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(JuicdTheme.brand)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(JuicdTheme.canvasDeep.opacity(0.45)))
    }

    private func bracketCard(_ payload: RemoteTourneyPayload) -> some View {
        let people = viewModel.entrants()
        let revealed = viewModel.revealedRound()
        let columns = TourneyBracketTree.rounds(
            entrants: people,
            actuals: viewModel.remoteActuals,
            revealed: revealed
        )
        let titles = ["R16", "QF", "SF", "Final"]
        return Card(title: "Bracket", systemImage: "point.3.connected.trianglepath.dotted", style: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.isFrozen ? "Frozen · R16 → Final" : "Matchups lock 1 hour before start. Bots fill empty slots.")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JuicdTheme.textTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { idx, matches in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(titles.indices.contains(idx) ? titles[idx] : "R\(idx + 1)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(JuicdTheme.brand)
                                VStack(spacing: 10) {
                                    ForEach(matches) { match in
                                        bracketMatchup(match)
                                    }
                                }
                            }
                            .frame(width: 148)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func bracketMatchup(_ match: TourneyBracketTree.Match) -> some View {
        VStack(spacing: 0) {
            bracketSlot(match.top, winnerId: match.winner?.id)
            Rectangle()
                .fill(JuicdTheme.strokeSubtle)
                .frame(height: 1)
            bracketSlot(match.bottom, winnerId: match.winner?.id)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(JuicdTheme.card.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private func bracketSlot(_ person: BracketEntrant?, winnerId: String?) -> some View {
        let isWinner = person.map { $0.id == winnerId } ?? false
        return HStack(spacing: 6) {
            Text(person?.displayName ?? "Open")
                .font(.system(size: 11, weight: isWinner ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(person == nil ? JuicdTheme.textTertiary : JuicdTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if person?.isBot == true {
                Text("BOT")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(JuicdTheme.brand)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isWinner ? JuicdTheme.brand.opacity(0.16) : Color.clear)
    }

    private func compactTopIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(JuicdTheme.brand)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(JuicdTheme.brand)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(JuicdTheme.textSecondary)
        }
    }
}
