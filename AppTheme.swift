import SwiftUI

enum JuicdTheme {
    /// Primary accent (cyan)
    static let brand = Color(red: 0.32, green: 0.82, blue: 1.0)
    static let brand2 = Color(red: 0.18, green: 0.58, blue: 0.98)
    static let brandMuted = Color(red: 0.22, green: 0.45, blue: 0.62)

    /// Near-black canvas (high-contrast “portfolio” style)
    static let canvasDeep = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let slateBackground = Color(red: 0.07, green: 0.07, blue: 0.09)

    /// Card / surface layers
    static let card = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let cardElevated = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let strokeSubtle = Color.white.opacity(0.06)
    static let strokeHighlight = Color.white.opacity(0.1)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.38)

    /// Trend / P&L (muted neon — not system green/red)
    static let trendUp = Color(red: 0.35, green: 0.92, blue: 0.58)
    static let trendDown = Color(red: 0.98, green: 0.38, blue: 0.42)

    static func ribbonAccent(ribbonId: String) -> Color {
        switch ribbonId {
        case "live_api": return Color(red: 0.2, green: 0.95, blue: 0.75)
        case "popular", "popular_nba", "popular_cbb", "popular_mbb": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "popular_nfl": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "popular_mlb": return Color(red: 0.85, green: 0.2, blue: 0.22)
        case "popular_nhl": return Color(red: 0.35, green: 0.75, blue: 0.95)
        case "popular_soccer", "popular_wsoc": return Color(red: 0.25, green: 0.78, blue: 0.45)
        case "nba": return Color(red: 0.9, green: 0.28, blue: 0.22)
        case "nfl": return Color(red: 0.2, green: 0.45, blue: 0.95)
        case "mlb": return Color(red: 0.85, green: 0.2, blue: 0.22)
        case "nhl": return Color(red: 0.35, green: 0.75, blue: 0.95)
        case "soccer": return Color(red: 0.25, green: 0.78, blue: 0.45)
        case "cbb", "mbb": return Color(red: 0.95, green: 0.4, blue: 0.18)
        case "womens_soccer": return Color(red: 0.45, green: 0.85, blue: 0.4)
        default: return brand
        }
    }

    static func ribbonIcon(ribbonId: String) -> String {
        switch ribbonId {
        case "live_api": return "antenna.radiowaves.left.and.right"
        case "popular", "popular_nba", "nba", "cbb", "mbb": return "basketball.fill"
        case "popular_nfl", "nfl": return "football.fill"
        case "popular_mlb", "mlb": return "baseball.fill"
        case "popular_nhl", "nhl": return "sportscourt.fill"
        case "popular_soccer", "soccer": return "soccerball"
        case "popular_wsoc", "womens_soccer": return "soccerball"
        default: return "line.3.horizontal.decrease.circle.fill"
        }
    }

    /// League pill on prop tiles (by tag from stub data).
    static func leaguePillColor(tag: String) -> Color {
        switch tag.uppercased() {
        case "NBA": return Color(red: 0.95, green: 0.35, blue: 0.18)
        case "NFL": return Color(red: 0.25, green: 0.48, blue: 0.98)
        case "MLB": return Color(red: 0.92, green: 0.22, blue: 0.24)
        case "NHL": return Color(red: 0.3, green: 0.72, blue: 0.95)
        case "EPL", "UCL", "MLS", "SOC": return Color(red: 0.28, green: 0.82, blue: 0.48)
        case "CBB", "MBB": return Color(red: 0.92, green: 0.42, blue: 0.2)
        case "NWSL", "WSL": return Color(red: 0.5, green: 0.88, blue: 0.45)
        case "LIVE": return Color(red: 0.25, green: 0.95, blue: 0.75)
        default: return brand
        }
    }
}

// MARK: - Screen backdrop

/// Soft radial glows — common pattern in modern sports / fantasy apps.
struct JuicdScreenBackground: View {
    var body: some View {
        ZStack {
            JuicdTheme.canvasDeep
            RadialGradient(
                colors: [
                    JuicdTheme.brand.opacity(0.07),
                    Color.clear
                ],
                center: UnitPoint(x: 0.2, y: 0.05),
                startRadius: 40,
                endRadius: 380
            )
            LinearGradient(
                colors: [
                    JuicdTheme.slateBackground.opacity(0.45),
                    JuicdTheme.canvasDeep
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main tab chrome (shared “pop” across Play / Dashboard / Tourney / Friends / Profile)

/// Compact accent under the safe area — ties all five tabs to the same modern look as Play.
struct JuicdTabScreenAccent: View {
    var body: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            JuicdTheme.brand.opacity(0.85),
                            JuicdTheme.brand2.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 64, height: 3)
                .shadow(color: JuicdTheme.brand.opacity(0.2), radius: 6, y: 0)
            Spacer()
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Cards

struct Card: View {
    let title: String?
    let systemImage: String?
    var style: CardStyle = .standard
    let content: AnyView

    enum CardStyle {
        case standard
        case hero
    }

    init(title: String? = nil, systemImage: String? = nil, style: CardStyle = .standard, @ViewBuilder content: () -> some View) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 12) {
                    if let systemImage {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [JuicdTheme.brand.opacity(0.35), JuicdTheme.brand2.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            Image(systemName: systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(JuicdTheme.brand)
                        }
                        .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(JuicdTheme.textPrimary)
                }
            }
            content
        }
        .padding(style == .hero ? 22 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: style == .hero ? 24 : 22, style: .continuous)
                .fill(JuicdTheme.card)
                .shadow(color: Color.black.opacity(0.35), radius: style == .hero ? 18 : 12, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: style == .hero ? 24 : 22, style: .continuous)
                .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
        }
    }
}

// MARK: - Headers

struct BrandHeader: View {
    let title: String
    let subtitle: String?
    var centered: Bool = false
    var kicker: String? = nil

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 10) {
            if let kicker {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(JuicdTheme.textTertiary)
            }
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(JuicdTheme.textPrimary)
                .multilineTextAlignment(centered ? .center : .leading)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .padding(.bottom, 8)
    }
}

/// Readable column on wide phones; generous vertical rhythm.
struct SectionColumn<Content: View>: View {
    var spacing: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: spacing) {
            content()
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ribbon (Play tab)

struct PlayRibbonHeader: View {
    let ribbon: PlayPropRibbon
    /// When set, the **entire** header row (icon + title + chevron) opens that league filter on Play.
    var onChevronTap: (() -> Void)?

    private var accent: Color { JuicdTheme.ribbonAccent(ribbonId: ribbon.id) }

    @ViewBuilder
    var body: some View {
        if let action = onChevronTap {
            Button(action: action) {
                headerRow(showChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(ribbon.title) board")
        } else {
            headerRow(showChevron: false)
        }
    }

    @ViewBuilder
    private func headerRow(showChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.45), accent.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: JuicdTheme.ribbonIcon(ribbonId: ribbon.id))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(ribbon.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)
                if let sub = ribbon.subtitle {
                    Text(sub)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JuicdTheme.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(JuicdTheme.textTertiary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Inputs (Sign-in / Friends)

struct JuicdInputField<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .foregroundStyle(JuicdTheme.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(JuicdTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(JuicdTheme.strokeSubtle, lineWidth: 1)
                    )
            }
    }
}
