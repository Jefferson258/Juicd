//
//  AnalyticsProvider.swift
//  Juicd
//
//  Kept in sync with LaunchPilot kits/analytics/Sources/AnalyticsCore/AnalyticsProvider.swift.
//

import Foundation

/// A backend that receives validated, redacted events. `AnalyticsService` registers
/// zero or more of these. Real network providers (TelemetryDeck, ...) conform to
/// this from this same folder; only network-free ones are always present.
protocol AnalyticsProvider {
    var identifier: String { get }
    func track(_ event: AnalyticsEvent)
}

/// Sends nowhere. Used when analytics is disabled/unconfigured so the facade
/// never has to special-case "no provider".
final class AnalyticsNoopProvider: AnalyticsProvider {
    let identifier = "noop"
    func track(_ event: AnalyticsEvent) {}
}
