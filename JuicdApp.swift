import SwiftUI
import UIKit

@main
struct JuicdApp: App {
    @StateObject private var repository = InMemoryJuicdRepository.shared

    init() {
        JuicdMobileAds.start()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-juicd-ads-on") {
            UserDefaults.standard.set(true, forKey: JuicdAdsConfig.enabledStorageKey)
        }
        if args.contains("-juicd-ads-off") {
            UserDefaults.standard.set(false, forKey: JuicdAdsConfig.enabledStorageKey)
        }
        // Opaque bar, no blur/material — avoids “liquid glass” if any system tab UI appears.
        // Main chrome uses a SwiftUI custom bar (see RootView) like Corvim.
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.17, alpha: 1)
        tab.backgroundEffect = nil
        tab.shadowColor = .clear
        tab.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.55, alpha: 1)
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.55, alpha: 1)]
        tab.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.32, green: 0.82, blue: 1.0, alpha: 1)
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0.32, green: 0.82, blue: 1.0, alpha: 1)]
        let bar = UITabBar.appearance()
        bar.standardAppearance = tab
        bar.scrollEdgeAppearance = tab
        bar.isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topTrailing) {
                RootView(repository: repository)
                AnalyticsDebugOverlay()
            }
            .preferredColorScheme(ColorScheme.dark)
            .onAppear {
                AnalyticsService.logAppOpen()
            }
        }
    }
}
