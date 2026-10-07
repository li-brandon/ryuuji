import Foundation
import SwiftData
import Synchronization

nonisolated extension SchemaV1.Title {
    var kind: Kind {
        Kind(rawValue: kindRaw) ?? .show
    }

    var status: ListStatus {
        get { ListStatus(rawValue: statusRaw) ?? .planToWatch }
        set { statusRaw = newValue.rawValue }
    }

    var showStatus: ShowStatus {
        ShowStatus(tmdb: showStatusRaw)
    }

    var year: String? {
        AirDate.year(from: releaseDate)
    }

    /// Cached seasons, decoded once per metadata revision. Empty when missing or unreadable.
    var seasons: [SeasonInfo] {
        MetadataDecodeCache.shared.seasons(for: self)
    }

    var allEpisodes: [EpisodeInfo] {
        seasons.flatMap(\.episodes)
    }

    /// True when the stored episode blob can't be decoded and should be re-fetched.
    var needsEpisodeRefresh: Bool {
        kind == .show && EpisodeMetadata.decode(episodesData) == nil
    }

    func setSeasons(_ seasons: [SeasonInfo]) {
        episodesData = EpisodeMetadata(seasons: seasons).encoded()
        metadataRevision += 1
    }

    var eventList: [SchemaV1.WatchEvent] {
        events ?? []
    }

    var eventRefs: [EventRef] {
        eventList.map(\.ref)
    }

    func progress(today: String) -> Progress {
        Progress.compute(episodes: allEpisodes, events: eventRefs, today: today)
    }

    /// Most recent watch time, if any.
    var lastWatchedAt: Date? {
        eventList.map(\.watchedAt).max()
    }

    /// Latest activity for Up Next ordering: last watch, else when the title was added.
    var lastActivity: Date {
        lastWatchedAt ?? addedAt
    }
}

nonisolated extension SchemaV1.WatchEvent {
    var ref: EventRef {
        EventRef(season: season, episode: episode, tmdbEpisodeId: tmdbEpisodeId, watchedAt: watchedAt)
    }

    var isMovieEvent: Bool {
        season == nil && episode == nil && tmdbEpisodeId == nil
    }
}

/// Memoizes decoded episode blobs so list views don't re-decode JSON on every render.
nonisolated final class MetadataDecodeCache: Sendable {
    static let shared = MetadataDecodeCache()

    private struct Key: Hashable {
        var id: PersistentIdentifier
        var revision: Int
    }

    private let storage = Mutex<[Key: [SeasonInfo]]>([:])

    func seasons(for title: SchemaV1.Title) -> [SeasonInfo] {
        let key = Key(id: title.persistentModelID, revision: title.metadataRevision)
        if let cached = storage.withLock({ $0[key] }) {
            return cached
        }
        let seasons = EpisodeMetadata.decode(title.episodesData)?.seasons ?? []
        storage.withLock { $0[key] = seasons }
        return seasons
    }
}

nonisolated extension TitleKey {
    init(_ title: SchemaV1.Title) {
        self.init(tmdbId: title.tmdbId, kind: title.kind)
    }
}
