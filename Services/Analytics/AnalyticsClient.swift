//
//  AnalyticsClient.swift
//  Juicd
//
//  Kept in sync with LaunchPilot kits/analytics/Sources/AnalyticsCore/AnalyticsClient.swift.
//
//  The facade `AnalyticsService` wraps. Invalid event/param names never reach a
//  provider (only surfaced via `onInvalidEvent`) — this keeps the naming
//  convention in LaunchPilot docs/ANALYTICS.md §4 actually enforced.
//

import Foundation

final class AnalyticsClient {
    private let providers: [AnalyticsProvider]
    private let isEnabled: Bool
    private let redactPII: Bool
    private let onInvalidEvent: ((String) -> Void)?

    init(
        providers: [AnalyticsProvider],
        isEnabled: Bool = true,
        redactPII: Bool = true,
        onInvalidEvent: ((String) -> Void)? = nil
    ) {
        self.providers = providers
        self.isEnabled = isEnabled
        self.redactPII = redactPII
        self.onInvalidEvent = onInvalidEvent
    }

    @discardableResult
    func log(_ name: String, params: [String: AnalyticsValue] = [:]) -> Bool {
        guard isEnabled else { return false }
        guard AnalyticsEventNaming.isValidEventName(name) else {
            onInvalidEvent?("invalid event name: \(name)")
            return false
        }
        for key in params.keys where !AnalyticsEventNaming.isValidParamKey(key) {
            onInvalidEvent?("invalid param key: \(key) on event \(name)")
        }
        let cleanParams = redactPII ? AnalyticsPrivacy.redactingLikelyPII(from: params) : params
        let event = AnalyticsEvent(name: name, params: cleanParams)
        for provider in providers {
            provider.track(event)
        }
        return true
    }
}
