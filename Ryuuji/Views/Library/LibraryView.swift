import SwiftData
import SwiftUI

enum KindFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case shows = "Shows"
    case movies = "Movies"
    case anime = "Anime"

    var id: String { rawValue }

    func matches(_ title: Title) -> Bool {
        switch self {
        case .all: true
        case .shows: title.kind == .show
        case .movies: title.kind == .movie
        case .anime: title.isAnime
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case name = "Name"
    case added = "Date Added"
    case activity = "Recent Activity"

    var id: String { rawValue }
}

/// All tracked titles, filtered by status and kind (library spec).
struct LibraryView: View {
    @Query private var titles: [Title]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager

    @SceneStorage("library.status") private var statusRaw = ""
    @SceneStorage("library.kind") private var kindFilter: KindFilter = .all
    @SceneStorage("library.sort") private var sort: LibrarySort = .activity
    @State private var pendingRemoval: Title?

    private var statusFilter: ListStatus? {
        ListStatus(rawValue: statusRaw)
    }

    private var kindMatched: [Title] {
        titles.filter(kindFilter.matches)
    }

    private var visible: [Title] {
        let filtered = kindMatched.filter { statusFilter == nil || $0.status == statusFilter }
        switch sort {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .added:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .activity:
            return filtered.sorted { $0.lastActivity > $1.lastActivity }
        }
    }

    var body: some View {
        let today = AirDate.today()
        Group {
            if visible.isEmpty {
                VStack(spacing: 0) {
                    statusBar
                    Divider()
                    ContentUnavailableView {
                        Label(titles.isEmpty ? "Your Library Is Empty" : "No Matching Titles", systemImage: "books.vertical")
                    } description: {
                        Text(titles.isEmpty ? "Press ⌘K to search TMDB and add titles." : "Try a different status or kind filter.")
                    }
                }
            } else {
                List {
                    Section {
                        ForEach(visible) { title in
                            NavigationLink(value: TitleRoute(key: TitleKey(title))) {
                                LibraryRow(title: title, today: today)
                            }
                            .contextMenu { contextMenu(for: title) }
                        }
                    } header: {
                        // Pinned section header keeps the filter bar above the rows (LIB-297).
                        VStack(spacing: 0) {
                            statusBar
                            Divider()
                        }
                        .textCase(nil)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Library")
        .toolbar { kindAndSortPickers }
        .confirmationDialog(
            "Remove “\(pendingRemoval?.name ?? "")”?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { title in
            Button("Remove", role: .destructive) { remove(title) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This also deletes its watch history. It can't be undone.")
        }
    }

    private var statusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                StatusChip(label: "All", count: kindMatched.count, isSelected: statusFilter == nil) {
                    statusRaw = ""
                }
                ForEach(ListStatus.allCases) { status in
                    StatusChip(
                        label: status.label,
                        count: kindMatched.filter { $0.status == status }.count,
                        isSelected: statusFilter == status
                    ) {
                        statusRaw = status.rawValue
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ToolbarContentBuilder
    private var kindAndSortPickers: some ToolbarContent {
        ToolbarItem {
            Picker("Kind", selection: $kindFilter) {
                ForEach(KindFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        ToolbarItem {
            Picker("Sort", selection: $sort) {
                ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .help("Sort titles")
        }
    }

    @ViewBuilder
    private func contextMenu(for title: Title) -> some View {
        StatusPicker(title: title)
        ScorePicker(title: title)
        Divider()
        Button("Remove from Library…", role: .destructive) { pendingRemoval = title }
    }

    private func remove(_ title: Title) {
        modelContext.delete(title)
        try? modelContext.save()
        // Undo steps for this title's events can no longer apply.
        undoManager?.removeAllActions(withTarget: watchLog)
        appState.menuBarUndoManager.removeAllActions(withTarget: watchLog)
        pendingRemoval = nil
    }
}

private struct StatusChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                Text("\(count)")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count) titles")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LibraryRow: View {
    let title: Title
    let today: String

    var body: some View {
        HStack(spacing: 12) {
            PosterView(path: title.posterPath, width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let year = title.year {
                        Text(year).font(.caption).foregroundStyle(.secondary)
                    }
                    KindTags(kind: title.kind, isAnime: title.isAnime)
                    Text(title.status.label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let score = title.score {
                Label("\(score)", systemImage: "star.fill")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.yellow)
                    .labelStyle(.titleAndIcon)
            }
            if title.kind == .show {
                let progress = title.progress(today: today)
                Text("\(progress.watchedAiredRegularCount)/\(progress.airedRegular.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}
