import SwiftData
import SwiftUI

/// Menu bar extra: the Up Next list with one-click logging and a way back to the main window.
struct MenuBarExtraContent: View {
    @Query(filter: UpNextEntry.candidates)
    private var watching: [Title]

    @Environment(\.openWindow) private var openWindow

    private var entries: [UpNextEntry] { UpNextEntry.entries(from: watching) }

    var body: some View {
        let entries = entries
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries) { entry in
                    MenuBarRow(entry: entry)
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }

            Divider()

            Button("Open Ryuuji") {
                openWindow(id: "main")
                NSApp.activate()
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 320)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.square.stack")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Nothing Up Next")
                .font(.headline)
            Text("Add a show and log an episode to start watching.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct MenuBarRow: View {
    let entry: UpNextEntry

    @Environment(AppState.self) private var appState
    @Environment(WatchLogService.self) private var watchLog

    var body: some View {
        HStack(spacing: 10) {
            PosterView(path: entry.title.posterPath, width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(entry.next.code)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    // Register on the main window's undo stack so ⌘Z there reverts it.
                    watchLog.log(entry.next, of: entry.title, undoManager: appState.mainUndoManager)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help("Log \(entry.next.code)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
