import Combine
import GoogleMobileAds
import SwiftUI
import UIKit

enum JuicdBannerPlacement {
    /// Thin adaptive strip in a scrolling feed.
    case inlineFeed
    /// Full-width strip above the tab bar.
    case anchoredBottom
    /// 320×100 large banner for the in-feed sponsored card (~half of the old 300×250 MREC).
    case largeBanner
}

/// Owns one AdMob `BannerView` and loads it as soon as the slot is created,
/// *before* anything is drawn. Slots render nothing until `isLoaded` flips on
/// `bannerViewDidReceiveAd`, so a no-fill / failed request collapses to zero
/// height (no blank box, no stack spacing).
final class JuicdBannerAdLoader: NSObject, ObservableObject, BannerViewDelegate {
    @Published private(set) var isLoaded = false

    let bannerView: BannerView
    private let onPaidImpression: () -> Void
    private var didRecord = false
    private var refreshTimer: Timer?
    /// Failures so far. Each one schedules another load, up to 4 retries.
    private var failureCount = 0
    private var retryWork: DispatchWorkItem?

    init(
        adUnitID: String = JuicdAdsConfig.creativeBannerUnitID,
        placement: JuicdBannerPlacement,
        refreshInterval: TimeInterval? = nil,
        onPaidImpression: @escaping () -> Void = {}
    ) {
        // Must run before the first request: applies maxAdContentRating = .general.
        JuicdMobileAds.start()
        let adSize: AdSize
        switch placement {
        case .largeBanner:
            adSize = AdSizeLargeBanner
        case .inlineFeed, .anchoredBottom:
            adSize = currentOrientationAnchoredAdaptiveBanner(width: Self.bannerWidth(for: placement))
        }
        bannerView = BannerView(adSize: adSize)
        self.onPaidImpression = onPaidImpression
        super.init()
        bannerView.adUnitID = adUnitID
        bannerView.delegate = self
        bannerView.rootViewController = JuicdBannerAdView.keyRootViewController()
        bannerView.load(JuicdMobileAds.nonPersonalizedRequest())
        if let refreshInterval, refreshInterval >= 30 {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.bannerView.load(JuicdMobileAds.nonPersonalizedRequest())
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
        retryWork?.cancel()
    }

    static func bannerWidth(for placement: JuicdBannerPlacement) -> CGFloat {
        let screen = UIScreen.main.bounds.width
        switch placement {
        case .inlineFeed:
            return max(screen - 32, 320)
        case .anchoredBottom:
            return max(screen, 320)
        case .largeBanner:
            return 320
        }
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        retryWork?.cancel()
        failureCount = 0
        isLoaded = true
        guard !didRecord else { return }
        didRecord = true
        onPaidImpression()
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        // Collapse (or stay collapsed) — never leave an empty ad box on screen.
        isLoaded = false
        failureCount += 1
        #if DEBUG
        print("[Juicd ads] banner failed (\(failureCount)): \(error.localizedDescription)")
        #endif
        guard failureCount <= 4 else { return }
        retryWork?.cancel()
        let attempt = failureCount
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.bannerView.load(JuicdMobileAds.nonPersonalizedRequest())
        }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 2, execute: work)
    }
}

/// Hosts the loader's `BannerView`. Only inserted once an ad has loaded.
/// Simulator/DEBUG loads Google Test Ad creatives.
struct JuicdBannerAdView: UIViewRepresentable {
    @ObservedObject var loader: JuicdBannerAdLoader

    func makeUIView(context: Context) -> BannerView {
        loader.bannerView.rootViewController = Self.keyRootViewController()
        return loader.bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = Self.keyRootViewController()
    }

    static func keyRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

/// Full-width strip above the custom tab bar. Height matches AdMob’s anchored adaptive size.
/// Renders nothing (zero height) until an ad has loaded.
struct JuicdAnchoredBannerSlot: View {
    @StateObject private var loader = JuicdBannerAdLoader(placement: .anchoredBottom, refreshInterval: 60)

    private var bannerHeight: CGFloat {
        loader.bannerView.adSize.size.height
    }

    var body: some View {
        if loader.isLoaded {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(JuicdTheme.strokeSubtle)
                    .frame(height: 1)
                JuicdBannerAdView(loader: loader)
                    .frame(maxWidth: .infinity)
                    .frame(height: bannerHeight)
                    .accessibilityIdentifier("ad-banner-anchored")
            }
            .background(JuicdTheme.canvasDeep)
        }
    }
}

/// 320×100 AdMob large banner inside the sponsored-card chrome (includes X).
/// Collapses to nothing (zero height, no stack spacing) until AdMob returns an ad;
/// a no-fill or failed request never shows the empty "Sponsored" chrome.
struct JuicdSponsoredBannerCard: View {
    var onDismiss: () -> Void = {}
    @StateObject private var loader: JuicdBannerAdLoader

    init(onPaidImpression: @escaping () -> Void = {}, onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
        _loader = StateObject(wrappedValue: JuicdBannerAdLoader(
            placement: .largeBanner,
            onPaidImpression: onPaidImpression
        ))
    }

    var body: some View {
        if loader.isLoaded {
            card
        }
    }

    private var card: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sponsored")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(JuicdTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                JuicdBannerAdView(loader: loader)
                    .frame(width: 320, height: 100)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(12)
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
