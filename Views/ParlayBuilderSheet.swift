import SwiftUI

struct ParlayBuilderSheet: View {
    @ObservedObject var viewModel: PlayViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.maxStakePoints <= 0 {
                        Text("You don’t have any daily points left. Come back after the next refill.")
                            .foregroundStyle(JuicdTheme.textSecondary)
                            .font(.system(size: 15, weight: .medium))
                    } else {
                        legsSection
                        stakeSection
                        summarySection
                        addLegButton
                    }
                }
                .padding(20)
            }
            .background(JuicdScreenBackground())
            .onAppear {
                viewModel.clampStakeToBalance()
            }
            .navigationTitle(viewModel.parlayLegs.count <= 1 ? "Place bet" : "Parlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.showParlayBuilder = false
                        viewModel.pickingAdditionalLeg = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.maxStakePoints > 0 {
                    Button {
                        viewModel.placeBetTapped()
                    } label: {
                        Text("Place \(viewModel.stakePoints) pts")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JuicdTheme.brand)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(JuicdTheme.canvasDeep.opacity(0.95))
                }
            }
        }
    }

    private var legsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legs")
                .font(.caption.weight(.heavy))
                .foregroundStyle(JuicdTheme.textTertiary)
            ForEach(Array(viewModel.parlayLegs.enumerated()), id: \.element.id) { index, prop in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JuicdTheme.brand)
                        .frame(width: 20, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prop.athleteOrTeam)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("\(prop.pickLabel) · \(prop.lineText)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(JuicdTheme.textSecondary)
                        Text(String(format: "%.2f", prop.juicdEffectiveDecimalOdds))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JuicdTheme.brand)
                    }
                    Spacer()
                    Button {
                        viewModel.removeParlayLeg(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(JuicdTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(JuicdTheme.card))
            }
        }
    }

    private var stakeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stake")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(JuicdTheme.textTertiary)
                Spacer()
                Text("Max \(viewModel.maxStakePoints) pts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JuicdTheme.textTertiary)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.stakePoints) },
                    set: { viewModel.stakePoints = Int($0.rounded()) }
                ),
                in: 1...Double(max(1, viewModel.maxStakePoints)),
                step: 1
            )
            .tint(JuicdTheme.brand)
            Text("\(viewModel.stakePoints) pts")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(JuicdTheme.canvasDeep.opacity(0.5)))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Combined odds")
                Spacer()
                Text(String(format: "%.2f", viewModel.impliedParlayDecimal))
                    .fontWeight(.bold)
                    .foregroundStyle(JuicdTheme.brand)
            }
            .font(.system(size: 14, weight: .medium))
            HStack {
                Text("Est. season pts if win")
                Spacer()
                Text("+\(viewModel.estimatedSeasonPointsIfWin) pts")
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.55))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(JuicdTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(JuicdTheme.card.opacity(0.6)))
    }

    private var addLegButton: some View {
        Button {
            viewModel.beginAddLeg()
            viewModel.showParlayBuilder = false
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add another pick (parlay)")
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(JuicdTheme.brand)
        .disabled(viewModel.parlayLegs.count >= 8)
    }
}
