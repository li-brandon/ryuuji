import Foundation
import SwiftData
import os

nonisolated struct RefreshReport: Sendable, Equatable {
    var refreshed = 0
    var failed = 0
}

/// Re-fetches TMDB metadata off the main actor and applies refresh status rules (design D8).
@ModelActor
actor MetadataRefresher {
    nonisolated static let maxConcurrentRequests = 4
    nonisolated static let staleInterval: TimeInterval = 7 * 24 * 60 * 60

    private static let logger = Logger(subsystem: "moe.ryuuji.Ryuuji", category: "refresh")

    /// Refreshes every title due under the title-metadata spec: shows that aren't Ended or
    /// Canceled, plus shows not refreshed in 7 days (or never, or with unreadable cache).
    func refreshDue(client: any TMDBClient, now: Date = .now, today: String = AirDate.today()) async -> RefreshReport {
        let titles = (try? modelContext.fetch(FetchDescriptor<Title>())) ?? []
        let due = titles.filter { Self.isDue($0, now: now) }.map(TitleKey.init)
        return await refresh(due, client: client, now: now, today: today)
    }

    /// Refreshes specific titles, e.g. from the detail view's Refresh action.
    func refresh(_ keys: [TitleKey], client: any TMDBClient, now: Date = .now, today: String = AirDate.today()) async -> RefreshReport {
        guard !keys.isEmpty else { return RefreshReport() }
        let results = await Self.fetchAll(keys, client: client)

        var report = RefreshReport()
        for (key, result) in results {
            switch result {
            case .success(let metadata):
                guard let title = try? TitleRepository.find(tmdbId: key.tmdbId, kind: key.kind, in: modelContext) else { continue }
                TitleMapper.apply(metadata, to: title)
                title.lastRefreshedAt = now
                title.status = StatusEngine.status(
                    after: .refresh,
                    current: title.status,
                    kind: title.kind,
                    progress: title.progress(today: today),
                    showStatus: title.showStatus
                )
                report.refreshed += 1
            case .failure(let error):
                Self.logger.error("Refresh failed for \(key.kind.rawValue, privacy: .public) \(key.tmdbId): \(error.localizedDescription, privacy: .public)")
                report.failed += 1
            }
        }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Refresh save failed: \(error.localizedDescription, privacy: .public)")
        }
        Self.logger.info("Refresh finished: \(report.refreshed) refreshed, \(report.failed) failed")
        return report
    }

    nonisolated static func isDue(_ title: Title, now: Date) -> Bool {
        guard title.kind == .show else { return false }
        if !title.showStatus.isFinished || title.needsEpisodeRefresh { return true }
        guard let last = title.lastRefreshedAt else { return true }
        return now.timeIntervalSince(last) >= staleInterval
    }

    /// Fetches with at most `maxConcurrentRequests` requests in flight.
    private nonisolated static func fetchAll(
        _ keys: [TitleKey],
        client: any TMDBClient
    ) async -> [(TitleKey, Result<FetchedMetadata, Error>)] {
        await withTaskGroup(of: (TitleKey, Result<FetchedMetadata, Error>).self) { group in
            var pending = keys[...]
            var results: [(TitleKey, Result<FetchedMetadata, Error>)] = []

            func startNext() {
                guard let key = pending.popFirst() else { return }
                group.addTask {
                    do {
                        return (key, .success(try await client.metadata(for: key)))
                    } catch {
                        return (key, .failure(error))
                    }
                }
            }

            for _ in 0..<maxConcurrentRequests { startNext() }
            for await result in group {
                results.append(result)
                startNext()
            }
            return results
        }
    }
}
