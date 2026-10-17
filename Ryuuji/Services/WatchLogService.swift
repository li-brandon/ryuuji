import Foundation
import Observation
import SwiftData
import os

/// Which episodes a bulk mark covers.
enum BulkScope: Hashable {
    /// Every aired, unwatched episode in one season (including season 0 if chosen explicitly).
    case season(Int)
    /// Every aired, unwatched regular episode; specials are skipped.
    case all
}

/// Owns every write that touches watch events or list status (design D6). Each public
/// operation updates status, saves, and registers exactly one undo step.
@Observable
final class WatchLogService {
    private let context: ModelContext
    private let today: () -> String
    private let now: () -> Date
    private let logger = Logger(subsystem: "moe.ryuuji.Ryuuji", category: "watch-log")

    init(
        context: ModelContext,
        today: @escaping () -> String = { AirDate.today() },
        now: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.today = today
        self.now = now
    }

    // MARK: Operations

    /// Logs one watch of `episode` (or of the movie when `episode` is nil). Logging an
    /// already-watched episode records a rewatch.
    func log(_ episode: EpisodeInfo?, of title: Title, undoManager: UndoManager?) {
        perform(episode == nil ? "Log Movie" : "Log Episode", on: title, trigger: .log, undoManager: undoManager) {
            let event = makeEvent(for: episode, of: title, at: now(), batchId: nil)
            return ([event], [])
        }
    }

    /// Logs every aired, unwatched episode in `scope` with one shared timestamp and batch id.
    func bulkMark(_ scope: BulkScope, of title: Title, undoManager: UndoManager?) {
        let targets = unwatchedAired(scope, of: title)
        guard !targets.isEmpty else { return }

        let name = if case .season = scope { "Mark Season Watched" } else { "Mark All Watched" }
        perform(name, on: title, trigger: .log, undoManager: undoManager) {
            let batchId = UUID()
            let timestamp = now()
            let events = targets.map { makeEvent(for: $0, of: title, at: timestamp, batchId: batchId) }
            return (events, [])
        }
    }

    /// Changes the list status by hand. Choosing Completed also fills in missing watches
    /// (see `complete`); either way it's one undo step that restores the previous status.
    func setStatus(_ status: ListStatus, of title: Title, undoManager: UndoManager?) {
        guard status != title.status else { return }
        if status == .completed {
            complete(title, undoManager: undoManager)
            return
        }
        perform("Change Status", on: title, trigger: nil, undoManager: undoManager) {
            title.status = status
            return ([], [])
        }
    }

    /// Sets `title` to Completed and logs what it's missing: every aired, unwatched regular
    /// episode as one batch, or one watch of a movie that has none. Existing events are kept.
    /// Status is then recomputed like any log, so a Returning show ends up Caught Up rather
    /// than Completed; a show with no aired episodes keeps Completed.
    func complete(_ title: Title, undoManager: UndoManager?) {
        let progress = title.progress(today: today())
        let targets: [EpisodeInfo?] = switch title.kind {
        case .movie: progress.eventCount == 0 ? [nil] : []
        case .show: unwatchedAired(.all, of: title).map { Optional($0) }
        }
        let trigger: StatusTrigger? = title.kind == .show && !progress.hasAiredRegular ? nil : .log

        perform("Mark Completed", on: title, trigger: trigger, undoManager: undoManager) {
            title.status = .completed
            let batchId = title.kind == .show ? UUID() : nil
            let timestamp = now()
            let events = targets.map { makeEvent(for: $0, of: title, at: timestamp, batchId: batchId) }
            return (events, [])
        }
    }

    /// Removes every event for `episode` (or every movie event when `episode` is nil).
    func unmark(_ episode: EpisodeInfo?, of title: Title, undoManager: UndoManager?) {
        let doomed: [WatchEvent]
        if let episode {
            let matcher = EpisodeMatcher(episodes: title.allEpisodes)
            doomed = title.eventList.filter { matcher.match($0.ref)?.tmdbId == episode.tmdbId }
        } else {
            doomed = title.eventList
        }
        guard !doomed.isEmpty else { return }

        perform("Unmark", on: title, trigger: .unmark, undoManager: undoManager) {
            let snapshots = doomed.map(EventSnapshot.init)
            doomed.forEach(context.delete)
            return ([], snapshots)
        }
    }

    /// Deletes a single event, e.g. from History.
    func deleteEvent(_ event: WatchEvent, undoManager: UndoManager?) {
        guard let title = event.title else {
            context.delete(event)
            save()
            return
        }
        perform("Delete Watch", on: title, trigger: .unmark, undoManager: undoManager) {
            let snapshot = EventSnapshot(event)
            context.delete(event)
            return ([], [snapshot])
        }
    }

    // MARK: Core

    private func perform(
        _ actionName: String,
        on title: Title,
        trigger: StatusTrigger?,
        undoManager: UndoManager?,
        mutate: () -> (added: [WatchEvent], removed: [EventSnapshot])
    ) {
        let previousStatus = title.status
        let (added, removed) = mutate()
        if let trigger {
            applyStatus(trigger, to: title)
        }
        save()

        guard let undoManager else { return }
        let undo = UndoRecord(
            titleKey: TitleKey(title),
            previousStatus: previousStatus,
            addedEventIds: added.map(\.uid),
            removedEvents: removed
        )
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { service in
            MainActor.assumeIsolated { service.revert(undo) }
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
    }

    private func revert(_ record: UndoRecord) {
        guard let title = try? TitleRepository.find(tmdbId: record.titleKey.tmdbId, kind: record.titleKey.kind, in: context) else {
            logger.error("Undo skipped: title no longer exists")
            return
        }
        for uid in record.addedEventIds {
            if let event = try? TitleRepository.event(uid: uid, in: context) {
                context.delete(event)
            }
        }
        for snapshot in record.removedEvents {
            let event = snapshot.makeEvent()
            context.insert(event)
            event.title = title
        }
        title.status = record.previousStatus
        save()
    }

    /// Aired episodes in `scope` with no events, in season/episode order.
    private func unwatchedAired(_ scope: BulkScope, of title: Title) -> [EpisodeInfo] {
        let progress = title.progress(today: today())
        return title.allEpisodes
            .filter { episode in
                switch scope {
                case .season(let number): episode.season == number
                case .all: !episode.isSpecial
                }
            }
            .filter { $0.isAired(today: today()) && !progress.isWatched($0) }
            .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
    }

    private func makeEvent(for episode: EpisodeInfo?, of title: Title, at date: Date, batchId: UUID?) -> WatchEvent {
        let event = WatchEvent(
            watchedAt: date,
            season: episode?.season,
            episode: episode?.number,
            tmdbEpisodeId: episode?.tmdbId,
            batchId: batchId
        )
        context.insert(event)
        event.title = title
        return event
    }

    private func applyStatus(_ trigger: StatusTrigger, to title: Title) {
        // Deleted events can linger in the relationship until save; exclude them.
        let refs = title.eventList.filter { !$0.isDeleted }.map(\.ref)
        let progress = Progress.compute(episodes: title.allEpisodes, events: refs, today: today())
        title.status = StatusEngine.status(
            after: trigger,
            current: title.status,
            kind: title.kind,
            progress: progress,
            showStatus: title.showStatus
        )
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// The values needed to recreate a deleted event on undo.
struct EventSnapshot: Sendable {
    var uid: UUID
    var watchedAt: Date
    var season: Int?
    var episode: Int?
    var tmdbEpisodeId: Int?
    var batchId: UUID?

    init(_ event: WatchEvent) {
        uid = event.uid
        watchedAt = event.watchedAt
        season = event.season
        episode = event.episode
        tmdbEpisodeId = event.tmdbEpisodeId
        batchId = event.batchId
    }

    func makeEvent() -> WatchEvent {
        WatchEvent(uid: uid, watchedAt: watchedAt, season: season, episode: episode, tmdbEpisodeId: tmdbEpisodeId, batchId: batchId)
    }
}

private struct UndoRecord: Sendable {
    var titleKey: TitleKey
    var previousStatus: ListStatus
    var addedEventIds: [UUID]
    var removedEvents: [EventSnapshot]
}
