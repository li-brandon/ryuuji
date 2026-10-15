import SwiftData
import SwiftUI

struct MenuBarExtraContent: View {
    @Query(filter: #Predicate<Title> { $0.statusRaw == "watching" && $0.kindRaw == "show" })
    private var watching: [Title]
    
    @Environment(AppServices.self) private var services
    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow
    
    private struct Entry: Identifiable {
        let title: Title
        let next: EpisodeInfo
        var id: PersistentIdentifier { title.persistentModelID }
    }
    
    private var entries: [Entry] {
        let today = AirDate.today()
        return watching
            .compactMap { title -> Entry? in
                let progress = title.progress(today: today)
                guard let next = progress.next else { return nil }
                return Entry(title: title, next: next)
            }
            .sorted { $0.title.lastActivity > $1.title.lastActivity }
    }
    
    var body: some View {
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
                NSApp.activate(ignoringOtherApps: true)
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
    let entry: MenuBarExtraContent.Entry
    
    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager
    
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
                    watchLog.log(entry.next, of: entry.title, undoManager: undoManager)
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
