import SwiftUI

struct TourneyView: View {
    @ObservedObject var viewModel: TourneyViewModel

    private static let tipTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Tourney",
                    subtitle: "Daily closest-pick bracket — choose a tournament variant, preview all four rounds, enter before lock, then one numeric pick per round.",
                    centered: true,
                    kicker: "Daily"
                )

                dailySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
    }

    private var dailySection: some View {
        Card(title: "Daily closest-pick", systemImage: "trophy.fill", style: .hero) {
            VStack(alignment: .leading, spacing: 14) {
                Text("One bracket per UTC day. Sixteen players — each round uses the prop shown below; closest to the simulated result advances. One pick per round (no per-round stake).")
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)

                tiebreakerFootnote

                if viewModel.dailyClosest == nil {
                    gamePicker

                    if let g = viewModel.gameOptions.first(where: { $0.id == viewModel.selectedGameId }) {
                        roundPreviewBlock(for: g)
                        entryDeadlineBlock(for: g)
                    }

                    Button {
                        viewModel.enterDailyClosest()
                    } label: {
                        Text("Enter bracket")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                } else if let st = viewModel.dailyClosest {
                    Text(st.tournamentName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                    Text(st.gameLabel)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JuicdTheme.brand)

                    Text("Tip \(Self.tipTimeFormatter.string(from: st.tipOffAt)) · entry locked \(Self.tipTimeFormatter.string(from: st.entryClosesAt))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JuicdTheme.textTertiary)

                    if st.completed {
                        Text("You cleared the daily bracket today.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                    } else if st.eliminated {
                        eliminatedMessage(for: st)
                    } else {
                        Text("Round \(st.nextQuarter) of 4")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JuicdTheme.textSecondary)

                        if let spec = viewModel.currentRoundSpec {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(spec.propLabel)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Text(spec.statSummary)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(JuicdTheme.canvasDeep.opacity(0.45)))
                        }

                        TextField(roundPlaceholder(for: viewModel.currentRoundSpec), text: $viewModel.dailyPickText)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(JuicdTheme.card))
                            .foregroundStyle(JuicdTheme.textPrimary)

                        Button {
                            viewModel.submitDailyPick()
                        } label: {
                            Text("Submit pick")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JuicdTheme.brand)

                        Button {
                            viewModel.simulateFullBracketDemo()
                        } label: {
                            Text("Simulate full bracket (demo)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(JuicdTheme.textTertiary)
                    }

                    if !st.roundsCompleted.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today’s rounds")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(JuicdTheme.textTertiary)
                            ForEach(st.roundsCompleted, id: \.quarter) { r in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Round \(r.quarter) · \(r.propLabel)")
                                        .font(.caption.weight(.bold))
                                    Text("You \(r.userPick.formatted(.number.precision(.fractionLength(1)))) vs \(r.opponentLabel) \(r.opponentPick.formatted(.number.precision(.fractionLength(1)))) · result \(r.actualTotalPoints.formatted(.number.precision(.fractionLength(1))))")
                                        .font(.caption2)
                                        .foregroundStyle(JuicdTheme.textSecondary)
                                    Text(r.userWon ? "Won — +\(r.rewardSeasonPoints) season pts" : "Lost")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(r.userWon ? JuicdTheme.brand : JuicdTheme.textTertiary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.5)))
                            }
                        }
                    }
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.9))
                }
            }
        }
    }

    private var gamePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick a tournament")
                .font(.caption.weight(.heavy))
                .foregroundStyle(JuicdTheme.textTertiary)
            VStack(spacing: 8) {
                ForEach(viewModel.gameOptions) { g in
                    let selected = viewModel.selectedGameId == g.id
                    Button {
                        viewModel.selectedGameId = g.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(g.tournamentName)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(JuicdTheme.textPrimary)
                                Text(g.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                Text("Tip \(Self.tipTimeFormatter.string(from: g.tipOffAt))")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(JuicdTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? JuicdTheme.brand : JuicdTheme.textTertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? JuicdTheme.brand.opacity(0.12) : JuicdTheme.canvasDeep.opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? JuicdTheme.brand.opacity(0.5) : JuicdTheme.strokeSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(Date() >= g.entryClosesAt)
                    .opacity(Date() >= g.entryClosesAt ? 0.45 : 1)
                }
            }
        }
    }

    private func roundPreviewBlock(for g: DailyGameOption) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your four rounds (locked at entry)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(JuicdTheme.textTertiary)
            ForEach(g.roundPreviews) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Round \(p.round) — \(p.title)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text(p.subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(JuicdTheme.canvasDeep.opacity(0.4)))
            }
        }
    }

    @ViewBuilder
    private func eliminatedMessage(for st: DailyClosestTournamentState) -> some View {
        if st.roundsCompleted.count == 4, let firstLoss = st.roundsCompleted.first(where: { !$0.userWon })?.quarter {
            Text("Full four-round run complete. You didn’t sweep the bracket — earliest loss was round \(firstLoss). See results below.")
                .foregroundStyle(JuicdTheme.textSecondary)
        } else {
            Text("Eliminated in round \(st.roundsCompleted.last?.quarter ?? 0).")
                .foregroundStyle(JuicdTheme.textSecondary)
        }
    }

    private func roundPlaceholder(for spec: DailyRoundPropSpec?) -> String {
        guard let spec else { return "Your pick" }
        let mid = (spec.simMin + spec.simMax) / 2
        let hint = String(format: "%.1f", (mid * 10).rounded() / 10)
        return "Pick (e.g. \(hint))"
    }

    private func entryDeadlineBlock(for g: DailyGameOption) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time left to enter")
                .font(.caption.weight(.heavy))
                .foregroundStyle(JuicdTheme.textTertiary)
            Text("Locks 1 hour before tip-off so brackets can be built on the server.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(JuicdTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = max(0, g.entryClosesAt.timeIntervalSince(Date()))
                if remaining <= 0 {
                    Text("Entry closed for this game")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textTertiary)
                } else {
                    Text(formatCountdown(remaining))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(JuicdTheme.brand)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(JuicdTheme.canvasDeep.opacity(0.5)))
    }

    private func formatCountdown(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private var tiebreakerFootnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tiebreakers")
                .font(.caption.weight(.heavy))
                .foregroundStyle(JuicdTheme.textTertiary)
            Text("Closer to the actual total wins. If both are equally close, we compare fractional parts of each pick × 1337; if still tied, the lower submitted pick wins.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(JuicdTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(JuicdTheme.canvasDeep.opacity(0.4)))
    }
}
