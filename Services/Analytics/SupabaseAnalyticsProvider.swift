//
//  SupabaseAnalyticsProvider.swift
//  Juicd
//
//  Fire-and-forget POST to Supabase REST (juicd_analytics_events). Uses the
//  signed-in user's JWT when available, otherwise the anon key. See LaunchPilot
//  docs/HOW_TO_VIEW_ANALYTICS.md for querying dashboards.
//

import Foundation
import os

final class SupabaseAnalyticsProvider: AnalyticsProvider {
    let identifier = "supabase"

    /// One UUID per process lifetime (not persisted across launches).
    private static let processSessionId = UUID().uuidString
    private static let maxAttempts = 3
    private static let retryDelaysNanoseconds: [UInt64] = [500_000_000, 1_500_000_000]
    private static let logger = Logger(subsystem: "com.juicd.analytics", category: "Supabase")

    private struct HTTPFailure: Error {
        let statusCode: Int
    }

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

        Task {
            await Self.send(req, eventName: event.name)
        }
    }

    private static func send(_ request: URLRequest, eventName: String) async {
        for attempt in 1...maxAttempts {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw HTTPFailure(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
                }
                return
            } catch {
                let shouldRetry: Bool = {
                    if let failure = error as? HTTPFailure {
                        return failure.statusCode == 408 || failure.statusCode == 429 || failure.statusCode >= 500
                    }
                    return (error as? URLError) != nil
                }()
                guard shouldRetry, attempt < maxAttempts else {
                    logger.error("analytics POST failed after \(attempt) attempts event=\(eventName, privacy: .public)")
                    return
                }
                do {
                    try await Task.sleep(nanoseconds: retryDelaysNanoseconds[attempt - 1])
                } catch {
                    return
                }
            }
        }
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
