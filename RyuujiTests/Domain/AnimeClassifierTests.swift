import Testing
@testable import Ryuuji

struct AnimeClassifierTests {
    @Test func japaneseAnimatedShowIsAnime() {
        #expect(AnimeClassifier.isAnime(genreIds: [16, 10759], originCountries: ["JP"], originalLanguage: "ja"))
    }

    @Test func japaneseLanguageAloneQualifies() {
        #expect(AnimeClassifier.isAnime(genreIds: [16], originCountries: [], originalLanguage: "ja"))
    }

    @Test func westernAnimatedShowIsNotAnime() {
        #expect(!AnimeClassifier.isAnime(genreIds: [16], originCountries: ["US"], originalLanguage: "en"))
    }

    @Test func liveActionJapaneseShowIsNotAnime() {
        #expect(!AnimeClassifier.isAnime(genreIds: [18], originCountries: ["JP"], originalLanguage: "ja"))
    }
}
