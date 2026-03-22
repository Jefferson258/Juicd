import SwiftUI

enum JuicdTheme {
    static let brand = Color(red: 0.32, green: 0.78, blue: 1.0)
    static let brand2 = Color(red: 0.15, green: 0.55, blue: 0.98)
    /// Slate gray app canvas (not pure black).
    static let slateBackground = Color(red: 0.19, green: 0.22, blue: 0.27)
    static let card = Color(red: 0.26, green: 0.30, blue: 0.36)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
}

struct Card: View {
    let title: String?
    let systemImage: String?
    let content: AnyView

    init(title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> some View) {
        self.title = title
        self.systemImage = systemImage
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(JuicdTheme.brand2)
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JuicdTheme.textPrimary)
                }
            }
            content
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

struct BrandHeader: View {
    let title: String
    let subtitle: String?
    var centered: Bool = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [JuicdTheme.brand, JuicdTheme.brand2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .multilineTextAlignment(centered ? .center : .leading)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .multilineTextAlignment(centered ? .center : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Keeps a readable column on wide phones and centers content.
struct SectionColumn<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            content()
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}
