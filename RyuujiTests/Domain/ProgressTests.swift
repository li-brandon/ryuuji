import Foundation
import Testing
@testable import Ryuuji

struct ProgressTests {
    let e = Fixtures.episode

    @Test func progressCountsDistinctEpisodes() {
        let episodes = Fixtures.season(1, count: 4)
        let events = [Fixtures.event(episodes[0]), Fixtures.event(episodes[1]), Fixtures.event(episodes[1])]
        let progress = Progress.compute(episodes: episodes, events: events, today: Fixtures.today)
        #expect(progress.watchedAiredRegularCount == 2)
        #expect(progress.remaining == 2)
        #expect(progress.next == episodes[2])
    }

    @Test func nextEpisodeFillsGaps() {
        let episodes = Fixtures.season(1, count: 3)
        let events = [Fixtures.event(episodes[0]), Fixtures.event(episodes[2])]
        let progress = Progress.compute(episodes: episodes, events: events, today: Fixtures.today)
        #expect(progress.next == episodes[1])
    }

    @Test func nextEpisodeCrossesSeasons() {
        let episodes = Fixtures.season(2, count: 2) + Fixtures.season(1, count: 2)
        let events = Fixtures.season(1, count: 2).map { Fixtures.event($0) }
        let progress = Progress.compute(episodes: episodes, events: events, today: Fixtures.today)
        #expect(progress.next == e(2, 1, Fixtures.past, nil))
    }

    @Test func futureEpisodeIsUnaired() {
        let episodes = [e(1, 1, Fixtures.past, nil), e(1, 2, Fixtures.future, nil)]
        let progress = Progress.compute(episodes: episodes, events: [Fixtures.event(episodes[0])], today: Fixtures.today)
        #expect(progress.next == nil)
        #expect(progress.remaining == 0)
        #expect(!episodes[1].isAired(today: Fixtures.today))
    }

    @Test func episodeAiringTodayIsAired() {
        #expect(e(1, 1, Fixtures.today, nil).isAired(today: Fixtures.today))
    }

    @Test func missingAirDateIsUnaired() {
        let episodes = [e(1, 1, nil, nil)]
        let progress = Progress.compute(episodes: episodes, events: [], today: Fixtures.today)
        #expect(!episodes[0].isAired(today: Fixtures.today))
        #expect(progress.next == nil)
        #expect(!progress.hasAiredRegular)
    }

    @Test func unwatchedSpecialsDoNotBlockCompletion() {
        let regular = Fixtures.season(1, count: 2)
        let specials = Fixtures.season(0, count: 3)
        let progress = Progress.compute(
            episodes: specials + regular,
            events: regular.map { Fixtures.event($0) },
            today: Fixtures.today
        )
        #expect(progress.remaining == 0)
        #expect(progress.next == nil)
        #expect(progress.airedRegular.count == 2)
    }

    @Test func watchedSpecialsCountForTheirOwnRow() {
        let special = e(0, 1, Fixtures.past, nil)
        let progress = Progress.compute(episodes: [special], events: [Fixtures.event(special)], today: Fixtures.today)
        #expect(progress.isWatched(special))
        #expect(progress.watchedAiredRegularCount == 0)
    }

    @Test func rewatchCountIsEventsMinusOne() {
        let episode = e(1, 1, Fixtures.past, nil)
        let events = Array(repeating: Fixtures.event(episode), count: 3)
        let progress = Progress.compute(episodes: [episode], events: events, today: Fixtures.today)
        #expect(progress.watchCount(of: episode) == 3)
        #expect(progress.rewatchCount(of: episode) == 2)
    }

    @Test func eventsMatchByTMDBIdBeforeNumbers() {
        // TMDB renumbered: the episode with id 1013 now lives at S2E1.
        let renumbered = EpisodeInfo(tmdbId: 1013, season: 2, number: 1, name: "Moved", airDate: Fixtures.past)
        let event = EventRef(season: 1, episode: 13, tmdbEpisodeId: 1013, watchedAt: .now)
        let progress = Progress.compute(episodes: [renumbered], events: [event], today: Fixtures.today)
        #expect(progress.isWatched(renumbered))
        #expect(progress.orphanCount == 0)
    }

    @Test func eventsWithoutIdMatchByNumbers() {
        let episode = e(1, 2, Fixtures.past, nil)
        let event = EventRef(season: 1, episode: 2, tmdbEpisodeId: nil, watchedAt: .now)
        let progress = Progress.compute(episodes: [episode], events: [event], today: Fixtures.today)
        #expect(progress.isWatched(episode))
    }

    @Test func unmatchedEventsAreOrphans() {
        let episode = e(1, 1, Fixtures.past, nil)
        let gone = EventRef(season: 1, episode: 9, tmdbEpisodeId: 99_999, watchedAt: .now)
        let progress = Progress.compute(episodes: [episode], events: [gone], today: Fixtures.today)
        #expect(progress.orphanCount == 1)
        #expect(progress.eventCount == 1)
        #expect(!progress.isWatched(episode))
    }

    @Test func movieEventCount() {
        let progress = Progress.compute(episodes: [], events: [Fixtures.movieEvent(), Fixtures.movieEvent()], today: Fixtures.today)
        #expect(progress.eventCount == 2)
    }
}
