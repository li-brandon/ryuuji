/// Watch progress for one title, derived from its cached episodes and its watch events.
nonisolated struct Progress: Sendable {
    /// Number of events per episode, keyed by TMDB episode id.
    let watchCounts: [Int: Int]
    /// Aired regular (non-special) episodes in season/episode order.
    let airedRegular: [EpisodeInfo]
    /// How many of `airedRegular` have at least one event.
    let watchedAiredRegularCount: Int
    /// The first aired, unwatched regular episode.
    let next: EpisodeInfo?
    /// Aired regular episodes with no events.
    let remaining: Int
    /// Events that match no cached episode (kept for History, ignored for progress).
    let orphanCount: Int
    /// Every event for the title, matched or not. For movies this is the watch count.
    let eventCount: Int

    var hasAiredRegular: Bool { !airedRegular.isEmpty }

    func watchCount(of episode: EpisodeInfo) -> Int { watchCounts[episode.tmdbId] ?? 0 }
    func isWatched(_ episode: EpisodeInfo) -> Bool { watchCount(of: episode) > 0 }
    func rewatchCount(of episode: EpisodeInfo) -> Int { max(0, watchCount(of: episode) - 1) }

    static func compute(episodes: [EpisodeInfo], events: [EventRef], today: String) -> Progress {
        let matcher = EpisodeMatcher(episodes: episodes)
        var counts: [Int: Int] = [:]
        var orphans = 0
        for event in events {
            if let episode = matcher.match(event) {
                counts[episode.tmdbId, default: 0] += 1
            } else {
                orphans += 1
            }
        }

        let airedRegular = episodes
            .filter { !$0.isSpecial && $0.isAired(today: today) }
            .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        let unwatched = airedRegular.filter { (counts[$0.tmdbId] ?? 0) == 0 }

        return Progress(
            watchCounts: counts,
            airedRegular: airedRegular,
            watchedAiredRegularCount: airedRegular.count - unwatched.count,
            next: unwatched.first,
            remaining: unwatched.count,
            orphanCount: orphans,
            eventCount: events.count
        )
    }
}

/// Matches watch events to episodes: TMDB episode id first, then season/episode for
/// events recorded without an id (design D4).
nonisolated struct EpisodeMatcher: Sendable {
    private let byId: [Int: EpisodeInfo]
    private let byNumber: [EpisodeKey: EpisodeInfo]

    init(episodes: [EpisodeInfo]) {
        var byId: [Int: EpisodeInfo] = [:]
        var byNumber: [EpisodeKey: EpisodeInfo] = [:]
        for episode in episodes {
            byId[episode.tmdbId] = episode
            byNumber[EpisodeKey(season: episode.season, number: episode.number)] = episode
        }
        self.byId = byId
        self.byNumber = byNumber
    }

    func match(_ event: EventRef) -> EpisodeInfo? {
        if let id = event.tmdbEpisodeId {
            return byId[id]
        }
        guard let season = event.season, let number = event.episode else { return nil }
        return byNumber[EpisodeKey(season: season, number: number)]
    }
}

nonisolated struct EpisodeKey: Hashable, Sendable {
    var season: Int
    var number: Int
}
