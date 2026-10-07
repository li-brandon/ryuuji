import Foundation
import SwiftData
import Testing
@testable import Ryuuji

struct ModelTests {
    @Test func insertAndFetchTitleWithEvents() throws {
        let container = try RyuujiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let title = Title(tmdbId: 209867, kind: .show, name: "Frieren")
        title.setSeasons(Fixtures.seasons(from: Fixtures.season(1, count: 3)))
        context.insert(title)
        let event = WatchEvent(watchedAt: .now, season: 1, episode: 1, tmdbEpisodeId: 1001)
        event.title = title
        try context.save()

        let titles = try context.fetch(FetchDescriptor<Title>())
        #expect(titles.count == 1)
        #expect(titles[0].kind == .show)
        #expect(titles[0].allEpisodes.count == 3)
        #expect(titles[0].eventList.count == 1)
        #expect(try context.fetch(FetchDescriptor<WatchEvent>()).first?.title?.name == "Frieren")
    }

    @Test func seasonsReflectNewRevision() throws {
        let container = try RyuujiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let title = Title(tmdbId: 1, kind: .show)
        context.insert(title)
        title.setSeasons(Fixtures.seasons(from: Fixtures.season(1, count: 2)))
        #expect(title.allEpisodes.count == 2)
        title.setSeasons(Fixtures.seasons(from: Fixtures.season(1, count: 5)))
        #expect(title.allEpisodes.count == 5)
    }

    @Test func deletingTitleCascadesEvents() throws {
        let container = try RyuujiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let title = Title(tmdbId: 1, kind: .movie)
        context.insert(title)
        let event = WatchEvent(watchedAt: .now)
        event.title = title
        try context.save()

        context.delete(title)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<WatchEvent>()) == 0)
    }

    @Test func statusAccessorsUseRawStrings() {
        let title = Title(tmdbId: 1, kind: .show)
        title.status = .caughtUp
        #expect(title.statusRaw == "caughtUp")
        title.showStatusRaw = "Ended"
        #expect(title.showStatus == .ended)
    }

    @Test func unreadableEpisodeBlobNeedsRefresh() {
        let title = Title(tmdbId: 1, kind: .show)
        title.episodesData = Data("garbage".utf8)
        #expect(title.needsEpisodeRefresh)
        #expect(title.seasons.isEmpty)
    }
}

struct TitleRepositoryTests {
    @Test func addingSameTitleTwiceYieldsOne() throws {
        let container = try RyuujiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let first = try TitleRepository.insertIfAbsent(tmdbId: 42, kind: .show, in: context)
        try context.save()
        let second = try TitleRepository.insertIfAbsent(tmdbId: 42, kind: .show, in: context)

        #expect(first.inserted)
        #expect(!second.inserted)
        #expect(first.title === second.title)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 1)
    }

    @Test func sameIdDifferentKindAreDistinct() throws {
        let container = try RyuujiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try TitleRepository.insertIfAbsent(tmdbId: 42, kind: .show, in: context)
        try TitleRepository.insertIfAbsent(tmdbId: 42, kind: .movie, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Title>()) == 2)
    }
}
