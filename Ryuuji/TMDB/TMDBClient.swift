import Foundation

nonisolated enum TMDBError: LocalizedError, Equatable {
    case missingToken
    case httpStatus(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "A TMDB API token is required. Add it to Config/Secrets.xcconfig and rebuild (see README)."
        case .httpStatus(401):
            "TMDB rejected the API token. Check Config/Secrets.xcconfig."
        case .httpStatus(let code):
            "TMDB returned an error (HTTP \(code))."
        case .invalidResponse:
            "TMDB returned a response Ryuuji couldn't read."
        }
    }
}

/// Read-only access to the TMDB endpoints Ryuuji uses (design D7).
nonisolated protocol TMDBClient: Sendable {
    /// Movies and TV shows matching `query`; people are excluded.
    func search(_ query: String) async throws -> [TMDBSearchResult]
    func movie(id: Int) async throws -> TMDBMovie
    /// A show plus every season's episodes.
    func show(id: Int) async throws -> TMDBShowDetails
}

nonisolated struct LiveTMDBClient: TMDBClient {
    /// TMDB caps append_to_response at 20 sub-requests.
    static let seasonBatchSize = 20

    let token: String?
    var session: URLSession = .shared
    var baseURL = URL(string: "https://api.themoviedb.org/3")!

    func search(_ query: String) async throws -> [TMDBSearchResult] {
        let response: TMDBSearchResponse = try await get("search/multi", query: [
            "query": query,
            "include_adult": "false",
            "page": "1",
        ])
        return response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
    }

    func movie(id: Int) async throws -> TMDBMovie {
        try await get("movie/\(id)")
    }

    func show(id: Int) async throws -> TMDBShowDetails {
        let show: TMDBShow = try await get("tv/\(id)")
        let numbers = (show.seasons ?? []).map(\.seasonNumber)
        var seasons: [TMDBSeason] = []
        for batch in Self.batches(of: numbers) {
            let appended: TMDBAppendedSeasons = try await get("tv/\(id)", query: [
                "append_to_response": batch.map { "season/\($0)" }.joined(separator: ","),
            ])
            seasons += appended.seasons
        }
        return TMDBShowDetails(show: show, seasons: seasons.sorted { $0.seasonNumber < $1.seasonNumber })
    }

    static func batches(of numbers: [Int]) -> [[Int]] {
        stride(from: 0, to: numbers.count, by: seasonBatchSize).map {
            Array(numbers[$0..<min($0 + seasonBatchSize, numbers.count)])
        }
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        guard let token, !token.isEmpty else { throw TMDBError.missingToken }

        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = (["language": "en-US"].merging(query) { $1 })
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TMDBError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw TMDBError.httpStatus(http.statusCode) }
        do {
            return try TMDBJSON.decoder.decode(T.self, from: data)
        } catch {
            throw TMDBError.invalidResponse
        }
    }
}

/// TMDB image CDN URLs (design D10).
nonisolated enum TMDBImage {
    enum Size: String {
        case list = "w185"
        case detail = "w342"
    }

    static func url(_ path: String?, size: Size) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\(path)")
    }
}
