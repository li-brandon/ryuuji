import Foundation
import Testing
@testable import Ryuuji

/// Decoding and mapping against TMDB JSON fixtures (scripts/record-tmdb-fixtures.sh).
struct TMDBDecodingTests {
    func spyFamily() throws -> TMDBShowDetails {
        let show = try FixtureFile.decode(TMDBShow.self, "tv-120089")
        let appended = try FixtureFile.decode(TMDBAppendedSeasons.self, "tv-120089-seasons")
        return TMDBShowDetails(show: show, seasons: appended.seasons)
    }

    // MARK: Search

    @Test func searchKeepsOnlyMoviesAndShows() throws {
        let response = try FixtureFile.decode(TMDBSearchResponse.self, "search-frieren")
        let items = response.results.compactMap(SearchItem.init)
        #expect(!items.isEmpty)
        #expect(items.count == response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }.count)

        let frieren = try #require(items.first { $0.tmdbId == 209867 })
        #expect(frieren.kind == .show)
        #expect(frieren.year == "2023")
        #expect(frieren.isAnime)
        #expect(frieren.posterPath != nil)
    }

    @Test func emptyReleaseDateHasNoYear() throws {
        let json = #"{"id": 1, "media_type": "movie", "title": "X", "release_date": ""}"#
        let result = try TMDBJSON.decoder.decode(TMDBSearchResult.self, from: Data(json.utf8))
        #expect(SearchItem(result)?.year == nil)
    }

    @Test func personResultsAreDropped() throws {
        let json = #"{"id": 1, "media_type": "person", "name": "Someone"}"#
        let result = try TMDBJSON.decoder.decode(TMDBSearchResult.self, from: Data(json.utf8))
        #expect(SearchItem(result) == nil)
    }

    // MARK: Movie

    @Test func movieDecodesAndMaps() throws {
        let movie = try FixtureFile.decode(TMDBMovie.self, "movie-372058")
        #expect(movie.id == 372058)
        #expect(movie.countries.contains("JP"))

        let title = Title(tmdbId: movie.id, kind: .movie)
        TitleMapper.apply(movie, to: title)
        #expect(title.name == "Your Name.")
        #expect(title.year == "2016")
        #expect(title.runtime == movie.runtime)
        #expect(title.genres.contains("Animation"))
        #expect(title.isAnime)
        #expect(title.seasons.isEmpty)
    }

    // MARK: Show

    @Test func showSeasonsDecodeFromAppendedKeys() throws {
        let details = try spyFamily()
        let regular = details.seasons.filter { $0.seasonNumber > 0 }
        #expect(regular.count >= 2)
        #expect(details.seasons.map(\.seasonNumber) == details.seasons.map(\.seasonNumber).sorted())
        for season in details.seasons {
            #expect(!season.episodes.isEmpty)
            #expect(season.episodes.allSatisfy { $0.seasonNumber == season.seasonNumber })
        }
    }

    @Test func showMapsToTitleAndEpisodeBlob() throws {
        let details = try spyFamily()
        let title = Title(tmdbId: 120089, kind: .show)
        TitleMapper.apply(details, to: title)

        #expect(title.name == "SPY x FAMILY")
        #expect(title.isAnime)
        #expect(title.showStatus != .unknown)
        #expect(title.year == "2022")
        #expect(title.seasons.count == details.seasons.count)
        #expect(title.allEpisodes.count == details.seasons.reduce(0) { $0 + $1.episodes.count })
        #expect(title.allEpisodes.allSatisfy { $0.airDate != "" })
        #expect(title.seasons.first { $0.isSpecials }?.name != nil)
    }

    @Test func seasonBatchesRespectTMDBLimit() {
        let batches = LiveTMDBClient.batches(of: Array(0...44))
        #expect(batches.map(\.count) == [20, 20, 5])
        #expect(LiveTMDBClient.batches(of: []).isEmpty)
    }

    @Test func missingTokenFailsBeforeNetwork() async {
        let client = LiveTMDBClient(token: nil)
        await #expect(throws: TMDBError.missingToken) {
            try await client.search("frieren")
        }
    }
}
