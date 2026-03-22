import SwiftUI

struct PlayView: View {
    @ObservedObject var viewModel: PlayViewModel

    var body: some View {
        ScrollView {
            SectionColumn(spacing: 22) {
                BrandHeader(
                    title: "Play",
                    subtitle: "Browse props by league. Add ODDS_API_KEY for a live moneyline tile.",
                    centered: true,
                    kicker: "Today’s board"
                )

                if let profile = viewModel.profile {
                    bankrollHero(points: profile.availableDailyPoints)
                }

                oddsToolbar

                ForEach(viewModel.ribbons) { ribbon in
                    ribbonBlock(ribbon)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .background(JuicdScreenBackground())
        .task {
            await viewModel.refreshLiveOddsLine()
        }
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
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, JuicdTheme.brand],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("pts")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [JuicdTheme.brand.opacity(0.45), JuicdTheme.strokeSubtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 12)
        }
    }

    private func ribbonBlock(_ ribbon: PlayPropRibbon) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PlayRibbonHeader(ribbon: ribbon)

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
        }
    }

    private func propBetSquare(_ prop: PlayPropBet, ribbonId: String) -> some View {
        let pillColor = JuicdTheme.leaguePillColor(tag: prop.leagueTag)
        let ribbonAccent = JuicdTheme.ribbonAccent(ribbonId: ribbonId)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
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
                Text("Odds")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textTertiary)
                Spacer()
                Text(String(format: "%.2f", prop.oddsDecimal))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.brand)
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
            }
            .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
        }
    }
}
