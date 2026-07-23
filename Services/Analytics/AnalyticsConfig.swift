//
//  AnalyticsConfig.swift
//  Juicd
//
//  Reads analytics config from (1) environment variables, then (2) Info.plist,
//  then a default — same pattern as SupabaseConfig.swift in this folder.
//  Env vars: set in Xcode scheme (Run → Arguments → Environment Variables).
//  Info.plist: add the keys below under target Info → Custom iOS Target
//  Properties for device builds where env vars aren't present.
//
//  None of these values are secrets (a provider "app ID" is not an API key),
//  but keep them out of git anyway per this repo's convention until a real
//  provider is configured.
//

import Foundation

enum JuicdAnalyticsConfig {
    /// Supported: `none`, `debug`, `debug+supabase`, `supabase`, `telemetrydeck`,
    /// `supabase+telemetrydeck`. Default: `supabase` when URL+anon key are configured, else `debug`.
    static var provider: String {
        let raw = (env("JUICD_ANALYTICS_PROVIDER") ?? plist("JUICD_ANALYTICS_PROVIDER"))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let raw, !raw.isEmpty {
            return raw
        }
        return SupabaseConfig.isConfigured ? "supabase" : "debug"
    }

    /// Non-secret app identifier some providers need (e.g. TelemetryDeck app ID). Empty when unset.
    static var appID: String {
        (env("JUICD_ANALYTICS_APP_ID") ?? plist("JUICD_ANALYTICS_APP_ID") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Master kill switch. Defaults on; set JUICD_ANALYTICS_ENABLED=0 to disable everywhere.
    static var isEnabled: Bool {
        let raw = (env("JUICD_ANALYTICS_ENABLED") ?? plist("JUICD_ANALYTICS_ENABLED") ?? "1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !(raw == "0" || raw.lowercased() == "false")
    }

    /// Where the local, never-uploaded debug JSONL log lives (Documents dir), or nil to disable file logging.
    static var debugFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent("analytics-debug-events.jsonl")
    }

    private static func env(_ key: String) -> String? {
        let v = ProcessInfo.processInfo.environment[key]
        return (v != nil && !v!.isEmpty) ? v : nil
    }

    private static func plist(_ key: String) -> String? {
        (Bundle.main.infoDictionary?[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
