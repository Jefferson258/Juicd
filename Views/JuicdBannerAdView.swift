import GoogleMobileAds
import SwiftUI
import UIKit

enum JuicdBannerPlacement {
    /// Thin adaptive strip in a scrolling feed.
    case inlineFeed
    /// Full-width strip above the tab bar.
    case anchoredBottom
    /// 300×250 box (MREC) for the in-feed sponsored card.
    case mediumRectangle
}

/// Adaptive AdMob banner. Simulator/DEBUG loads Google Test Ad creatives.
struct JuicdBannerAdView: UIViewRepresentable {
    var adUnitID: String = JuicdAdsConfig.creativeBannerUnitID
    var placement: JuicdBannerPlacement = .inlineFeed
    /// Google’s minimum refresh is 30s. `nil` loads once (in-feed).
    var refreshInterval: TimeInterval? = nil
    var onPaidImpression: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPaidImpression: onPaidImpression)
    }

    func makeUIView(context: Context) -> BannerView {
        JuicdMobileAds.start()
        let banner: BannerView
        switch placement {
        case .mediumRectangle:
            banner = BannerView(adSize: AdSizeMediumRectangle)
        case .inlineFeed, .anchoredBottom:
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: bannerWidth)
            banner = BannerView(adSize: adSize)
        }
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.keyRootViewController()
        banner.load(JuicdMobileAds.nonPersonalizedRequest())
        if let refreshInterval, refreshInterval >= 30 {
            context.coordinator.startRefresh(banner, interval: refreshInterval)
        }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = Self.keyRootViewController()
    }

    static func dismantleUIView(_ uiView: BannerView, coordinator: Coordinator) {
        coordinator.stopRefresh()
    }

    private var bannerWidth: CGFloat {
        let screen = UIScreen.main.bounds.width
        switch placement {
        case .inlineFeed:
            return max(screen - 32, 320)
        case .anchoredBottom:
            return max(screen, 320)
        case .mediumRectangle:
            return 300
        }
    }

    static func keyRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onPaidImpression: () -> Void
        private var didRecord = false
        private var refreshTimer: Timer?
        private weak var banner: BannerView?

        init(onPaidImpression: @escaping () -> Void) {
            self.onPaidImpression = onPaidImpression
        }

        func startRefresh(_ banner: BannerView, interval: TimeInterval) {
            stopRefresh()
            self.banner = banner
            refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let banner = self?.banner else { return }
                banner.load(JuicdMobileAds.nonPersonalizedRequest())
            }
        }

        func stopRefresh() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            guard !didRecord else { return }
            didRecord = true
            onPaidImpression()
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[Juicd ads] banner failed: \(error.localizedDescription)")
            #endif
        }
    }
}

/// Full-width strip above the custom tab bar. Height matches AdMob’s anchored adaptive size.
struct JuicdAnchoredBannerSlot: View {
    private var bannerHeight: CGFloat {
        let width = max(UIScreen.main.bounds.width, 320)
        return currentOrientationAnchoredAdaptiveBanner(width: width).size.height
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(JuicdTheme.strokeSubtle)
                .frame(height: 1)
            JuicdBannerAdView(placement: .anchoredBottom, refreshInterval: 60)
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
                .accessibilityIdentifier("ad-banner-anchored")
        }
        .background(JuicdTheme.canvasDeep)
    }
}

/// 300×250 AdMob box inside the same sponsored-card chrome as the native placeholder (includes X).
struct JuicdSponsoredBannerCard: View {
    var onPaidImpression: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sponsored")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                JuicdBannerAdView(placement: .mediumRectangle, onPaidImpression: onPaidImpression)
                    .frame(width: 300, height: 250)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(JuicdTheme.card.opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(JuicdTheme.brand.opacity(0.45), lineWidth: 1.2)
                    }
            }

            Button(action: onDismiss) {
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
        .accessibilityIdentifier("ad-sponsored-card")
    }
}

/// Play / Tourney in-feed slot. Hidden when using the bottom-strip layout.
struct JuicdInFeedAdSlot: View {
    let creative: JuicdDevAdCreative
    var onDismiss: () -> Void

    var body: some View {
        switch JuicdAdsConfig.presentation {
        case .nativeCard:
            JuicdNativeAdPlaceholder(creative: creative, onFirstView: {
                JuicdAdsDev.recordImpression()
            }, onDismiss: onDismiss)
        case .cardBanner:
            JuicdSponsoredBannerCard(
                onPaidImpression: { JuicdAdsDev.recordImpression() },
                onDismiss: onDismiss
            )
        case .bottomBanner:
            EmptyView()
        }
    }
}
