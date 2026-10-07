import Foundation
import SwiftData
import Synchronization
import Testing
@testable import Ryuuji

/// Refresh scenarios from specs/title-metadata and specs/list-status.
struct MetadataRefresherTests {
    let container: ModelContainer
    let context: ModelContext
    let client = FakeTMDBClient()
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    init() throws {
        container = try RyuujiStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    func refresher() -> MetadataRefresher {
        MetadataRefresher(modelContainer: container)
    }

    /// Inserts a show with `episodes` cached and the first `watched` of them logged.
    @discardableResult
    func insertShow(id: Int, episodes: [EpisodeInfo], watched: Int, status: ListStatus, showStatus: ShowStatus = .returning) throws -> Title {
        let title = Title(tmdbId: id, kind: .show, name: "Show \(id)", status: status)
        title.showStatusRaw = showStatus.rawValue
        title.setSeasons(Fixtures.seasons(from: episodes))
        context.insert(title)
        for episode in episodes.prefix(watched) {
            let event = WatchEvent(watchedAt: now, season: episode.season, episode: episode.number, tmdbEpisodeId: episode.tmdbId)
            context.insert(event)
            event.title = title
        }
        try context.save()
        return title
    }

    func fetchTitle(_ id: Int) throws -> Title {
        let fresh = ModelContext(container)
        return try #require(try TitleRepository.find(tmdbId: id, kind: .show, in: fresh))
    }

    // MARK: Status after refresh

    @Test func newEpisodeMovesCaughtUpToWatching() async throws {
        let episodes = Fixtures.season(1, count: 2)
        try insertShow(id: 1, episodes: episodes, watched: 2, status: .caughtUp)
        try client.update { $0.shows[1] = try TMDBBuilder.show(id: 1, episodes: episodes + [Fixtures.episode(1, 3)]) }

        let report = await refresher().refreshDue(client: client, now: now, today: Fixtures.today)

        #expect(report == RefreshReport(refreshed: 1, failed: 0))
        let title = try fetchTitle(1)
        #expect(title.allEpisodes.count == 3)
        #expect(title.status == .watching)
        #expect(title.lastRefreshedAt == now)
    }

    @Test func showEndingCompletesCaughtUpShow() async throws {
        let episodes = Fixtures.season(1, count: 2)
        try insertShow(id: 2, episodes: episodes, watched: 2, status: .caughtUp)
        try client.update { $0.shows[2] = try TMDBBuilder.show(id: 2, status: "Ended", episodes: episodes) }

        _ = await refresher().refreshDue(client: client, now: now, today: Fixtures.today)

        #expect(try fetchTitle(2).status == .completed)
    }

    @Test func pausedShowIsUntouched() async throws {
        let episodes = Fixtures.season(1, count: 2)
        try insertShow(id: 3, episodes: episodes, watched: 2, status: .onHold)
        try client.update { $0.shows[3] = try TMDBBuilder.show(id: 3, episodes: episodes + [Fixtures.episode(1, 3)]) }

        _ = await refresher().refreshDue(client: client, now: now, today: Fixtures.today)

        let title = try fetchTitle(3)
        #expect(title.allEpisodes.count == 3)
        #expect(title.status == .onHold)
    }

    @Test func failedRefreshKeepsCache() async throws {
        let episodes = Fixtures.season(1, count: 2)
        try insertShow(id: 4, episodes: episodes, watched: 1, status: .watching)
        client.update { $0.failing = true }

        let report = await refresher().refreshDue(client: client, now: now, today: Fixtures.today)

        #expect(report == RefreshReport(refreshed: 0, failed: 1))
        let title = try fetchTitle(4)
        #expect(title.allEpisodes.count == 2)
        #expect(title.lastRefreshedAt == nil)
        #expect(title.eventList.count == 1)
    }

    // MARK: Selection

    @Test func selectionSkipsRecentlyRefreshedEndedShowsAndMovies() throws {
        let ended = Title(tmdbId: 5, kind: .show)
        ended.showStatusRaw = ShowStatus.ended.rawValue
        ended.setSeasons(Fixtures.seasons(from: Fixtures.season(1, count: 1)))
        ended.lastRefreshedAt = now.addingTimeInterval(-24 * 60 * 60)
        #expect(!MetadataRefresher.isDue(ended, now: now))

        ended.lastRefreshedAt = now.addingTimeInterval(-8 * 24 * 60 * 60)
        #expect(MetadataRefresher.isDue(ended, now: now))

        let returning = Title(tmdbId: 6, kind: .show)
        returning.showStatusRaw = ShowStatus.returning.rawValue
        returning.setSeasons(Fixtures.seasons(from: Fixtures.season(1, count: 1)))
        returning.lastRefreshedAt = now
        #expect(MetadataRefresher.isDue(returning, now: now))

        #expect(!MetadataRefresher.isDue(Title(tmdbId: 7, kind: .movie), now: now))
    }

    // MARK: Refresh never loses watch history

    @Test func renumberedEpisodeKeepsItsEvents() async throws {
        // Watched S1E13 (TMDB id 1013); TMDB later moves it to S2E1.
        let original = Fixtures.season(1, count: 13)
        try insertShow(id: 8, episodes: original, watched: 13, status: .caughtUp)
        let moved = EpisodeInfo(tmdbId: 1013, season: 2, number: 1, name: "Moved", airDate: Fixtures.past)
        try client.update { $0.shows[8] = try TMDBBuilder.show(id: 8, episodes: Array(original.prefix(12)) + [moved]) }

        _ = await refresher().refresh([TitleKey(tmdbId: 8, kind: .show)], client: client, now: now, today: Fixtures.today)

        let title = try fetchTitle(8)
        let event = try #require(title.eventList.first { $0.tmdbEpisodeId == 1013 })
        #expect(event.season == 2)
        #expect(event.episode == 1)
        #expect(title.progress(today: Fixtures.today).isWatched(moved))
        #expect(title.status == .caughtUp)
    }

    @Test func removedEpisodeEventIsKept() async throws {
        let original = Fixtures.season(1, count: 3)
        try insertShow(id: 9, episodes: original, watched: 3, status: .caughtUp)
        try client.update { $0.shows[9] = try TMDBBuilder.show(id: 9, episodes: Array(original.prefix(2))) }

        _ = await refresher().refresh([TitleKey(tmdbId: 9, kind: .show)], client: client, now: now, today: Fixtures.today)

        let title = try fetchTitle(9)
        #expect(title.eventList.count == 3)
        #expect(title.progress(today: Fixtures.today).orphanCount == 1)
    }

    @Test func atMostFourRequestsInFlight() async throws {
        let probe = ConcurrencyProbeClient()
        for id in 100..<110 {
            try insertShow(id: id, episodes: Fixtures.season(1, count: 1), watched: 0, status: .watching)
        }
        let report = await refresher().refreshDue(client: probe, now: now, today: Fixtures.today)
        #expect(report.refreshed == 10)
        #expect(probe.peak == MetadataRefresher.maxConcurrentRequests)
    }
}

/// Records the peak number of overlapping show requests.
nonisolated final class ConcurrencyProbeClient: TMDBClient, Sendable {
    private let counts = Mutex((current: 0, peak: 0))

    var peak: Int { counts.withLock { $0.peak } }

    func search(_ query: String) async throws -> [TMDBSearchResult] { [] }
    func movie(id: Int) async throws -> TMDBMovie { throw TMDBError.httpStatus(404) }

    func show(id: Int) async throws -> TMDBShowDetails {
        counts.withLock { $0.current += 1; $0.peak = max($0.peak, $0.current) }
        try await Task.sleep(for: .milliseconds(50))
        counts.withLock { $0.current -= 1 }
        return try TMDBBuilder.show(id: id, episodes: Fixtures.season(1, count: 1))
    }
}
