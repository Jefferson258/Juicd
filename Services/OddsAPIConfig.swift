import Foundation

/// Add `ODDS_API_KEY` to your target’s **Info** (Custom iOS Target Properties) in Xcode.
/// Get a key at [the-odds-api.com](https://the-odds-api.com/).
enum OddsAPIConfig {
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "ODDS_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool { !apiKey.isEmpty }
}
