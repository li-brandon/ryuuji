import SwiftData
import SwiftUI

/// One Up Next item: a Watching show and its next episode. Shared by `UpNextView` and the
/// menu bar extra so both lists use the same selection and order.
struct UpNextEntry: Identifiable {
    let title: Title
    let next: EpisodeInfo
    let remaining: Int
    var id: PersistentIdentifier { title.persistentModelID }

    /// The `@Query` filter for Up Next candidates; narrow the results with `entries(from:)`.
    static var candidates: Predicate<Title> {
        #Predicate<Title> { $0.statusRaw == "watching" && $0.kindRaw == "show" }
    }

    /// Candidates that have a next episode, most recently active first.
    static func entries(from titles: [Title]) -> [UpNextEntry] {
        let today = AirDate.today()
        return titles
            .compactMap { title -> UpNextEntry? in
                let progress = title.progress(today: today)
                guard let next = progress.next else { return nil }
                return UpNextEntry(title: title, next: next, remaining: progress.remaining)
            }
            .sorted { $0.title.lastActivity > $1.title.lastActivity }
    }
}

/// Home view: Watching shows with a next episode, plus one-click logging (up-next spec).
struct UpNextView: View {
    @Query(filter: UpNextEntry.candidates)
    private var watching: [Title]

    private var entries: [UpNextEntry] { UpNextEntry.entries(from: watching) }

    var body: some View {
        let entries = entries
        Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("Nothing Up Next", systemImage: "play.square.stack")
                } description: {
                    Text("Press ⌘K to add a show, then log an episode to start watching it.")
                }
            } else {
                List(entries) { entry in
                    NavigationLink(value: TitleRoute(key: TitleKey(entry.title))) {
                        UpNextRow(title: entry.title, next: entry.next, remaining: entry.remaining)
                    }
                }
                .animation(.default, value: entries.map(\.id))
            }
        }
        .navigationTitle("Up Next")
    }
}

private struct UpNextRow: View {
    let title: Title
    let next: EpisodeInfo
    let remaining: Int

    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        HStack(spacing: 14) {
            PosterView(path: title.posterPath, width: 46)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title.name)
                        .font(.headline)
                        .lineLimit(1)
                    if title.isAnime { TagView(text: "Anime", tint: .pink) }
                }
                Text(next.displayName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(remaining) left")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                withAnimation {
                    watchLog.log(next, of: title, undoManager: undoManager)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help("Log \(next.code)")
            .accessibilityLabel("Log \(next.code) of \(title.name)")
        }
        .padding(.vertical, 4)
    }
}
