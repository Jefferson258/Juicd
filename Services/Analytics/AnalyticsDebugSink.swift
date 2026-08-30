//
//  AnalyticsDebugSink.swift
//  Juicd
//
//  Kept in sync with LaunchPilot kits/analytics/Sources/AnalyticsCore/AnalyticsDebugSink.swift.
//
//  Records events without any network access:
//   - in-memory ring buffer (`recordedEvents`) for tests / QA / the debug overlay,
//   - optional JSONL file in Documents (never uploaded),
//   - os.Logger + optional console print when `logToConsole` is true.
//

import Foundation
import Combine
import os

final class AnalyticsDebugSink: ObservableObject, AnalyticsProvider {
    let identifier = "debug"

    private let maxBufferedEvents: Int
    private let fileURL: URL?
    private let logToConsole: Bool
    private let logger: Logger

    private let lock = NSLock()
    private var buffer: [AnalyticsEvent] = []

    /// Published snapshots let the debug overlay react to events without a
    /// polling timer. The buffer itself remains locked because analytics can
    /// be recorded from background work.
    @Published private(set) var eventCount = 0
    @Published private(set) var lastEventName = "none"

    init(
        maxBufferedEvents: Int = 200,
        fileURL: URL? = nil,
        logToConsole: Bool = true,
        loggerSubsystem: String = "com.juicd.analytics"
    ) {
        self.maxBufferedEvents = max(1, maxBufferedEvents)
        self.fileURL = fileURL
        self.logToConsole = logToConsole
        self.logger = Logger(subsystem: loggerSubsystem, category: "AnalyticsDebug")
    }

    func track(_ event: AnalyticsEvent) {
        lock.lock()
        buffer.append(event)
        if buffer.count > maxBufferedEvents {
            buffer.removeFirst(buffer.count - maxBufferedEvents)
        }
        lock.unlock()

        // Always publish on the main queue. Read the locked buffer when the
        // update executes so queued updates cannot publish an older event
        // after a newer one.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let count = self.buffer.count
            let lastName = self.buffer.last?.name ?? "none"
            self.lock.unlock()
            self.eventCount = count
            self.lastEventName = lastName
        }

        let paramsDescription = event.params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.stringValue)" }
            .joined(separator: " ")

        if logToConsole {
            if paramsDescription.isEmpty {
                logger.debug("\(event.name, privacy: .public)")
                print("[Juicd Analytics][debug] \(event.name)")
            } else {
                logger.debug("\(event.name, privacy: .public) \(paramsDescription, privacy: .public)")
                print("[Juicd Analytics][debug] \(event.name) \(paramsDescription)")
            }
        }

        appendToFileIfConfigured(event)
    }

    /// Thread-safe snapshot of everything currently buffered (oldest first).
    var recordedEvents: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.eventCount = 0
            self?.lastEventName = "none"
        }
    }

    // MARK: - File sink (best-effort; never throws into caller)

    private func appendToFileIfConfigured(_ event: AnalyticsEvent) {
        guard let fileURL else { return }
        guard let line = Self.jsonLine(for: event) else { return }
        let data = (line + "\n").data(using: .utf8) ?? Data()

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        handle.write(data)
    }

    private static let iso8601 = ISO8601DateFormatter()

    static func jsonLine(for event: AnalyticsEvent) -> String? {
        var payload: [String: Any] = [
            "name": event.name,
            "timestamp": iso8601.string(from: event.timestamp)
        ]
        var paramsJSON: [String: Any] = [:]
        for (key, value) in event.params {
            switch value {
            case .string(let v): paramsJSON[key] = v
            case .int(let v): paramsJSON[key] = v
            case .double(let v): paramsJSON[key] = v
            case .bool(let v): paramsJSON[key] = v
            }
        }
        payload["params"] = paramsJSON
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
