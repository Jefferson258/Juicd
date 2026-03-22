import SwiftUI

struct TourneyView: View {
    @ObservedObject var viewModel: TourneyViewModel

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Tourney",
                    subtitle: "Weekly cups: survive each day’s cut. Bonuses when you’re out or when you win it all.",
                    centered: true,
                    kicker: "Brackets"
                )

                if let p = viewModel.progress, let def = viewModel.definitions.first(where: { $0.id == p.definitionId }) {
                    activeBracketCard(def: def, p: p)
                } else {
                    Card(title: "Pick a cup", systemImage: "flag.checkered", style: .hero) {
                        Text("One active weekly bracket at a time. Choose a sport — you can switch after your run ends.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.system(size: 15, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 12) {
                        ForEach(viewModel.definitions) { def in
                            Button {
                                viewModel.join(def)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [JuicdTheme.brand.opacity(0.35), JuicdTheme.brand2.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                        Image(systemName: def.iconSystemName)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(JuicdTheme.brand)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(def.name)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundStyle(JuicdTheme.textPrimary)
                                        Text("\(def.roundCount) rounds · \(def.sportKey.replacingOccurrences(of: "_", with: "."))")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(JuicdTheme.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(JuicdTheme.textTertiary)
                                }
                                .padding(16)
                                .background {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [JuicdTheme.cardElevated, JuicdTheme.card],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let last = viewModel.lastResult {
                    Card(title: "Last round", systemImage: "chart.bar.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Day \(last.roundIndex) · score \(last.userScore) · rank #\(last.rank) of 100")
                                .foregroundStyle(JuicdTheme.textPrimary)
                                .font(.system(size: 15, weight: .semibold))
                            if last.bonusAwarded > 0 {
                                Text("+\(last.bonusAwarded) season pts")
                                    .foregroundStyle(JuicdTheme.brand)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            if last.completedTournament {
                                Text("You won the cup!")
                                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.35))
                                    .fontWeight(.bold)
                            } else if last.eliminated {
                                Text("Eliminated — bonus applied from your run.")
                                    .foregroundStyle(JuicdTheme.textSecondary)
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
    }

    @ViewBuilder
    private func activeBracketCard(def: WeeklyBracketDefinition, p: UserBracketProgress) -> some View {
        Card(title: def.name, systemImage: def.iconSystemName, style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                if p.completed {
                    Text("Tournament complete. Total bonus: \(p.totalBonusAwarded) pts")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.system(size: 15, weight: .medium))
                    Button("Leave & join another") {
                        viewModel.leave()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                } else if p.eliminated {
                    Text("Eliminated. Bonus earned: \(p.totalBonusAwarded) pts")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.system(size: 15, weight: .medium))
                    Button("Leave & join another") {
                        viewModel.leave()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                } else {
                    Text("Next: day \(p.nextRoundToPlay) of \(def.roundCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textPrimary)
                    Text("Each day you’re ranked against 100 competitors. Finish in the top 50 to advance.")
                        .foregroundStyle(JuicdTheme.textSecondary)
                        .font(.system(size: 14, weight: .medium))
                        .lineSpacing(3)

                    Button {
                        viewModel.playNextRound()
                    } label: {
                        Text("Simulate today’s round")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                    .controlSize(.large)

                    Button("Leave tournament", role: .destructive) {
                        viewModel.leave()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }
}
