import Foundation
import os

/// Build-time configuration read from the app's Info.plist.
nonisolated enum AppConfig {
    static let logger = Logger(subsystem: "moe.ryuuji.Ryuuji", category: "config")

    /// The TMDB API Read Access Token, or nil when Secrets.xcconfig did not provide one.
    static var tmdbToken: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TMDBToken") as? String else { return nil }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset build setting leaves the literal "$(TMDB_TOKEN)" or an empty string.
        if token.isEmpty || token.hasPrefix("$(") { return nil }
        return token
    }

    static func logTokenPresence() {
        logger.info("TMDB token present: \(tmdbToken != nil, privacy: .public)")
    }
}
