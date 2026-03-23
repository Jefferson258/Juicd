import SwiftUI

/// In-feed native-style slot. Clearly labeled; optional dismiss control (dev).
struct JuicdNativeAdPlaceholder: View {
    let creative: JuicdDevAdCreative
    var onFirstView: () -> Void
    var onDismiss: () -> Void

    @State private var didRecordImpression = false

    private var accent: Color {
        Color(red: creative.accent.r, green: creative.accent.g, blue: creative.accent.b)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.opacity(0.22))
                            .frame(width: 44, height: 44)
                        Image(systemName: creative.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sponsored")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(JuicdTheme.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text(creative.sponsorName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(JuicdTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(creative.headline)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(JuicdTheme.textPrimary)

                Text(creative.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(JuicdTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(creative.cta)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(accent.opacity(0.45), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }
            .padding(16)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(JuicdTheme.card.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(accent.opacity(0.25), lineWidth: 1)
                    }
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(JuicdTheme.textSecondary, JuicdTheme.cardElevated.opacity(0.95))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.top, 10)
            .accessibilityLabel("Dismiss ad")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sponsored. \(creative.sponsorName). \(creative.headline)")
        .onAppear {
            guard !didRecordImpression else { return }
            didRecordImpression = true
            onFirstView()
        }
    }
}
