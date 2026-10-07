import Foundation
import Observation
import SwiftData

/// Adds search results to the list (title-search spec).
@Observable
final class TitleAdder {
    enum Outcome {
        /// A new title was fetched and inserted.
        case added(Title)
        /// The title was already in the list; nothing was created.
        case existing(Title)
    }

    private let context: ModelContext
    private let client: any TMDBClient
    private let watchLog: WatchLogService
    private let now: () -> Date

    init(context: ModelContext, client: any TMDBClient, watchLog: WatchLogService, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.client = client
        self.watchLog = watchLog
        self.now = now
    }

    /// Fetches full metadata and inserts the title with `status`. Throws without inserting
    /// anything if TMDB can't be reached.
    func add(_ item: SearchItem, status: ListStatus) async throws -> Outcome {
        if let existing = try TitleRepository.find(tmdbId: item.tmdbId, kind: item.kind, in: context) {
            return .existing(existing)
        }

        let metadata = try await client.metadata(for: item.key)

        // Another add may have finished while we were fetching.
        if let existing = try TitleRepository.find(tmdbId: item.tmdbId, kind: item.kind, in: context) {
            return .existing(existing)
        }

        let title = Title(tmdbId: item.tmdbId, kind: item.kind, name: item.name, status: status, addedAt: now())
        context.insert(title)
        TitleMapper.apply(metadata, to: title)
        title.lastRefreshedAt = now()
        try context.save()

        if item.kind == .movie && status == .completed {
            watchLog.log(nil, of: title, undoManager: nil)
        }
        return .added(title)
    }
}
