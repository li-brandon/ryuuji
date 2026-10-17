import Foundation
import SwiftData
import Testing
@testable import Ryuuji

/// Scenarios from specs/watch-log/spec.md, run against an in-memory store.
struct WatchLogServiceTests {
    let container: ModelContainer
    let context: ModelContext
    let service: WatchLogService
    let clock = Date(timeIntervalSince1970: 1_780_000_000)

    init() throws {
        container = try RyuujiStore.makeContainer(inMemory: true)
        context = ModelContext(container)
        let clock = clock
        service = WatchLogService(context: context, today: { Fixtures.today }, now: { clock })
    }

    func makeShow(_ episodes: [EpisodeInfo], status: ListStatus = .planToWatch, showStatus: ShowStatus = .returning) -> Title {
        let title = Title(tmdbId: Int.random(in: 1...1_000_000), kind: .show, name: "Show", status: status)
        title.showStatusRaw = showStatus.rawValue
        title.setSeasons(Fixtures.seasons(from: episodes))
        context.insert(title)
        try? context.save()
        return title
    }

    func makeMovie() -> Title {
        let title = Title(tmdbId: Int.random(in: 1...1_000_000), kind: .movie, name: "Movie")
        context.insert(title)
        try? context.save()
        return title
    }

    func eventCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<WatchEvent>())
    }

    /// A test undo manager that doesn't depend on a run loop.
    func makeUndoManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    // MARK: Watch events are the source of truth

    @Test func progressIsDerivedFromEvents() {
        let episodes = Fixtures.season(1, count: 3)
        let show = makeShow(episodes)
        service.log(episodes[0], of: show, undoManager: nil)
        service.log(episodes[1], of: show, undoManager: nil)
        service.log(episodes[1], of: show, undoManager: nil)
        #expect(show.progress(today: Fixtures.today).watchedAiredRegularCount == 2)
    }

    // MARK: Log a single episode

    @Test func logEpisodeRecordsEventAtNow() throws {
        let episodes = Fixtures.season(1, count: 3)
        let show = makeShow(episodes)
        service.log(episodes[2], of: show, undoManager: nil)

        let event = try #require(show.eventList.first)
        #expect(event.season == 1)
        #expect(event.episode == 3)
        #expect(event.tmdbEpisodeId == episodes[2].tmdbId)
        #expect(event.watchedAt == clock)
        #expect(show.status == .watching)
    }

    // MARK: Log a movie

    @Test func logMovieRecordsEventWithoutEpisode() throws {
        let movie = makeMovie()
        service.log(nil, of: movie, undoManager: nil)
        let event = try #require(movie.eventList.first)
        #expect(event.isMovieEvent)
        #expect(movie.status == .completed)
    }

    // MARK: Rewatches are repeated events

    @Test func logAgainAddsRewatch() {
        let episodes = Fixtures.season(1, count: 2)
        let show = makeShow(episodes)
        service.log(episodes[0], of: show, undoManager: nil)
        service.log(episodes[0], of: show, undoManager: nil)
        #expect(show.progress(today: Fixtures.today).rewatchCount(of: episodes[0]) == 1)
    }

    // MARK: Bulk marking

    @Test func markSeasonSkipsWatchedAndUnaired() throws {
        let aired = Fixtures.season(2, count: 10)
        let unaired = [Fixtures.episode(2, 11, airDate: Fixtures.future), Fixtures.episode(2, 12, airDate: Fixtures.future)]
        let show = makeShow(Fixtures.season(1, count: 2) + aired + unaired)
        for episode in aired.prefix(3) {
            service.log(episode, of: show, undoManager: nil)
        }

        service.bulkMark(.season(2), of: show, undoManager: nil)

        let batch = show.eventList.filter { $0.batchId != nil }
        #expect(batch.count == 7)
        #expect(Set(batch.map(\.batchId)).count == 1)
        #expect(Set(batch.map(\.watchedAt)).count == 1)
        #expect(batch.allSatisfy { $0.season == 2 && ($0.episode ?? 0) > 3 && ($0.episode ?? 0) <= 10 })
    }

    @Test func markAllSkipsSpecials() {
        let show = makeShow(Fixtures.season(0, count: 2) + Fixtures.season(1, count: 3) + Fixtures.season(2, count: 2))
        service.bulkMark(.all, of: show, undoManager: nil)
        #expect(show.eventList.count == 5)
        #expect(show.eventList.allSatisfy { $0.season != 0 })
        #expect(show.status == .caughtUp)
    }

    @Test func markAllOnEndedShowCompletes() {
        let show = makeShow(Fixtures.season(1, count: 3), showStatus: .ended)
        service.bulkMark(.all, of: show, undoManager: nil)
        #expect(show.status == .completed)
    }

    // MARK: Unmark an episode

    @Test func unmarkRemovesAllEventsForEpisode() throws {
        let episodes = Fixtures.season(1, count: 3)
        let show = makeShow(episodes)
        service.log(episodes[2], of: show, undoManager: nil)
        service.log(episodes[2], of: show, undoManager: nil)
        service.log(episodes[0], of: show, undoManager: nil)

        service.unmark(episodes[2], of: show, undoManager: nil)

        #expect(try eventCount() == 1)
        #expect(!show.progress(today: Fixtures.today).isWatched(episodes[2]))
    }

    @Test func unmarkFromCaughtUpReturnsToWatching() {
        let episodes = Fixtures.season(1, count: 2)
        let show = makeShow(episodes)
        service.bulkMark(.all, of: show, undoManager: nil)
        #expect(show.status == .caughtUp)
        service.unmark(episodes[1], of: show, undoManager: nil)
        #expect(show.status == .watching)
    }

    @Test func unmarkMovieReturnsToPlanToWatch() throws {
        let movie = makeMovie()
        service.log(nil, of: movie, undoManager: nil)
        service.unmark(nil, of: movie, undoManager: nil)
        #expect(try eventCount() == 0)
        #expect(movie.status == .planToWatch)
    }

    @Test func deleteSingleEventMarksEpisodeUnwatched() throws {
        let episodes = Fixtures.season(1, count: 3)
        let show = makeShow(episodes)
        service.log(episodes[2], of: show, undoManager: nil)
        let event = try #require(show.eventList.first)
        service.deleteEvent(event, undoManager: nil)
        #expect(!show.progress(today: Fixtures.today).isWatched(episodes[2]))
    }

    // MARK: Undo logging

    @Test func undoSingleLogRestoresEventsAndStatus() throws {
        let undo = makeUndoManager()
        let episodes = Fixtures.season(1, count: 3)
        let show = makeShow(episodes, status: .planToWatch)

        service.log(episodes[0], of: show, undoManager: undo)
        #expect(show.status == .watching)
        #expect(undo.canUndo)

        undo.undo()

        #expect(try eventCount() == 0)
        #expect(show.status == .planToWatch)
    }

    @Test func undoBulkMarkIsOneStep() throws {
        let undo = makeUndoManager()
        let episodes = Fixtures.season(1, count: 5)
        let show = makeShow(episodes, status: .watching)
        service.log(episodes[0], of: show, undoManager: undo)

        service.bulkMark(.season(1), of: show, undoManager: undo)
        #expect(try eventCount() == 5)
        #expect(show.status == .caughtUp)

        undo.undo()

        #expect(try eventCount() == 1)
        #expect(show.status == .watching)
    }

    @Test func undoUnmarkRestoresEvents() throws {
        let undo = makeUndoManager()
        let episodes = Fixtures.season(1, count: 2)
        let show = makeShow(episodes)
        service.bulkMark(.all, of: show, undoManager: nil)
        let originalDates = show.eventList.map(\.watchedAt)

        service.unmark(episodes[1], of: show, undoManager: undo)
        #expect(show.status == .watching)
        undo.undo()

        #expect(try eventCount() == 2)
        #expect(show.status == .caughtUp)
        #expect(Set(show.eventList.map(\.watchedAt)) == Set(originalDates))
    }

    @Test func undoAfterTitleRemovalIsHarmless() throws {
        let undo = makeUndoManager()
        let episodes = Fixtures.season(1, count: 2)
        let show = makeShow(episodes)
        service.log(episodes[0], of: show, undoManager: undo)
        context.delete(show)
        try context.save()
        undo.undo()
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 0)
    }

    // MARK: Setting to Completed (LIB-299) — the StatusPicker path

    @Test func setCompletedMarksAiredRegularEpisodesAsOneBatch() throws {
        let specials = Fixtures.season(0, count: 2)
        let aired = Fixtures.season(1, count: 10)
        let unaired = [Fixtures.episode(1, 11, airDate: Fixtures.future), Fixtures.episode(1, 12, airDate: Fixtures.future)]
        let show = makeShow(specials + aired + unaired, status: .watching, showStatus: .ended)

        service.setStatus(.completed, of: show, undoManager: nil)

        let events = show.eventList
        #expect(events.count == 10)
        #expect(events.allSatisfy { $0.season == 1 && ($0.episode ?? 0) <= 10 })
        #expect(Set(events.map(\.batchId)).count == 1)
        #expect(events.first?.batchId != nil)
        #expect(show.status == .completed)
    }

    @Test func setCompletedFillsOnlyMissingEpisodes() throws {
        let episodes = Fixtures.season(1, count: 5)
        let show = makeShow(episodes, status: .watching, showStatus: .ended)
        service.log(episodes[0], of: show, undoManager: nil)
        service.log(episodes[1], of: show, undoManager: nil)

        service.setStatus(.completed, of: show, undoManager: nil)

        #expect(try eventCount() == 5)
        #expect(Set(show.eventList.compactMap(\.episode)) == [1, 2, 3, 4, 5])
        #expect(episodes.allSatisfy { show.progress(today: Fixtures.today).rewatchCount(of: $0) == 0 })
    }

    @Test func setCompletedOnReturningShowBecomesCaughtUp() throws {
        // Completed is reserved for finished shows; a Returning show the user has caught up on is Caught Up.
        let show = makeShow(Fixtures.season(1, count: 3), status: .watching, showStatus: .returning)

        service.setStatus(.completed, of: show, undoManager: nil)

        #expect(try eventCount() == 3)
        #expect(show.status == .caughtUp)
    }

    @Test func setCompletedOnShowWithNothingAiredStaysCompleted() throws {
        let show = makeShow(Fixtures.season(1, count: 3, airDate: Fixtures.future), status: .planToWatch)

        service.setStatus(.completed, of: show, undoManager: nil)

        #expect(try eventCount() == 0)
        #expect(show.status == .completed)
    }

    @Test func undoSetCompletedRestoresEventsAndStatus() throws {
        let undo = makeUndoManager()
        let episodes = Fixtures.season(1, count: 5)
        let show = makeShow(episodes, status: .planToWatch, showStatus: .ended)
        service.log(episodes[0], of: show, undoManager: nil)
        #expect(show.status == .watching)

        service.setStatus(.completed, of: show, undoManager: undo)
        #expect(try eventCount() == 5)
        #expect(show.status == .completed)

        undo.undo()

        #expect(try eventCount() == 1)
        #expect(show.progress(today: Fixtures.today).isWatched(episodes[0]))
        #expect(show.status == .watching)
        #expect(!undo.canUndo)
    }

    @Test func undoOtherStatusChangeRestoresStatus() throws {
        let undo = makeUndoManager()
        let show = makeShow(Fixtures.season(1, count: 3), status: .watching)

        service.setStatus(.onHold, of: show, undoManager: undo)
        #expect(show.status == .onHold)
        #expect(try eventCount() == 0)

        undo.undo()

        #expect(show.status == .watching)
    }

    @Test func setCompletedOnUnwatchedMovieLogsOneEvent() throws {
        let movie = makeMovie()

        service.setStatus(.completed, of: movie, undoManager: nil)

        #expect(movie.eventList.count == 1)
        #expect(movie.eventList.first?.isMovieEvent == true)
        #expect(movie.status == .completed)
    }

    @Test func setCompletedOnWatchedMovieAddsNoEvent() throws {
        let movie = makeMovie()
        service.log(nil, of: movie, undoManager: nil)
        service.setStatus(.dropped, of: movie, undoManager: nil)

        service.setStatus(.completed, of: movie, undoManager: nil)

        #expect(movie.eventList.count == 1)
        #expect(movie.status == .completed)
    }
}
