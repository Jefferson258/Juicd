import Foundation

enum SupabaseConfig {
    static var projectURLString: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var projectURL: URL? {
        guard !projectURLString.isEmpty else { return nil }
        return URL(string: projectURLString)
    }

    static var edgeBaseURL: URL? {
        guard let base = projectURL else { return nil }
        return base.appendingPathComponent("functions/v1")
    }

    static var isConfigured: Bool {
        projectURL != nil && !anonKey.isEmpty
    }
}

