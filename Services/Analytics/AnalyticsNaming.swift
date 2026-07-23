//
//  AnalyticsNaming.swift
//  Juicd
//
//  Kept in sync with LaunchPilot kits/analytics/Sources/AnalyticsCore/AnalyticsNaming.swift.
//

import Foundation

/// Shared event-naming convention across every LaunchPilot product.
/// See LaunchPilot docs/ANALYTICS.md §4 "Event naming" for the rationale.
///
/// - Event names: lowercase `snake_case`, verb-ish/noun, 2–40 chars,
///   e.g. `app_open`, `tab_view`, `sign_in`, `screen_view`.
/// - Param keys: same charset, 1–40 chars.
enum AnalyticsEventNaming {
    private static let namePattern = try! NSRegularExpression(pattern: "^[a-z][a-z0-9_]{1,39}$")

    static func isValidEventName(_ name: String) -> Bool {
        matches(namePattern, name)
    }

    static func isValidParamKey(_ key: String) -> Bool {
        guard !key.isEmpty, key.count <= 40 else { return false }
        return matches(namePattern, key) || key.count == 1 && key.first!.isLowercase
    }

    private static func matches(_ regex: NSRegularExpression, _ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }
}
