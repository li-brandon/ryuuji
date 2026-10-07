import Foundation
import Observation
import SwiftData

enum SidebarItem: Hashable, CaseIterable {
    case upNext
    case library
    case history

    var label: String {
        switch self {
        case .upNext: "Up Next"
        case .library: "Library"
        case .history: "History"
        }
    }

    var systemImage: String {
        switch self {
        case .upNext: "play.square.stack"
        case .library: "books.vertical"
        case .history: "clock.arrow.circlepath"
        }
    }
}

/// Navigation value for a title's detail view.
struct TitleRoute: Hashable {
    var key: TitleKey
}

/// Window-level UI state.
@Observable
final class AppState {
    var sidebar: SidebarItem? = .upNext {
        didSet { if oldValue != sidebar { path = [] } }
    }
    var path: [TitleRoute] = []
    var isQuickAddPresented = false
    /// Text to pre-fill the next time quick add opens (debug launch flag only).
    var quickAddSeedQuery: String?

    func open(_ title: Title) {
        path = [TitleRoute(key: TitleKey(title))]
    }
}

/// Long-lived services shared by every view.
@Observable
final class AppServices {
    let container: ModelContainer
    let client: any TMDBClient
    let watchLog: WatchLogService
    let adder: TitleAdder
    let refresher: MetadataRefresher
    let scheduler: RefreshScheduler

    init(container: ModelContainer, client: any TMDBClient) {
        self.container = container
        self.client = client
        let watchLog = WatchLogService(context: container.mainContext)
        self.watchLog = watchLog
        self.adder = TitleAdder(context: container.mainContext, client: client, watchLog: watchLog)
        let refresher = MetadataRefresher(modelContainer: container)
        self.refresher = refresher
        self.scheduler = RefreshScheduler(refresher: refresher, client: client)
    }

    /// Refreshes one title on demand from its detail view.
    func refresh(_ key: TitleKey) async -> RefreshReport {
        await refresher.refresh([key], client: client)
    }
}
