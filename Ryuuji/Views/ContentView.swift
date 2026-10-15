import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $appState.sidebar) { item in
                Label(item.label, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
        } detail: {
            NavigationStack(path: $appState.path) {
                root
                    .navigationDestination(for: TitleRoute.self) { route in
                        TitleDetailView(key: route.key)
                    }
            }
        }
        .overlay {
            if appState.isQuickAddPresented {
                QuickAddPanel()
            }
        }
        .animation(.easeOut(duration: 0.12), value: appState.isQuickAddPresented)
        .onChange(of: undoManager, initial: true) { appState.mainUndoManager = undoManager }
    }

    @ViewBuilder
    private var root: some View {
        switch appState.sidebar ?? .upNext {
        case .upNext: UpNextView()
        case .library: LibraryView()
        case .history: HistoryView()
        }
    }
}
