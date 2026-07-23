//
//  SupabaseAnalyticsProvider.swift
//  Juicd
//
//  Fire-and-forget POST to Supabase REST (juicd_analytics_events). Uses the
//  signed-in user's JWT when available, otherwise the anon key. See LaunchPilot
//  docs/HOW_TO_VIEW_ANALYTICS.md for querying dashboards.
//

import Foundation

final class SupabaseAnalyticsProvider: AnalyticsProvider {
    let identifier = "supabase"

    /// One UUID per process lifetime (not persisted across launches).
    private static let processSessionId = UUID().uuidString

    func track(_ event: AnalyticsEvent) {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.projectURL else { return }

        var body: [String: Any] = [
            "event_name": event.name,
            "params": Self.jsonObject(from: event.params),
            "session_id": Self.processSessionId,
            "app_version": Self.appVersion,
            "build": Self.buildNumber,
        ]
        if let userId = SupabaseAuthService.currentSession?.userId {
            body["user_id"] = userId.uuidString
        }

        guard let url = URL(string: base.absoluteString + "/rest/v1/juicd_analytics_events") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.bearerToken())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }
        req.httpBody = payload

        URLSession.shared.dataTask(with: req) { _, response, _ in
            #if DEBUG
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[SupabaseAnalyticsProvider] POST failed status=\(http.statusCode) event=\(event.name)")
            }
            #endif
        }.resume()
    }

    // MARK: - Metadata

    private static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }

    private static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
    }

    private static func bearerToken() -> String {
        SupabaseAuthService.accessToken ?? SupabaseConfig.anonKey
    }

    private static func jsonObject(from params: [String: AnalyticsValue]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in params {
            switch value {
            case .string(let s): out[key] = s
            case .int(let i): out[key] = i
            case .double(let d): out[key] = d
            case .bool(let b): out[key] = b
            }
        }
        return out
    }
}
