import Foundation

// Decodable TMDB v3 responses. Decoded with `.convertFromSnakeCase`.

nonisolated struct TMDBGenre: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct TMDBSearchResponse: Decodable, Sendable {
    let results: [TMDBSearchResult]
}

nonisolated struct TMDBSearchResult: Decodable, Hashable, Sendable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let genreIds: [Int]?
    let originCountry: [String]?
    let originalLanguage: String?
    let overview: String?
}

nonisolated struct TMDBMovie: Decodable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let runtime: Int?
    let genres: [TMDBGenre]
    let originCountry: [String]?
    let productionCountries: [ProductionCountry]?
    let originalLanguage: String?

    nonisolated struct ProductionCountry: Decodable, Sendable {
        let iso31661: String
    }

    /// `origin_country` when present, else production countries.
    var countries: [String] {
        if let originCountry, !originCountry.isEmpty { return originCountry }
        return productionCountries?.map(\.iso31661) ?? []
    }
}

nonisolated struct TMDBShow: Decodable, Sendable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let firstAirDate: String?
    let status: String?
    let genres: [TMDBGenre]
    let originCountry: [String]?
    let originalLanguage: String?
    let episodeRunTime: [Int]?
    let seasons: [SeasonSummary]?

    nonisolated struct SeasonSummary: Decodable, Sendable {
        let seasonNumber: Int
        let name: String?
        let episodeCount: Int?
    }
}

nonisolated struct TMDBSeason: Decodable, Sendable {
    let seasonNumber: Int
    let name: String?
    let episodes: [TMDBEpisode]
}

nonisolated struct TMDBEpisode: Decodable, Sendable {
    let id: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let name: String?
    let airDate: String?
    let runtime: Int?
}

/// A `/tv/{id}?append_to_response=season/1,...` response: the seasons appear under
/// dynamic "season/N" keys.
nonisolated struct TMDBAppendedSeasons: Decodable, Sendable {
    let seasons: [TMDBSeason]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        seasons = try container.allKeys
            .filter { $0.stringValue.hasPrefix("season/") }
            .map { try container.decode(TMDBSeason.self, forKey: $0) }
            .sorted { $0.seasonNumber < $1.seasonNumber }
    }
}

/// A show with all of its seasons' episodes.
nonisolated struct TMDBShowDetails: Sendable {
    let show: TMDBShow
    let seasons: [TMDBSeason]
}

nonisolated enum TMDBJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
