import SwiftData
import SwiftUI

/// Menu bar extra: the Up Next list with one-click logging and a way back to the main window.
struct MenuBarExtraContent: View {
    @Query(filter: UpNextEntry.candidates)
    private var watching: [Title]

    @Environment(AppState.self) private var appState
    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.openWindow) private var openWindow

    /// The stack the most recent menu bar log registered on, for the Undo button.
    @State private var undoTarget: UndoManager?
    /// Bumped on undo stack changes; UndoManager isn't observable.
    @State private var undoRevision = 0

    private var entries: [UpNextEntry] { UpNextEntry.entries(from: watching) }

    var body: some View {
        let entries = entries
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                // Long lists scroll so the footer stays reachable.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            MenuBarRow(entry: entry) { log(entry) }
                            if entry.id != entries.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            if let undoTarget, undoRevision >= 0, undoTarget.canUndo {
                Button(undoTarget.undoMenuItemTitle) {
                    withAnimation { undoTarget.undo() }
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { _ in undoRevision += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in undoRevision += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in undoRevision += 1 }
    }

    private func log(_ entry: UpNextEntry) {
        // The main window's stack when open, so ⌘Z there reverts it; otherwise an app-owned
        // stack, so the Undo button here still can.
        let undoManager = appState.menuBarLogUndoManager
        withAnimation {
            watchLog.log(entry.next, of: entry.title, undoManager: undoManager)
        }
        undoTarget = undoManager
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
    let onLog: () -> Void

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

            Button(action: onLog) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help("Log \(entry.next.code) of \(entry.title.name)")
            .accessibilityLabel("Log \(entry.next.code) of \(entry.title.name)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
