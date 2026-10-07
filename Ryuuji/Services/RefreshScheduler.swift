import AppKit
import Foundation
import os

/// Runs `MetadataRefresher.refreshDue` on launch, every 24 hours, and on wake when stale
/// (design D8).
@MainActor
final class RefreshScheduler {
    static let interval: TimeInterval = 24 * 60 * 60
    private static let lastRunKey = "lastMetadataRefresh"

    private let refresher: MetadataRefresher
    private let client: any TMDBClient
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "moe.ryuuji.Ryuuji", category: "refresh")
    private var isRunning = false
    private var wakeObserver: NSObjectProtocol?

    init(refresher: MetadataRefresher, client: any TMDBClient, defaults: UserDefaults = .standard) {
        self.refresher = refresher
        self.client = client
        self.defaults = defaults
    }

    private var lastRun: Date? {
        get { defaults.object(forKey: Self.lastRunKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastRunKey) }
    }

    /// Call once from the main window's `.task`. Refreshes now, then checks hourly; the
    /// continuous clock keeps counting through sleep, so a missed day is caught on wake too.
    func run() async {
        observeWake()
        await refreshNow(reason: "launch")
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60 * 60))
            await refreshIfStale(reason: "timer")
        }
    }

    private func observeWake() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refreshIfStale(reason: "wake") }
            }
        }
    }

    func refreshIfStale(reason: String) async {
        if let lastRun, Date.now.timeIntervalSince(lastRun) < Self.interval { return }
        await refreshNow(reason: reason)
    }

    func refreshNow(reason: String) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        logger.info("Metadata refresh starting (\(reason, privacy: .public))")
        _ = await refresher.refreshDue(client: client)
        lastRun = .now
    }
}
