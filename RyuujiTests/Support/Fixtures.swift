import Foundation
@testable import Ryuuji

/// Builders for domain test data.
nonisolated enum Fixtures {
    static let today = "2026-06-15"
    static let past = "2026-01-01"
    static let future = "2026-12-31"

    /// Unique, readable TMDB ids: season * 1000 + episode number.
    static func episode(_ season: Int, _ number: Int, airDate: String? = past, name: String? = nil) -> EpisodeInfo {
        EpisodeInfo(
            tmdbId: season * 1000 + number,
            season: season,
            number: number,
            name: name ?? "Episode \(number)",
            airDate: airDate,
            runtime: 24
        )
    }

    /// A season of `count` aired episodes.
    static func season(_ season: Int, count: Int, airDate: String? = past) -> [EpisodeInfo] {
        (1...count).map { episode(season, $0, airDate: airDate) }
    }

    static func event(_ episode: EpisodeInfo, at date: Date = Date(timeIntervalSince1970: 0)) -> EventRef {
        EventRef(season: episode.season, episode: episode.number, tmdbEpisodeId: episode.tmdbId, watchedAt: date)
    }

    static func movieEvent(at date: Date = Date(timeIntervalSince1970: 0)) -> EventRef {
        EventRef(watchedAt: date)
    }

    static func seasons(from episodes: [EpisodeInfo]) -> [SeasonInfo] {
        Dictionary(grouping: episodes, by: \.season)
            .sorted { $0.key < $1.key }
            .map { SeasonInfo(number: $0.key, name: $0.key == 0 ? "Specials" : "Season \($0.key)", episodes: $0.value) }
    }
}
