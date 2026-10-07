import SwiftData
import SwiftUI

@main
struct RyuujiApp: App {
    @State private var services: AppServices
    @State private var appState: AppState

    init() {
        AppConfig.logTokenPresence()

        // Keep posters available offline after first load (design D10).
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)

        let container: ModelContainer
        do {
            container = try RyuujiStore.makeContainer(inMemory: DebugLaunch.inMemoryStore, storeURL: DebugLaunch.storeURL)
        } catch {
            fatalError("Could not open the Ryuuji store: \(error)")
        }
        DebugLaunch.seedIfRequested(container.mainContext)
        let appState = AppState()
        DebugLaunch.configure(appState)
        _appState = State(initialValue: appState)
        _services = State(initialValue: AppServices(container: container, client: LiveTMDBClient(token: AppConfig.tmdbToken)))
    }

    var body: some Scene {
        Window("Ryuuji", id: "main") {
            ContentView()
                .environment(appState)
                .environment(services)
                .environment(services.watchLog)
                .task { await services.scheduler.run() }
        }
        .modelContainer(services.container)
        .defaultSize(width: 1100, height: 720)
        .commands {
            RyuujiCommands(appState: appState)
        }

        Window("About Ryuuji", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            AboutView()
        }
    }
}

struct RyuujiCommands: Commands {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Ryuuji") { openWindow(id: "about") }
        }
        CommandGroup(replacing: .newItem) {
            Button("Add Title…") { appState.isQuickAddPresented = true }
                .keyboardShortcut("k")
        }
        CommandMenu("Go") {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                Button(item.label) { appState.sidebar = item }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
            }
        }
    }
}
