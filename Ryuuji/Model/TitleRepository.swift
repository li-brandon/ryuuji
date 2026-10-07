import Foundation
import SwiftData

/// Lookups that enforce one `Title` per TMDB title in code, since CloudKit-compatible
/// schemas can't declare unique attributes.
nonisolated enum TitleRepository {
    static func find(tmdbId: Int, kind: Kind, in context: ModelContext) throws -> Title? {
        let kindRaw = kind.rawValue
        var descriptor = FetchDescriptor<Title>(
            predicate: #Predicate { $0.tmdbId == tmdbId && $0.kindRaw == kindRaw }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns the existing title, or inserts a new one configured by `configure`.
    @discardableResult
    static func insertIfAbsent(
        tmdbId: Int,
        kind: Kind,
        in context: ModelContext,
        configure: (Title) -> Void = { _ in }
    ) throws -> (title: Title, inserted: Bool) {
        if let existing = try find(tmdbId: tmdbId, kind: kind, in: context) {
            return (existing, false)
        }
        let title = Title(tmdbId: tmdbId, kind: kind)
        configure(title)
        context.insert(title)
        return (title, true)
    }

    static func event(uid: UUID, in context: ModelContext) throws -> WatchEvent? {
        var descriptor = FetchDescriptor<WatchEvent>(predicate: #Predicate { $0.uid == uid })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
