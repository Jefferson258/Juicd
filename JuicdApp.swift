import SwiftUI
import UIKit

@main
struct JuicdApp: App {
    @StateObject private var repository = InMemoryJuicdRepository.shared

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.17, alpha: 1)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository)
                .preferredColorScheme(.dark)
        }
    }
}
