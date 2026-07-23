//
//  AnalyticsEvent.swift
//  Juicd
//
//  Kept byte-for-byte in sync with LaunchPilot's tested reference implementation:
//  ~/Desktop/LaunchPilot/kits/analytics/Sources/AnalyticsCore/AnalyticsEvent.swift
//  See LaunchPilot docs/ANALYTICS.md for why this is copied rather than a package
//  dependency, and kits/analytics/README.md for the rollout checklist.
//

import Foundation

/// A single analytics event. Keep params small and non-identifying — see
/// LaunchPilot docs/ANALYTICS.md's privacy checklist (no email/name/exact
/// location/free-text user content).
struct AnalyticsEvent: Equatable, Codable {
    let name: String
    let params: [String: AnalyticsValue]
    let timestamp: Date

    init(name: String, params: [String: AnalyticsValue] = [:], timestamp: Date = Date()) {
        self.name = name
        self.params = params
        self.timestamp = timestamp
    }
}

/// JSON-safe scalar param value. Deliberately narrow (no nested objects/arrays)
/// so events stay flat, small, and easy to redact.
enum AnalyticsValue: Equatable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var stringValue: String {
        switch self {
        case .string(let v): return v
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .bool(let v): return String(v)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnalyticsValue")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}

extension AnalyticsValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(floatLiteral value: Double) { self = .double(value) }
}
