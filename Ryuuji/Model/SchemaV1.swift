import Foundation
import SwiftData

/// Version 1 of the persisted schema.
///
/// CloudKit rules (design D2): every attribute has a default or is optional, every
/// relationship is optional, no unique constraints, enums stored as raw strings.
nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Title.self, WatchEvent.self] }

    /// A tracked movie or show: cached TMDB metadata plus the user's list fields.
    @Model
    final class Title {
        // Identity
        var tmdbId: Int = 0
        var kindRaw: String = Kind.show.rawValue

        // Cached TMDB metadata
        var name: String = ""
        var originalName: String = ""
        var overview: String = ""
        var posterPath: String?
        /// Release date (movies) or first-air date (shows), "yyyy-MM-dd".
        var releaseDate: String?
        var genres: [String] = []
        var originCountries: [String] = []
        var originalLanguage: String = ""
        var runtime: Int?
        var isAnime: Bool = false
        var showStatusRaw: String?
        /// JSON-encoded `EpisodeMetadata` (design D3). Empty for movies.
        var episodesData: Data = Data()
        /// Bumped whenever `episodesData` changes; keys the decode cache.
        var metadataRevision: Int = 0
        var lastRefreshedAt: Date?

        // List fields
        var statusRaw: String = ListStatus.planToWatch.rawValue
        var score: Int?
        var notes: String = ""
        var addedAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \WatchEvent.title)
        var events: [WatchEvent]? = []

        init(tmdbId: Int, kind: Kind, name: String = "", status: ListStatus = .planToWatch, addedAt: Date = .now) {
            self.tmdbId = tmdbId
            self.kindRaw = kind.rawValue
            self.name = name
            self.statusRaw = status.rawValue
            self.addedAt = addedAt
        }
    }

    /// One recorded watch of an episode (or of a movie, with no season/episode).
    @Model
    final class WatchEvent {
        /// Stable identity used by undo, independent of SwiftData's store ids.
        var uid: UUID = UUID()
        var watchedAt: Date = Date.now
        var season: Int?
        var episode: Int?
        var tmdbEpisodeId: Int?
        /// Shared by all events created by one bulk mark.
        var batchId: UUID?
        var title: Title?

        init(
            uid: UUID = UUID(),
            watchedAt: Date,
            season: Int? = nil,
            episode: Int? = nil,
            tmdbEpisodeId: Int? = nil,
            batchId: UUID? = nil
        ) {
            self.uid = uid
            self.watchedAt = watchedAt
            self.season = season
            self.episode = episode
            self.tmdbEpisodeId = tmdbEpisodeId
            self.batchId = batchId
        }
    }
}

nonisolated enum RyuujiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Title = SchemaV1.Title
typealias WatchEvent = SchemaV1.WatchEvent

nonisolated enum RyuujiStore {
    /// `storeURL` overrides the default on-disk location (debug launch flag only).
    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = if let storeURL, !inMemory {
            ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: RyuujiMigrationPlan.self, configurations: configuration)
    }
}
