import Foundation

enum IssueReportError: Error, Equatable, LocalizedError {
    case empty
    case notConfigured
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Write a short description of what went wrong."
        case .notConfigured:
            return "Reporting isn’t available in this build."
        case .server:
            return "Couldn’t send the report. Try again in a moment."
        }
    }
}

/// Swap `IssueReportService.sink` to send reports somewhere else
/// (GitHub, email, LaunchPilot). Default posts to Supabase
/// `juicd_issue_reports` and a breadcrumb on `juicd_app_errors`.
enum IssueReportService {
    static let maxBodyLength = 4000
    static var sink: any IssueReportSink = JuicdSupabaseIssueReportSink()

    static func preparedBody(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IssueReportError.empty }
        return String(trimmed.prefix(maxBodyLength))
    }

    static func submit(body: String, screen: String = "profile") async throws {
        let text = try preparedBody(body)
        AnalyticsService.shared.log("issue_report", params: [
            "char_count": .int(text.count),
            "screen": .string(String(screen.prefix(40))),
        ])
        try await sink.submit(body: text, screen: screen)
    }
}

protocol IssueReportSink: Sendable {
    func submit(body: String, screen: String) async throws
}

/// Dedicated table first; always also writes `juicd_app_errors` so existing
/// spike watches can see volume before a LaunchPilot consumer exists.
struct JuicdSupabaseIssueReportSink: IssueReportSink {
    func submit(body: String, screen: String) async throws {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.projectURL else {
            throw IssueReportError.notConfigured
        }

        AppErrorLogger.log(
            severity: .info,
            message: "user_issue_report: \(String(body.prefix(200)))",
            screen: screen,
            extra: [
                "kind": .string("user_report"),
                "body": .string(body),
            ]
        )

        var payload: [String: Any] = [
            "body": body,
            "screen": String(screen.prefix(80)),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "platform": "ios",
        ]
        if let userId = SupabaseAuthService.currentSession?.userId {
            payload["user_id"] = userId.uuidString
        }

        guard let url = URL(string: base.absoluteString + "/rest/v1/juicd_issue_reports") else {
            throw IssueReportError.notConfigured
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseAuthService.accessToken ?? SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        // 404 = table not applied yet; breadcrumb on juicd_app_errors already landed.
        if status == 404 { return }
        guard (200...299).contains(status) else {
            throw IssueReportError.server(status)
        }
    }
}
