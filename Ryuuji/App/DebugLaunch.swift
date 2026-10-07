import Foundation
import SwiftData

/// Debug-only launch options for trying the UI without touching the real store:
///   -RyuujiInMemory YES     use an empty in-memory store
///   -RyuujiSampleData YES   seed sample titles (only into an in-memory store)
///   -RyuujiStorePath /tmp/x.store        use a scratch on-disk store
///   -RyuujiStartView library|history     open on a sidebar item
///   -RyuujiOpenTitle show:120089         open a title's detail view
///   -RyuujiQuickAdd "frieren"            open Cmd-K with this query typed
enum DebugLaunch {
    /// Applies the start-view flags to fresh window state.
    static func configure(_ state: AppState) {
        #if DEBUG
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "RyuujiStartView") {
        case "library": state.sidebar = .library
        case "history": state.sidebar = .history
        default: break
        }
        if let raw = defaults.string(forKey: "RyuujiOpenTitle") {
            let parts = raw.split(separator: ":")
            if parts.count == 2, let kind = Kind(rawValue: String(parts[0])), let id = Int(parts[1]) {
                state.path = [TitleRoute(key: TitleKey(tmdbId: id, kind: kind))]
            }
        }
        if let query = defaults.string(forKey: "RyuujiQuickAdd") {
            state.quickAddSeedQuery = query
            state.isQuickAddPresented = true
        }
        #endif
    }

    static var inMemoryStore: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "RyuujiInMemory")
        #else
        false
        #endif
    }

    static var storeURL: URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "RyuujiStorePath").map { URL(fileURLWithPath: $0) }
        #else
        nil
        #endif
    }

    static func seedIfRequested(_ context: ModelContext) {
        #if DEBUG
        guard inMemoryStore, UserDefaults.standard.bool(forKey: "RyuujiSampleData") else { return }
        SampleData.insert(into: context)
        #endif
    }
}

#if DEBUG
/// Sample library with air dates relative to today, so every view has something to show.
enum SampleData {
    static func insert(into context: ModelContext) {
        let now = Date.now
        func day(_ offset: Int) -> String {
            AirDate.today(now: Calendar.current.date(byAdding: .day, value: offset, to: now)!)
        }
        func ago(hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        func show(
            _ id: Int, _ name: String, poster: String?, year: String, status: ListStatus,
            showStatus: ShowStatus, anime: Bool, seasons: [(Int, Int)], unaired: Int = 0,
            watched: Int, added: Date
        ) {
            let title = Title(tmdbId: id, kind: .show, name: name, status: status, addedAt: added)
            title.posterPath = poster
            title.releaseDate = "\(year)-01-01"
            title.showStatusRaw = showStatus.rawValue
            title.isAnime = anime
            title.overview = "Sample data for \(name)."
            var infos: [SeasonInfo] = []
            var offset = -400
            for (season, count) in seasons {
                var episodes: [EpisodeInfo] = []
                for number in 1...count {
                    episodes.append(EpisodeInfo(
                        tmdbId: id * 10_000 + season * 100 + number, season: season, number: number,
                        name: season == 0 ? "Special \(number)" : "Episode \(number)",
                        airDate: day(offset), runtime: 24))
                    offset += 7
                }
                infos.append(SeasonInfo(number: season, name: season == 0 ? "Specials" : "Season \(season)", episodes: episodes))
            }
            if unaired > 0, let last = infos.indices.last {
                let season = infos[last].number
                let start = infos[last].episodes.count
                for n in 1...unaired {
                    infos[last].episodes.append(EpisodeInfo(
                        tmdbId: id * 10_000 + season * 100 + start + n, season: season, number: start + n,
                        name: "Episode \(start + n)", airDate: n == unaired ? nil : day(n * 7), runtime: 24))
                }
            }
            title.setSeasons(infos)
            context.insert(title)

            let regular = infos.filter { $0.number > 0 }.flatMap(\.episodes)
            // Events carry season/episode only, so a live refresh matches them to real TMDB episodes.
            for (index, episode) in regular.prefix(watched).enumerated() {
                let event = WatchEvent(
                    watchedAt: ago(hours: Double(watched - index) * 20),
                    season: episode.season, episode: episode.number)
                context.insert(event)
                event.title = title
            }
        }

        show(120089, "SPY x FAMILY", poster: "/3r4LYFuXrg3G8fepysr4xSLWnQL.jpg", year: "2022", status: .watching,
             showStatus: .returning, anime: true, seasons: [(0, 1), (1, 25), (2, 12)], unaired: 2, watched: 30, added: ago(hours: 900))
        show(209867, "Frieren: Beyond Journey's End", poster: "/dqZENchTd7lp5zht7BdlqM7RBhD.jpg", year: "2023", status: .watching,
             showStatus: .returning, anime: true, seasons: [(1, 28)], watched: 5, added: ago(hours: 500))
        show(1396, "Breaking Bad", poster: "/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg", year: "2008", status: .completed,
             showStatus: .ended, anime: false, seasons: [(1, 7), (2, 13)], watched: 20, added: ago(hours: 2000))
        show(95396, "Severance", poster: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg", year: "2022", status: .caughtUp,
             showStatus: .returning, anime: false, seasons: [(1, 9)], unaired: 1, watched: 9, added: ago(hours: 300))
        show(100088, "The Last of Us", poster: "/uKvVjHNqB5VmOrdxqAt2F7J78ED.jpg", year: "2023", status: .onHold,
             showStatus: .returning, anime: false, seasons: [(1, 9)], watched: 3, added: ago(hours: 700))
        show(37854, "One Piece", poster: "/cMD9Ygz11zjJzAovURpO75Qg7rT.jpg", year: "1999", status: .planToWatch,
             showStatus: .returning, anime: true, seasons: [(1, 61)], watched: 0, added: ago(hours: 100))

        let movie = Title(tmdbId: 372058, kind: .movie, name: "Your Name.", status: .completed, addedAt: ago(hours: 1500))
        movie.posterPath = "/q719jXXEzOoYaps6babgKnONONX.jpg"
        movie.releaseDate = "2016-08-26"
        movie.runtime = 106
        movie.isAnime = true
        movie.score = 9
        context.insert(movie)
        let watch = WatchEvent(watchedAt: ago(hours: 30))
        context.insert(watch)
        watch.title = movie

        let planned = Title(tmdbId: 129, kind: .movie, name: "Spirited Away", status: .planToWatch, addedAt: ago(hours: 50))
        planned.posterPath = "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg"
        planned.releaseDate = "2001-07-20"
        planned.runtime = 125
        planned.isAnime = true
        context.insert(planned)

        try? context.save()
    }
}
#endif
