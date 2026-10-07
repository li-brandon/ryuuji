import Foundation
import Synchronization
@testable import Ryuuji

private nonisolated final class BundleToken {}

/// Loads JSON fixtures copied into the test bundle.
nonisolated enum FixtureFile {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try TMDBJSON.decoder.decode(T.self, from: data(name))
    }
}

/// An in-memory TMDB client whose responses tests can swap.
nonisolated final class FakeTMDBClient: TMDBClient, Sendable {
    private let state = Mutex(State())

    struct State {
        var movies: [Int: TMDBMovie] = [:]
        var shows: [Int: TMDBShowDetails] = [:]
        var searchResults: [TMDBSearchResult] = []
        var failing = false
        var requestCount = 0
    }

    func update(_ body: (inout State) throws -> Void) rethrows {
        try state.withLock { try body(&$0) }
    }

    var requestCount: Int { state.withLock { $0.requestCount } }

    func search(_ query: String) async throws -> [TMDBSearchResult] {
        try state.withLock { s in
            s.requestCount += 1
            if s.failing { throw TMDBError.httpStatus(503) }
            return s.searchResults
        }
    }

    func movie(id: Int) async throws -> TMDBMovie {
        try state.withLock { s in
            s.requestCount += 1
            if s.failing { throw TMDBError.httpStatus(503) }
            guard let movie = s.movies[id] else { throw TMDBError.httpStatus(404) }
            return movie
        }
    }

    func show(id: Int) async throws -> TMDBShowDetails {
        try state.withLock { s in
            s.requestCount += 1
            if s.failing { throw TMDBError.httpStatus(503) }
            guard let show = s.shows[id] else { throw TMDBError.httpStatus(404) }
            return show
        }
    }
}

/// Builds TMDB response values in code for refresh tests.
nonisolated enum TMDBBuilder {
    static func show(id: Int, status: String = "Returning Series", episodes: [EpisodeInfo]) throws -> TMDBShowDetails {
        let showJSON: [String: Any] = [
            "id": id, "name": "Show \(id)", "genres": [["id": 16, "name": "Animation"]],
            "origin_country": ["JP"], "original_language": "ja", "status": status,
        ]
        let show = try TMDBJSON.decoder.decode(TMDBShow.self, from: JSONSerialization.data(withJSONObject: showJSON))
        let seasons = try Dictionary(grouping: episodes, by: \.season).sorted { $0.key < $1.key }.map { number, eps in
            let json: [String: Any] = [
                "season_number": number,
                "name": "Season \(number)",
                "episodes": eps.map { e -> [String: Any] in
                    ["id": e.tmdbId, "season_number": e.season, "episode_number": e.number, "name": e.name, "air_date": e.airDate ?? ""]
                },
            ]
            return try TMDBJSON.decoder.decode(TMDBSeason.self, from: JSONSerialization.data(withJSONObject: json))
        }
        return TMDBShowDetails(show: show, seasons: seasons)
    }
}
