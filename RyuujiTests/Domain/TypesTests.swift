import Foundation
import Testing
@testable import Ryuuji

struct TypesTests {
    @Test func episodeMetadataRoundTrips() {
        let metadata = EpisodeMetadata(seasons: [
            SeasonInfo(number: 1, name: "Season 1", episodes: [
                EpisodeInfo(tmdbId: 10, season: 1, number: 1, name: "Pilot", airDate: "2024-01-05", runtime: 24),
                EpisodeInfo(tmdbId: 11, season: 1, number: 2, name: "Two", airDate: nil, runtime: nil),
            ])
        ])
        #expect(EpisodeMetadata.decode(metadata.encoded()) == metadata)
    }

    @Test func corruptOrUnknownVersionDecodesToNil() {
        #expect(EpisodeMetadata.decode(Data()) == nil)
        #expect(EpisodeMetadata.decode(Data("nope".utf8)) == nil)
        var future = EpisodeMetadata(seasons: [])
        future.schemaVersion = 99
        #expect(EpisodeMetadata.decode(future.encoded()) == nil)
    }

    @Test func statusAndKindRoundTripThroughJSON() throws {
        let statuses = ListStatus.allCases
        let data = try JSONEncoder().encode(statuses)
        #expect(try JSONDecoder().decode([ListStatus].self, from: data) == statuses)
        #expect(Kind(rawValue: Kind.show.rawValue) == .show)
    }

    @Test func showStatusMapsTMDBStrings() {
        #expect(ShowStatus(tmdb: "Returning Series") == .returning)
        #expect(ShowStatus(tmdb: "Ended").isFinished)
        #expect(ShowStatus(tmdb: "Canceled").isFinished)
        #expect(ShowStatus(tmdb: "Something New") == .unknown)
        #expect(ShowStatus(tmdb: nil) == .unknown)
    }

    @Test func todayFormatsLocalDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-03-02 05:00 UTC is still March 1 in Los Angeles.
        let instant = Date(timeIntervalSince1970: 1_772_427_600)
        #expect(AirDate.today(now: instant, calendar: calendar) == "2026-03-01")
    }
}
