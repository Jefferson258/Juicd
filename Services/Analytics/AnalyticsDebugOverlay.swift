//
//  AnalyticsDebugOverlay.swift
//  Juicd
//
//  Manual QA / UITest hook for analytics without touching the network. Always
//  present in the view hierarchy (so a UITest can read it), visually
//  transparent unless launched with `-showAnalyticsDebugOverlay`.
//

import Combine
import SwiftUI

struct AnalyticsDebugOverlay: View {
    // The debug sink is a plain (non-ObservableObject) class, so nothing tells
    // SwiftUI to re-render this view when a new event is tracked elsewhere in
    // the app. A cheap periodic tick forces a re-read of `recordedEvents` so
    // the on-screen HUD (and any UITest reading its accessibility labels)
    // reflects events fired since the last render.
    @State private var tick = 0
    private let refreshTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var isVisible: Bool {
        ProcessInfo.processInfo.arguments.contains("-showAnalyticsDebugOverlay")
    }

    var body: some View {
        let events = AnalyticsService.debugSink.recordedEvents
        let count = events.count
        let last = events.last?.name ?? "none"

        return VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .accessibilityIdentifier("analytics-debug-count")
            Text(last)
                .accessibilityIdentifier("analytics-debug-last-event")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .padding(6)
        .background(.black.opacity(isVisible ? 0.6 : 0))
        .foregroundStyle(isVisible ? .white : .clear)
        .cornerRadius(6)
        .padding(8)
        .allowsHitTesting(false)
        .onReceive(refreshTimer) { _ in tick += 1 }
    }
}
