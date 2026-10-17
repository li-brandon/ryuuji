import Foundation
import SwiftData
import Testing
@testable import Ryuuji

/// Quick add with a starting status (title-search spec, LIB-299).
struct TitleAdderTests {
    let container: ModelContainer
    let context: ModelContext
    let client = FakeTMDBClient()
    let adder: TitleAdder

    init() throws {
        container = try RyuujiStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let watchLog = WatchLogService(context: context, today: { Fixtures.today }, now: { now })
        adder = TitleAdder(context: context, client: client, watchLog: watchLog, now: { now })
    }

    func searchItem(id: Int, kind: Kind) throws -> SearchItem {
        let json = #"{"id": \#(id), "media_type": "\#(kind == .movie ? "movie" : "tv")", "name": "X", "title": "X"}"#
        let result = try TMDBJSON.decoder.decode(TMDBSearchResult.self, from: Data(json.utf8))
        return try #require(SearchItem(result))
    }

    struct NotAdded: Error {}

    func added(_ outcome: TitleAdder.Outcome) throws -> Title {
        guard case .added(let title) = outcome else { throw NotAdded() }
        return title
    }

    @Test func showAddedAsCompletedMarksAiredRegularEpisodes() async throws {
        let regular = Fixtures.season(1, count: 3) + Fixtures.season(2, count: 2)
        let episodes = Fixtures.season(0, count: 2) + regular + [Fixtures.episode(2, 3, airDate: Fixtures.future)]
        try client.update { $0.shows[10] = try TMDBBuilder.show(id: 10, status: "Ended", episodes: episodes) }

        let title = try added(try await adder.add(searchItem(id: 10, kind: .show), status: .completed, undoManager: nil))

        let progress = title.progress(today: Fixtures.today)
        #expect(progress.watchedAiredRegularCount == regular.count)
        #expect(progress.remaining == 0)
        #expect(title.eventList.count == regular.count)
        #expect(title.eventList.allSatisfy { $0.season != 0 })
        #expect(!title.eventList.contains { $0.season == 2 && $0.episode == 3 })
        #expect(Set(title.eventList.map(\.batchId)).count == 1)
        #expect(title.status == .completed)
    }

    @Test func movieAddedAsCompletedLogsOneEvent() async throws {
        let movie = try FixtureFile.decode(TMDBMovie.self, "movie-372058")
        client.update { $0.movies[movie.id] = movie }

        let title = try added(try await adder.add(searchItem(id: movie.id, kind: .movie), status: .completed, undoManager: nil))

        #expect(title.eventList.count == 1)
        #expect(title.eventList.first?.isMovieEvent == true)
        #expect(title.status == .completed)
    }

    @Test func showAddedAsPlanToWatchHasNoEvents() async throws {
        try client.update { $0.shows[11] = try TMDBBuilder.show(id: 11, episodes: Fixtures.season(1, count: 3)) }

        let title = try added(try await adder.add(searchItem(id: 11, kind: .show), status: .planToWatch, undoManager: nil))

        #expect(title.eventList.isEmpty)
        #expect(title.status == .planToWatch)
    }

    @Test func undoShowAddedAsCompletedRemovesBatchInOneStep() async throws {
        let undo = UndoManager()
        undo.groupsByEvent = false
        let episodes = Fixtures.season(1, count: 4)
        try client.update { $0.shows[12] = try TMDBBuilder.show(id: 12, status: "Ended", episodes: episodes) }

        let title = try added(try await adder.add(searchItem(id: 12, kind: .show), status: .completed, undoManager: undo))
        #expect(title.eventList.count == episodes.count)
        #expect(undo.canUndo)

        undo.undo()

        #expect(title.eventList.isEmpty)
        #expect(!undo.canUndo)
    }
}
