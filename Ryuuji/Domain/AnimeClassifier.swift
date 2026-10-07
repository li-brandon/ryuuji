/// Decides whether a TMDB title counts as anime.
nonisolated enum AnimeClassifier {
    /// TMDB's genre id for Animation (same id for movies and TV).
    static let animationGenreId = 16

    /// Anime = Animation genre and (Japanese origin country or Japanese original language).
    static func isAnime(genreIds: [Int], originCountries: [String], originalLanguage: String?) -> Bool {
        guard genreIds.contains(animationGenreId) else { return false }
        return originCountries.contains("JP") || originalLanguage == "ja"
    }
}
