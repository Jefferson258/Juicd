import SwiftUI

struct PlayView: View {
    @ObservedObject var viewModel: PlayViewModel

    var body: some View {
        ScrollView {
            SectionColumn {
                BrandHeader(
                    title: "Play",
                    subtitle: "Scroll props by category — live moneyline when ODDS_API_KEY is set.",
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

                ForEach(viewModel.ribbons) { ribbon in
                    propRibbonSection(ribbon)
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

    private func propRibbonSection(_ ribbon: PlayPropRibbon) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(ribbon.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(JuicdTheme.textPrimary)
                if let sub = ribbon.subtitle {
                    Text(sub)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JuicdTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(ribbon.props) { prop in
                        propBetSquare(prop)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 8)
            }
        }
    }

    private func propBetSquare(_ prop: PlayPropBet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prop.leagueTag)
                .font(.caption2.weight(.black))
                .foregroundStyle(JuicdTheme.brand)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(JuicdTheme.brand.opacity(0.18))
                .clipShape(Capsule())

            Text(prop.athleteOrTeam)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(JuicdTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(prop.matchup)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JuicdTheme.textSecondary)
                .lineLimit(1)

            Text(prop.propDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JuicdTheme.textSecondary)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(prop.lineText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JuicdTheme.textSecondary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(JuicdTheme.textSecondary.opacity(0.5))
                Text(prop.pickLabel)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(JuicdTheme.textPrimary)
            }

            Spacer(minLength: 0)

            Text(String(format: "%.2f", prop.oddsDecimal))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.brand)
        }
        .padding(12)
        .frame(width: 152, alignment: .leading)
        .frame(minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(JuicdTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
