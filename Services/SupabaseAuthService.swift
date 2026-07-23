import Foundation
import Security

/// Persisted Supabase Auth session (anonymous for multi-device social beta).
struct SupabaseSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userId: UUID
    var expiresAt: Date
}

enum SupabaseAuthService {
    private static let keychainService = "com.jefferson258.juicd.supabase"
    private static let keychainAccount = "session"
    /// In-memory fallback so social APIs still work if Keychain write fails (common under UITest).
    private static var memorySession: SupabaseSession?

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static var currentSession: SupabaseSession? {
        get { memorySession ?? loadSession() }
        set {
            memorySession = newValue
            if let newValue { saveSession(newValue) } else { clearSession() }
        }
    }

    static var accessToken: String? { currentSession?.accessToken }

    static var isSignedIn: Bool { currentSession != nil }

    /// Restore a saved session, refreshing when near expiry.
    static func restoreSession() async -> SupabaseSession? {
        guard var session = memorySession ?? loadSession() else { return nil }
        memorySession = session
        if session.expiresAt.timeIntervalSinceNow > 60 {
            return session
        }
        do {
            session = try await refresh(session)
            memorySession = session
            saveSession(session)
            return session
        } catch {
            memorySession = nil
            clearSession()
            return nil
        }
    }

    /// Create (or reuse Keychain) anonymous Supabase user for multi-device social.
    static func signInAnonymously(displayName: String) async throws -> SupabaseSession {
        if let restored = await restoreSession() {
            try await upsertProfile(
                displayName: displayName,
                userId: restored.userId,
                accessToken: restored.accessToken
            )
            return restored
        }

        guard SupabaseConfig.isConfigured else { throw URLError(.badURL) }

        let (data, resp) = try await URLSession.shared.data(for: anonymousSignUpRequest(displayName: displayName))
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "auth failed"
            throw NSError(domain: "SupabaseAuth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let session = try decodeSession(from: data)
        memorySession = session
        saveSession(session)
        try await upsertProfile(displayName: displayName, userId: session.userId, accessToken: session.accessToken)
        return session
    }

    static func signOut() {
        memorySession = nil
        clearSession()
    }

    static func upsertProfile(displayName: String, userId: UUID, accessToken: String) async throws {
        guard let base = SupabaseConfig.projectURL else { throw URLError(.badURL) }
        var comps = URLComponents(url: base.appendingPathComponent("rest/v1/juicd_profiles"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "on_conflict", value: "id")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        let body: [String: Any] = [
            "id": userId.uuidString,
            "display_name": String(displayName.prefix(40)),
            "updated_at": isoBasic.string(from: Date()),
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "profile upsert failed"
            throw NSError(
                domain: "SupabaseAuth",
                code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }
    }

    // MARK: - Private

    private static func anonymousSignUpRequest(displayName: String) throws -> URLRequest {
        guard let url = SupabaseConfig.projectURL?.appendingPathComponent("auth/v1/signup") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "data": ["display_name": displayName],
        ])
        return req
    }

    private static func refresh(_ session: SupabaseSession) async throws -> SupabaseSession {
        guard var comps = URLComponents(
            url: SupabaseConfig.projectURL!.appendingPathComponent("auth/v1/token"),
            resolvingAgainstBaseURL: false
        ) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "refresh_token": session.refreshToken,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        return try decodeSession(from: data)
    }

    private static func decodeSession(from data: Data) throws -> SupabaseSession {
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = obj?["access_token"] as? String,
              let refresh = obj?["refresh_token"] as? String,
              let user = obj?["user"] as? [String: Any],
              let idString = user["id"] as? String,
              let userId = UUID(uuidString: idString)
        else {
            throw URLError(.cannotParseResponse)
        }
        let expiresIn = (obj?["expires_in"] as? NSNumber)?.doubleValue
            ?? (obj?["expires_in"] as? Double)
            ?? 3600
        return SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            userId: userId,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    private static func saveSession(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadSession() -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private static func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
