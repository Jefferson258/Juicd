import SwiftUI

struct TourneyView: View {
    @ObservedObject var viewModel: TourneyViewModel
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

                    tourneySegmentedToggle(
                        options: TourneyViewModel.Kind.allCases.map { ($0, $0.title) },
                        selection: viewModel.kind,
                        onSelect: { viewModel.select($0) }
                    )

                    if viewModel.hasUpcomingBoard {
                        tourneySegmentedToggle(
                            options: TourneyViewModel.BoardWindow.allCases.map {
                                ($0, $0.title(for: viewModel.kind))
                            },
                            selection: viewModel.boardWindow,
                            onSelect: { viewModel.selectWindow($0) }
                        )
                    }

                    if !adDismissed && JuicdAdsConfig.presentation != .bottomBanner {
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
                        tipRow(icon: "clock.fill", text: "Lock all four closest-number picks before any game on the tourney slate starts.")
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
                        Text(GameCountdown.phrase(until: commence, now: context.date))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                }
                if let freeze = payload.freezeDate {
                    Text(viewModel.isFrozen ? "Entry frozen — a slate game has started" : "Entry locks at first tip \(freeze.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JuicdTheme.textTertiary)
                }
                Text("16-person brackets · extra fields open when more than 16 enter")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JuicdTheme.textTertiary)
                if viewModel.bracketCount > 1 {
                    Text("Your bracket \(viewModel.bracketIndex + 1) of \(viewModel.bracketCount)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(JuicdTheme.brand)
                }
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

    private func bracketCard(_: RemoteTourneyPayload) -> some View {
        let people = viewModel.entrants()
        let revealed = viewModel.revealedRound()
        let columns = TourneyBracketTree.rounds(
            entrants: people,
            actuals: viewModel.remoteActuals,
            revealed: revealed
        )
        return Card(title: "Bracket", systemImage: "point.3.connected.trianglepath.dotted", style: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.isFrozen ? "Frozen · R16 → Final" : "Lock picks before the first game starts. Bots fill empty slots at freeze.")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JuicdTheme.textTertiary)
                TourneyBracketTreeView(columns: columns)
            }
        }
    }

    private func tourneySegmentedToggle<T: Hashable>(
        options: [(T, String)],
        selection: T,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, item in
                let value = item.0
                let title = item.1
                let selected = selection == value
                Button {
                    onSelect(value)
                } label: {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? JuicdTheme.textPrimary : JuicdTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? JuicdTheme.brand.opacity(0.24) : JuicdTheme.card.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    selected ? Color.white.opacity(0.55) : JuicdTheme.strokeSubtle,
                                    lineWidth: selected ? 1.5 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(JuicdTheme.canvasDeep.opacity(0.55))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                )
        )
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

struct TourneyBracketTreeView: View {
    let columns: [[TourneyBracketTree.Match]]

    private let matchH: CGFloat = 56
    private let stride0: CGFloat = 68
    private let colW: CGFloat = 142
    private let colGap: CGFloat = 34
    private let titles = ["R16", "QF", "SF", "Final"]

    private var treeWidth: CGFloat {
        let n = max(columns.count, 1)
        return CGFloat(n) * colW + CGFloat(max(0, n - 1)) * colGap
    }

    private var treeHeight: CGFloat {
        let n = max(columns.first?.count ?? 8, 1)
        return CGFloat(n) * stride0
    }

    private func y(round: Int, index: Int) -> CGFloat {
        let stride = stride0 * CGFloat(1 << round)
        let offset = (stride - matchH) / 2
        return CGFloat(index) * stride + offset
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: colGap) {
                    ForEach(Array(titles.prefix(columns.count).enumerated()), id: \.offset) { _, title in
                        Text(title)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(JuicdTheme.brand)
                            .frame(width: colW, alignment: .leading)
                    }
                }
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        guard columns.count > 1 else { return }
                        for r in 0..<(columns.count - 1) {
                            for i in 0..<columns[r].count {
                                let parentIdx = i / 2
                                let fromX = CGFloat(r) * (colW + colGap) + colW
                                let toX = CGFloat(r + 1) * (colW + colGap)
                                let y1 = y(round: r, index: i) + matchH / 2
                                let y2 = y(round: r + 1, index: parentIdx) + matchH / 2
                                let midX = (fromX + toX) / 2
                                var path = Path()
                                path.move(to: CGPoint(x: fromX, y: y1))
                                path.addLine(to: CGPoint(x: midX, y: y1))
                                path.addLine(to: CGPoint(x: midX, y: y2))
                                path.addLine(to: CGPoint(x: toX, y: y2))
                                ctx.stroke(
                                    path,
                                    with: .color(JuicdTheme.brand.opacity(0.42)),
                                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                    }
                    .frame(width: treeWidth, height: treeHeight)

                    ForEach(Array(columns.enumerated()), id: \.offset) { r, matches in
                        ForEach(Array(matches.enumerated()), id: \.element.id) { i, match in
                            matchCard(match)
                                .frame(width: colW, height: matchH, alignment: .top)
                                .offset(x: CGFloat(r) * (colW + colGap), y: y(round: r, index: i))
                        }
                    }
                }
                .frame(width: treeWidth, height: treeHeight, alignment: .topLeading)
            }
            .padding(.vertical, 4)
        }
    }

    private func matchCard(_ match: TourneyBracketTree.Match) -> some View {
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
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity)
        .background(isWinner ? JuicdTheme.brand.opacity(0.16) : Color.clear)
    }
}
