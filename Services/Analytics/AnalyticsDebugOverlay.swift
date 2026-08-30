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
    @ObservedObject private var debugSink = AnalyticsService.debugSink

    private var isVisible: Bool {
        ProcessInfo.processInfo.arguments.contains("-showAnalyticsDebugOverlay")
    }

    var body: some View {
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(debugSink.eventCount)")
                .accessibilityIdentifier("analytics-debug-count")
            Text(debugSink.lastEventName)
                .accessibilityIdentifier("analytics-debug-last-event")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .padding(6)
        .background(.black.opacity(isVisible ? 0.6 : 0))
        .foregroundStyle(isVisible ? .white : .clear)
        .cornerRadius(6)
        .padding(8)
        .allowsHitTesting(false)
        .accessibilityHidden(false)
    }
}
