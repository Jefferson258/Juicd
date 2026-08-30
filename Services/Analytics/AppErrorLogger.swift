//
//  AppErrorLogger.swift
//  Juicd
//
//  Client-side error breadcrumbs → juicd_app_errors (insert-only). Also mirrors
//  an `app_error` analytics event for dual visibility. See LaunchPilot
//  docs/HOW_TO_VIEW_ANALYTICS.md.
//

import Foundation
import os

enum AppErrorLogger {
    enum Severity: String {
        case info
        case warning
        case error
        case fatal
    }

    private static let maxAttempts = 3
    private static let retryDelaysNanoseconds: [UInt64] = [500_000_000, 1_500_000_000]
    private static let logger = Logger(subsystem: "com.juicd.analytics", category: "AppError")

    private struct HTTPFailure: Error {
        let statusCode: Int
    }

    /// Fire-and-forget insert + analytics dual-write; never throws to callers.
    static func log(
        severity: Severity,
        message: String,
        screen: String? = nil,
        extra: [String: AnalyticsValue] = [:]
    ) {
        let trimmed = String(message.prefix(500))
        guard !trimmed.isEmpty else { return }

        var analyticsParams: [String: AnalyticsValue] = [
            "severity": .string(severity.rawValue),
        ]
        if let screen, !screen.isEmpty {
            analyticsParams["screen"] = .string(String(screen.prefix(80)))
        }
        AnalyticsService.shared.log("app_error", params: analyticsParams)

        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.projectURL else { return }

        var body: [String: Any] = [
            "severity": severity.rawValue,
            "message": trimmed,
            "extra": jsonObject(from: extra),
            "app_version": appVersion,
            "build": buildNumber,
        ]
        if let screen, !screen.isEmpty {
            body["screen"] = String(screen.prefix(80))
        }
        if let userId = SupabaseAuthService.currentSession?.userId {
            body["user_id"] = userId.uuidString
        }

        guard let url = URL(string: base.absoluteString + "/rest/v1/juicd_app_errors") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearerToken())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }
        req.httpBody = payload

        Task {
            await Self.send(req, screen: screen)
        }
    }

    private static func send(_ request: URLRequest, screen: String?) async {
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
                    logger.error("app error POST failed after \(attempt) attempts screen=\(screen ?? "-", privacy: .public)")
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

    /// Alias kept for existing call sites.
    static func logError(
        severity: Severity,
        message: String,
        screen: String? = nil,
        extra: [String: AnalyticsValue] = [:]
    ) {
        log(severity: severity, message: message, screen: screen, extra: extra)
    }

    // MARK: - Private

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
