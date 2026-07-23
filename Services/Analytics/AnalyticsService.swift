//
//  AnalyticsService.swift
//  Juicd
//
//  Product analytics facade — the only type view/service code should call.
//  Wires config → providers → AnalyticsClient and exposes named convenience
//  events. See LaunchPilot docs/ANALYTICS.md and kits/analytics/README.md.
//

import Foundation

enum AnalyticsService {
    /// Exposed so QA, the debug overlay, and UITests can inspect events without network access.
    static let debugSink = AnalyticsDebugSink(
        fileURL: JuicdAnalyticsConfig.debugFileURL,
        logToConsole: isDebugBuild,
        loggerSubsystem: Bundle.main.bundleIdentifier ?? "com.jefferson258.juicd"
    )

    static let shared: AnalyticsClient = {
        var providers: [AnalyticsProvider] = []
        let provider = JuicdAnalyticsConfig.provider

        switch provider {
        case "none":
            break
        case "debug":
            providers.append(debugSink)
            appendSupabaseProvider(to: &providers)
        case "debug+supabase":
            providers.append(debugSink)
            appendSupabaseProvider(to: &providers)
        case "supabase":
            appendDebugSinkInDebugBuilds(to: &providers)
            appendSupabaseProvider(to: &providers)
        case "telemetrydeck":
            appendDebugSinkInDebugBuilds(to: &providers)
            appendTelemetryDeck(to: &providers)
        case "supabase+telemetrydeck":
            appendDebugSinkInDebugBuilds(to: &providers)
            appendSupabaseProvider(to: &providers)
            appendTelemetryDeck(to: &providers)
        default:
            // Unknown value → behave like configured default (supabase if wired).
            if SupabaseConfig.isConfigured {
                appendDebugSinkInDebugBuilds(to: &providers)
                appendSupabaseProvider(to: &providers)
            } else {
                providers.append(debugSink)
            }
        }

        return AnalyticsClient(
            providers: providers,
            isEnabled: JuicdAnalyticsConfig.isEnabled,
            onInvalidEvent: { message in
                #if DEBUG
                print("[AnalyticsService] \(message)")
                #endif
            }
        )
    }()

    // MARK: - Convenience events (LaunchPilot docs/ANALYTICS.md §4)

    static func logAppOpen(coldStart: Bool = true) {
        shared.log("app_open", params: ["cold_start": .bool(coldStart)])
    }

    static func logTabSelected(_ tab: String) {
        shared.log("tab_view", params: ["tab": .string(tab)])
    }

    static func logSignIn(method: String) {
        shared.log("sign_in", params: ["method": .string(method)])
    }

    static func logSignOut() {
        shared.log("sign_out")
    }

    static func logScreenView(_ screen: String) {
        shared.log("screen_view", params: ["screen": .string(screen)])
    }

    static func logFriendsView() {
        shared.log("friends_view")
    }

    static func logSlipSubmitted(legCount: Int, stakePoints: Int) {
        shared.log("slip_submitted", params: [
            "leg_count": .int(legCount),
            "stake_points": .int(stakePoints),
        ])
    }

    static func logSlipResolved(won: Bool, legCount: Int = 0) {
        var params: [String: AnalyticsValue] = ["won": .bool(won)]
        if legCount > 0 {
            params["leg_count"] = .int(legCount)
        }
        shared.log("slip_resolved", params: params)
    }

    static func logOddsSync(ok: Bool, source: String = "unknown") {
        shared.log("odds_sync", params: [
            "ok": .bool(ok),
            "source": .string(source),
        ])
    }

    static func logDashboardSlipsView(slateKey: String, slipCount: Int) {
        shared.log("dashboard_slips_view", params: [
            "slate_key": .string(slateKey),
            "slip_count": .int(slipCount),
        ])
    }

    static func logFriendRequestSent() {
        shared.log("friend_request_sent")
    }

    static func logGroupCreated() {
        shared.log("group_created")
    }

    static func logGroupJoined() {
        shared.log("group_joined")
    }

    static func logError(severity: String, screen: String? = nil) {
        var params: [String: AnalyticsValue] = ["severity": .string(severity)]
        if let screen, !screen.isEmpty {
            params["screen"] = .string(screen)
        }
        shared.log("app_error", params: params)
    }

    /// Prints the last `limit` buffered events to the console (Simulator QA helper).
    static func printRecentEvents(limit: Int = 10) {
        let events = debugSink.recordedEvents.suffix(max(1, limit))
        for event in events {
            let params = event.params
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.stringValue)" }
                .joined(separator: " ")
            print("[AnalyticsService] \(event.name)" + (params.isEmpty ? "" : " \(params)"))
        }
    }

    // MARK: - Provider wiring

    private static func appendDebugSinkInDebugBuilds(to providers: inout [AnalyticsProvider]) {
        #if DEBUG
        providers.append(debugSink)
        #endif
    }

    private static func appendSupabaseProvider(to providers: inout [AnalyticsProvider]) {
        guard JuicdAnalyticsConfig.isEnabled, SupabaseConfig.isConfigured else { return }
        providers.append(SupabaseAnalyticsProvider())
    }

    private static func appendTelemetryDeck(to providers: inout [AnalyticsProvider]) {
        if let td = TelemetryDeckProvider(appID: JuicdAnalyticsConfig.appID) {
            providers.append(td)
        }
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
