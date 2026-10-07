import Foundation

/// Whether a title is a movie or a TV show.
nonisolated enum Kind: String, Codable, CaseIterable, Sendable {
    case movie
    case show

    var label: String {
        switch self {
        case .movie: "Movie"
        case .show: "Show"
        }
    }
}

/// The user's list status for a title.
nonisolated enum ListStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case planToWatch
    case watching
    case caughtUp
    case onHold
    case dropped
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planToWatch: "Plan to Watch"
        case .watching: "Watching"
        case .caughtUp: "Caught Up"
        case .onHold: "On Hold"
        case .dropped: "Dropped"
        case .completed: "Completed"
        }
    }

    var systemImage: String {
        switch self {
        case .planToWatch: "bookmark"
        case .watching: "play.circle"
        case .caughtUp: "clock.badge.checkmark"
        case .onHold: "pause.circle"
        case .dropped: "xmark.circle"
        case .completed: "checkmark.circle"
        }
    }
}

/// TMDB's production status for a show.
nonisolated enum ShowStatus: String, Codable, Sendable {
    case returning = "Returning Series"
    case ended = "Ended"
    case canceled = "Canceled"
    case inProduction = "In Production"
    case planned = "Planned"
    case pilot = "Pilot"
    case unknown = "Unknown"

    init(tmdb raw: String?) {
        self = raw.flatMap(ShowStatus.init(rawValue:)) ?? .unknown
    }

    /// Whether no further episodes are expected.
    var isFinished: Bool { self == .ended || self == .canceled }
}

/// One episode as cached from TMDB.
nonisolated struct EpisodeInfo: Codable, Hashable, Identifiable, Sendable {
    /// TMDB episode id.
    var tmdbId: Int
    var season: Int
    var number: Int
    var name: String
    /// Air date as an ISO calendar date ("yyyy-MM-dd"), nil when TMDB has none.
    var airDate: String?
    var runtime: Int?

    var id: Int { tmdbId }

    /// Season 0 holds specials, which never count toward progress.
    var isSpecial: Bool { season == 0 }

    /// An episode has aired when its air date is on or before `today` ("yyyy-MM-dd").
    func isAired(today: String) -> Bool {
        guard let airDate, !airDate.isEmpty else { return false }
        return airDate <= today
    }

    /// "S1E5"
    var code: String { "S\(season)E\(number)" }
}

/// One season as cached from TMDB.
nonisolated struct SeasonInfo: Codable, Hashable, Identifiable, Sendable {
    var number: Int
    var name: String
    var episodes: [EpisodeInfo]

    var id: Int { number }
    var isSpecials: Bool { number == 0 }
}

/// The cached episode list stored on a title as JSON (design D3).
nonisolated struct EpisodeMetadata: Codable, Hashable, Sendable {
    static let currentVersion = 1

    var schemaVersion: Int = EpisodeMetadata.currentVersion
    var seasons: [SeasonInfo]

    init(seasons: [SeasonInfo]) {
        self.seasons = seasons
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    /// Decodes a stored blob. Returns nil for empty, corrupt, or unknown-version data,
    /// which callers treat as "needs refresh".
    static func decode(_ data: Data) -> EpisodeMetadata? {
        guard !data.isEmpty,
              let value = try? JSONDecoder().decode(EpisodeMetadata.self, from: data),
              value.schemaVersion == currentVersion
        else { return nil }
        return value
    }
}

/// A watch event reduced to the fields the domain logic needs.
nonisolated struct EventRef: Hashable, Sendable {
    var season: Int?
    var episode: Int?
    var tmdbEpisodeId: Int?
    var watchedAt: Date

    init(season: Int? = nil, episode: Int? = nil, tmdbEpisodeId: Int? = nil, watchedAt: Date) {
        self.season = season
        self.episode = episode
        self.tmdbEpisodeId = tmdbEpisodeId
        self.watchedAt = watchedAt
    }
}

/// Calendar helpers for TMDB-style "yyyy-MM-dd" dates.
nonisolated enum AirDate {
    /// Today's local calendar date as "yyyy-MM-dd".
    static func today(now: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Parses "yyyy-MM-dd" into a local-midnight Date, for display.
    static func date(from string: String?, calendar: Calendar = .current) -> Date? {
        guard let string else { return nil }
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The year part of "yyyy-MM-dd", if present.
    static func year(from string: String?) -> String? {
        guard let string, string.count >= 4 else { return nil }
        return String(string.prefix(4))
    }
}

/// A title's natural key (TMDB id + kind), stable across saves.
nonisolated struct TitleKey: Hashable, Sendable {
    var tmdbId: Int
    var kind: Kind
}
