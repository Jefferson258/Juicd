import SwiftUI

struct TourneyView: View {
    @ObservedObject var viewModel: TourneyViewModel

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Tourney",
                    subtitle: "One weekly bracket at a time. Top 50% each day advance. Bonuses at the end.",
                    centered: true
                )

                if let p = viewModel.progress, let def = viewModel.definitions.first(where: { $0.id == p.definitionId }) {
                    activeBracketCard(def: def, p: p)
                } else {
                    Card(title: "Join a weekly cup", systemImage: "flag.checkered") {
                        Text("Pick a sport. You can only be in one weekly tournament at a time.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    ForEach(viewModel.definitions) { def in
                        Button {
                            viewModel.join(def)
                        } label: {
                            HStack {
                                Image(systemName: def.iconSystemName)
                                    .font(.title2)
                                    .foregroundStyle(JuicdTheme.brand)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(def.name)
                                        .font(.headline)
                                        .foregroundStyle(JuicdTheme.textPrimary)
                                    Text("\(def.roundCount) day rounds · \(def.sportKey)")
                                        .font(.caption)
                                        .foregroundStyle(JuicdTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(JuicdTheme.card)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let last = viewModel.lastResult {
                    Card(title: "Last round", systemImage: "chart.bar.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day \(last.roundIndex) · score \(last.userScore) · rank #\(last.rank) of 100")
                                .foregroundStyle(JuicdTheme.textPrimary)
                                .font(.subheadline.weight(.semibold))
                            if last.bonusAwarded > 0 {
                                Text("+\(last.bonusAwarded) season pts")
                                    .foregroundStyle(JuicdTheme.brand)
                                    .font(.headline)
                            }
                            if last.completedTournament {
                                Text("You won the cup!")
                                    .foregroundStyle(.yellow)
                                    .fontWeight(.bold)
                            } else if last.eliminated {
                                Text("Eliminated — bonus applied from your run.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func activeBracketCard(def: WeeklyBracketDefinition, p: UserBracketProgress) -> some View {
        Card(title: def.name, systemImage: def.iconSystemName) {
            VStack(alignment: .leading, spacing: 12) {
                if p.completed {
                    Text("Tournament complete. Total bonus: \(p.totalBonusAwarded) pts")
                        .foregroundStyle(JuicdTheme.textSecondary)
                    Button("Leave & join another") {
                        viewModel.leave()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                } else if p.eliminated {
                    Text("Eliminated. Bonus earned: \(p.totalBonusAwarded) pts")
                        .foregroundStyle(JuicdTheme.textSecondary)
                    Button("Leave & join another") {
                        viewModel.leave()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                } else {
                    Text("Next: day \(p.nextRoundToPlay) of \(def.roundCount)")
                        .font(.headline)
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text("Each day you’re ranked against 100 competitors. Finish in the top 50 to advance.")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.caption)

                    Button {
                        viewModel.playNextRound()
                    } label: {
                        Text("Simulate today’s round")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)

                    Button("Leave tournament", role: .destructive) {
                        viewModel.leave()
                    }
                    .font(.footnote)
                }
            }
        }
    }
}
