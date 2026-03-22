import SwiftUI

struct PlayView: View {
    @ObservedObject var viewModel: PlayViewModel

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Play",
                    subtitle: "Today’s board — one live line from The Odds API (cached).",
                    centered: true
                )

                if let profile = viewModel.profile {
                    Card(title: "Bankroll", systemImage: "dollarsign.circle.fill") {
                        HStack {
                            Text("\(profile.availableDailyPoints) pts")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(JuicdTheme.brand)
                            Spacer()
                        }
                    }
                }

                HStack {
                    Text(viewModel.oddsStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                    Spacer()
                    Button {
                        Task { await viewModel.refreshLiveOddsLine() }
                    } label: {
                        if viewModel.isLoadingOdds {
                            ProgressView()
                                .tint(JuicdTheme.brand)
                        } else {
                            Label("Refresh odds", systemImage: "arrow.clockwise.circle.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .disabled(viewModel.isLoadingOdds)
                    .tint(JuicdTheme.brand)
                }

                ForEach(viewModel.boardRows) { row in
                    playRow(row)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(JuicdTheme.slateBackground.ignoresSafeArea())
        .task {
            await viewModel.refreshLiveOddsLine()
        }
    }

    private func playRow(_ row: PlayBoardRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(JuicdTheme.textPrimary)
                if row.isLiveFromAPI {
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(JuicdTheme.brand.opacity(0.25))
                        .foregroundStyle(JuicdTheme.brand)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(row.oddsText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.brand)
            }
            Text(row.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JuicdTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(JuicdTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
