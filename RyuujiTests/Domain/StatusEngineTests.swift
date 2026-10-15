import Testing
@testable import Ryuuji

/// One test per scenario in specs/list-status/spec.md.
struct StatusEngineTests {
    let episodes = Fixtures.season(1, count: 3)

    func progress(watched: Int, episodes: [EpisodeInfo]? = nil) -> Progress {
        let episodes = episodes ?? self.episodes
        let events = episodes.prefix(watched).map { Fixtures.event($0) }
        return Progress.compute(episodes: episodes, events: Array(events), today: Fixtures.today)
    }

    func show(_ trigger: StatusTrigger, _ current: ListStatus, watched: Int, _ showStatus: ShowStatus = .returning) -> ListStatus {
        StatusEngine.status(after: trigger, current: current, kind: .show, progress: progress(watched: watched), showStatus: showStatus)
    }

    // MARK: Status always present

    @Test func everyStatusHasALabel() {
        #expect(ListStatus.allCases.count == 6)
        #expect(Set(ListStatus.allCases.map(\.label)).count == 6)
    }

    // MARK: Status recomputed when logging

    @Test func firstEpisodeLoggedMakesWatching() {
        #expect(show(.log, .planToWatch, watched: 1) == .watching)
    }

    @Test(arguments: [ListStatus.onHold, .dropped])
    func loggingReactivatesPausedShow(current: ListStatus) {
        #expect(show(.log, current, watched: 2) == .watching)
    }

    @Test func caughtUpOnReturningShow() {
        #expect(show(.log, .watching, watched: 3, .returning) == .caughtUp)
    }

    @Test func finishedEndedShowCompletes() {
        #expect(show(.log, .watching, watched: 3, .ended) == .completed)
        #expect(show(.log, .watching, watched: 3, .canceled) == .completed)
    }

    @Test func movieWatchedCompletes() {
        let progress = Progress.compute(episodes: [], events: [Fixtures.movieEvent()], today: Fixtures.today)
        #expect(StatusEngine.status(after: .log, current: .planToWatch, kind: .movie, progress: progress, showStatus: .unknown) == .completed)
    }

    @Test func rewatchingCompletedEndedShowStaysCompleted() {
        let events = episodes.map { Fixtures.event($0) } + [Fixtures.event(episodes[0])]
        let progress = Progress.compute(episodes: episodes, events: events, today: Fixtures.today)
        #expect(StatusEngine.status(after: .log, current: .completed, kind: .show, progress: progress, showStatus: .ended) == .completed)
    }

    // MARK: Status updated after refresh

    @Test func newEpisodeAirsMovesCaughtUpToWatching() {
        #expect(show(.refresh, .caughtUp, watched: 2) == .watching)
    }

    @Test func showEndsMovesCaughtUpToCompleted() {
        #expect(show(.refresh, .caughtUp, watched: 3, .ended) == .completed)
    }

    @Test(arguments: [ListStatus.onHold, .dropped, .planToWatch, .completed])
    func refreshLeavesOtherStatusesAlone(current: ListStatus) {
        #expect(show(.refresh, current, watched: 2) == current)
    }

    @Test func manualCompletedSurvivesRefresh() {
        #expect(show(.refresh, .completed, watched: 1) == .completed)
    }

    // MARK: Status updated after unmarking

    @Test func unmarkFromCaughtUpMakesWatching() {
        #expect(show(.unmark, .caughtUp, watched: 2) == .watching)
        #expect(show(.unmark, .completed, watched: 2, .ended) == .watching)
    }

    @Test(arguments: [ListStatus.onHold, .dropped, .watching, .planToWatch])
    func unmarkLeavesOtherStatusesAlone(current: ListStatus) {
        #expect(show(.unmark, current, watched: 0) == current)
    }

    @Test func unmarkingLastMovieEventReturnsToPlanToWatch() {
        let empty = Progress.compute(episodes: [], events: [], today: Fixtures.today)
        #expect(StatusEngine.status(after: .unmark, current: .completed, kind: .movie, progress: empty, showStatus: .unknown) == .planToWatch)
        let watched = Progress.compute(episodes: [], events: [Fixtures.movieEvent()], today: Fixtures.today)
        #expect(StatusEngine.status(after: .unmark, current: .completed, kind: .movie, progress: watched, showStatus: .unknown) == .completed)
    }

    // MARK: Manual override

    @Test func droppedShowIsNotChangedByRefresh() {
        // Manual Dropped persists until a log; Up Next exclusion is covered in the up-next tests.
        #expect(show(.refresh, .dropped, watched: 1) == .dropped)
        #expect(show(.log, .dropped, watched: 1) == .watching)
    }

    // MARK: Setting to Completed (LIB-299)

    @Test func returningShowCompletedByBulkMarkBecomesCompleted() {
        let ended = Fixtures.season(1, count: 3)
        let events = ended.map { Fixtures.event($0) }
        let progress = Progress.compute(episodes: ended, events: events, today: Fixtures.today)
        #expect(StatusEngine.status(after: .log, current: .watching, kind: .show, progress: progress, showStatus: .ended) == .completed)
    }

    @Test func returningShowCompletedByBulkMarkBecomesCaughtUp() {
        let returning = Fixtures.season(1, count: 3)
        let events = returning.map { Fixtures.event($0) }
        let progress = Progress.compute(episodes: returning, events: events, today: Fixtures.today)
        #expect(StatusEngine.status(after: .log, current: .watching, kind: .show, progress: progress, showStatus: .returning) == .caughtUp)
    }
}
