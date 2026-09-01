import GoogleMobileAds
import SwiftUI
import UIKit

/// Adaptive banner in the Play feed. Uses test units until production IDs are in Info.plist.
struct JuicdBannerAdView: UIViewRepresentable {
    var adUnitID: String = JuicdAdsConfig.bannerUnitID
    var onPaidImpression: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPaidImpression: onPaidImpression)
    }

    func makeUIView(context: Context) -> BannerView {
        JuicdMobileAds.start()
        let width = max(UIScreen.main.bounds.width - 32, 320)
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.keyRootViewController()
        banner.load(JuicdMobileAds.nonPersonalizedRequest())
        return banner
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

    final class Coordinator: NSObject, BannerViewDelegate {
        let onPaidImpression: () -> Void
        private var didRecord = false

        init(onPaidImpression: @escaping () -> Void) {
            self.onPaidImpression = onPaidImpression
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
