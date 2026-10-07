import Foundation

/// A search result reduced to what the quick-add panel shows.
nonisolated struct SearchItem: Hashable, Identifiable, Sendable {
    var tmdbId: Int
    var kind: Kind
    var name: String
    var year: String?
    var posterPath: String?
    var isAnime: Bool

    var id: String { "\(kind.rawValue)-\(tmdbId)" }
    var key: TitleKey { TitleKey(tmdbId: tmdbId, kind: kind) }

    init?(_ result: TMDBSearchResult) {
        let kind: Kind
        switch result.mediaType {
        case "movie": kind = .movie
        case "tv": kind = .show
        default: return nil
        }
        self.tmdbId = result.id
        self.kind = kind
        self.name = (kind == .movie ? result.title : result.name) ?? result.name ?? result.title ?? "Untitled"
        self.year = AirDate.year(from: kind == .movie ? result.releaseDate : result.firstAirDate)
        self.posterPath = result.posterPath
        self.isAnime = AnimeClassifier.isAnime(
            genreIds: result.genreIds ?? [],
            originCountries: result.originCountry ?? [],
            originalLanguage: result.originalLanguage
        )
    }
}

/// Fetched metadata for one title, ready to apply.
nonisolated enum FetchedMetadata: Sendable {
    case movie(TMDBMovie)
    case show(TMDBShowDetails)
}

nonisolated extension TMDBClient {
    func metadata(for key: TitleKey) async throws -> FetchedMetadata {
        switch key.kind {
        case .movie: .movie(try await movie(id: key.tmdbId))
        case .show: .show(try await show(id: key.tmdbId))
        }
    }
}

/// Writes TMDB responses onto `Title`s.
nonisolated enum TitleMapper {
    static func apply(_ metadata: FetchedMetadata, to title: Title) {
        switch metadata {
        case .movie(let movie): apply(movie, to: title)
        case .show(let details): apply(details, to: title)
        }
    }

    static func apply(_ movie: TMDBMovie, to title: Title) {
        title.name = movie.title
        title.originalName = movie.originalTitle ?? movie.title
        title.overview = movie.overview ?? ""
        title.posterPath = movie.posterPath
        title.releaseDate = nonEmpty(movie.releaseDate)
        title.runtime = movie.runtime
        title.genres = movie.genres.map(\.name)
        title.originCountries = movie.countries
        title.originalLanguage = movie.originalLanguage ?? ""
        title.isAnime = AnimeClassifier.isAnime(
            genreIds: movie.genres.map(\.id),
            originCountries: movie.countries,
            originalLanguage: movie.originalLanguage
        )
    }

    static func apply(_ details: TMDBShowDetails, to title: Title) {
        let show = details.show
        title.name = show.name
        title.originalName = show.originalName ?? show.name
        title.overview = show.overview ?? ""
        title.posterPath = show.posterPath
        title.releaseDate = nonEmpty(show.firstAirDate)
        title.runtime = show.episodeRunTime?.first
        title.genres = show.genres.map(\.name)
        title.originCountries = show.originCountry ?? []
        title.originalLanguage = show.originalLanguage ?? ""
        title.showStatusRaw = show.status
        title.isAnime = AnimeClassifier.isAnime(
            genreIds: show.genres.map(\.id),
            originCountries: show.originCountry ?? [],
            originalLanguage: show.originalLanguage
        )
        MetadataApplier.applySeasons(seasons(from: details), to: title)
    }

    static func seasons(from details: TMDBShowDetails) -> [SeasonInfo] {
        details.seasons.map { season in
            SeasonInfo(
                number: season.seasonNumber,
                name: season.name ?? (season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)"),
                episodes: season.episodes.map { episode in
                    EpisodeInfo(
                        tmdbId: episode.id,
                        season: episode.seasonNumber,
                        number: episode.episodeNumber,
                        name: episode.name ?? "Episode \(episode.episodeNumber)",
                        airDate: nonEmpty(episode.airDate),
                        runtime: episode.runtime
                    )
                }
            )
        }
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }
        return string
    }
}

/// Replaces a show's cached episodes without losing watch history (design D4).
nonisolated enum MetadataApplier {
    static func applySeasons(_ seasons: [SeasonInfo], to title: Title) {
        title.setSeasons(seasons)

        // Rewrite matched events to TMDB's current numbering; orphans are left untouched.
        let matcher = EpisodeMatcher(episodes: seasons.flatMap(\.episodes))
        for event in title.eventList where !event.isMovieEvent {
            guard let episode = matcher.match(event.ref) else { continue }
            if event.season != episode.season { event.season = episode.season }
            if event.episode != episode.number { event.episode = episode.number }
            if event.tmdbEpisodeId != episode.tmdbId { event.tmdbEpisodeId = episode.tmdbId }
        }
    }
}
