import SwiftData
import SwiftUI

/// One title's metadata, list fields, and episode checklist (title-detail spec).
struct TitleDetailView: View {
    let key: TitleKey
    @Query private var matches: [Title]

    init(key: TitleKey) {
        self.key = key
        let tmdbId = key.tmdbId
        let kindRaw = key.kind.rawValue
        _matches = Query(filter: #Predicate<Title> { $0.tmdbId == tmdbId && $0.kindRaw == kindRaw })
    }

    var body: some View {
        if let title = matches.first {
            TitleDetailContent(title: title)
        } else {
            ContentUnavailableView("Title Removed", systemImage: "trash", description: Text("This title is no longer in your library."))
        }
    }
}

private struct TitleDetailContent: View {
    @Bindable var title: Title
    @Environment(AppServices.self) private var services
    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager
    @State private var isRefreshing = false
    @State private var refreshFailed = false

    var body: some View {
        let today = AirDate.today()
        let progress = title.progress(today: today)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(progress: progress)
                notes
                if title.kind == .show {
                    seasonList(progress: progress, today: today)
                } else {
                    movieActions(progress: progress)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .navigationTitle(title.name)
        .toolbar {
            if title.kind == .show {
                ToolbarItem {
                    Button("Mark All Watched", systemImage: "checkmark.circle") {
                        withAnimation { watchLog.bulkMark(.all, of: title, undoManager: undoManager) }
                    }
                    .disabled(progress.remaining == 0)
                    .help("Log every aired, unwatched episode (specials excluded)")
                }
            }
            ToolbarItem {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                        .help(refreshFailed ? "The last refresh failed. Try again." : "Re-fetch metadata from TMDB")
                }
            }
        }
    }

    // MARK: Header

    private func header(progress: Progress) -> some View {
        HStack(alignment: .top, spacing: 20) {
            PosterView(path: title.posterPath, size: .detail, width: 170)
            VStack(alignment: .leading, spacing: 10) {
                Text(title.name)
                    .font(.largeTitle.bold())
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    KindTags(kind: title.kind, isAnime: title.isAnime)
                    Text(title.subtitle).foregroundStyle(.secondary)
                }
                if title.kind == .show {
                    Text("\(progress.watchedAiredRegularCount)/\(progress.airedRegular.count) episodes watched")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    StatusPicker(title: title)
                        .fixedSize()
                    ScorePicker(title: title)
                        .fixedSize()
                }
                .padding(.vertical, 4)
                if !title.overview.isEmpty {
                    Text(title.overview)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if refreshFailed {
                    Label("Couldn't refresh from TMDB. Showing cached data.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.headline)
            TextEditor(text: $title.notes)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Shows

    private func seasonList(progress: Progress, today: String) -> some View {
        // Regular seasons first, specials last.
        let seasons = title.seasons.filter { !$0.isSpecials } + title.seasons.filter(\.isSpecials)
        return VStack(alignment: .leading, spacing: 16) {
            if seasons.isEmpty {
                Text("No episode data yet. Use Refresh to fetch it from TMDB.")
                    .foregroundStyle(.secondary)
            }
            ForEach(seasons) { season in
                SeasonSection(title: title, season: season, progress: progress, today: today)
            }
        }
    }

    // MARK: Movies

    private func movieActions(progress: Progress) -> some View {
        HStack(spacing: 12) {
            if progress.eventCount == 0 {
                Button("Mark Watched", systemImage: "checkmark.circle") {
                    watchLog.log(nil, of: title, undoManager: undoManager)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else {
                Label(
                    progress.eventCount == 1 ? "Watched once" : "Watched \(progress.eventCount) times",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.green)
                Button("Log Again", systemImage: "arrow.counterclockwise") {
                    watchLog.log(nil, of: title, undoManager: undoManager)
                }
                Button("Unmark", systemImage: "xmark.circle", role: .destructive) {
                    watchLog.unmark(nil, of: title, undoManager: undoManager)
                }
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        refreshFailed = false
        let key = TitleKey(title)
        Task {
            let report = await services.refresh(key)
            refreshFailed = report.failed > 0
            isRefreshing = false
        }
    }
}

private struct SeasonSection: View {
    let title: Title
    let season: SeasonInfo
    let progress: Progress
    let today: String

    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager
    @State private var isExpanded = true

    var body: some View {
        let aired = season.episodes.filter { $0.isAired(today: today) }
        let watched = aired.filter(progress.isWatched).count

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    Label(season.name, systemImage: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.title3.bold())
                }
                .buttonStyle(.plain)
                Text("\(watched)/\(aired.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Mark Season Watched") {
                    withAnimation { watchLog.bulkMark(.season(season.number), of: title, undoManager: undoManager) }
                }
                .disabled(watched == aired.count)
            }
            .padding(.bottom, 8)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(season.episodes.sorted { $0.number < $1.number }) { episode in
                        EpisodeRow(title: title, episode: episode, progress: progress, today: today)
                        if episode.id != season.episodes.last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct EpisodeRow: View {
    let title: Title
    let episode: EpisodeInfo
    let progress: Progress
    let today: String

    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let isAired = episode.isAired(today: today)
        let count = progress.watchCount(of: episode)
        let isWatched = count > 0

        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { isWatched },
                set: { checked in
                    if checked {
                        watchLog.log(episode, of: title, undoManager: undoManager)
                    } else {
                        watchLog.unmark(episode, of: title, undoManager: undoManager)
                    }
                }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(!isAired && !isWatched)
            .accessibilityLabel("Watched \(episode.code)")

            Text("\(episode.number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            Text(episode.name)
                .lineLimit(1)
                .foregroundStyle(isAired ? .primary : .secondary)
            if count > 1 {
                TagView(text: "×\(count)", tint: .purple)
                    .help("Rewatched \(count - 1) time\(count == 2 ? "" : "s")")
            }
            Spacer()
            Text(airDateText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(isAired ? .secondary : .tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if isWatched {
                Button("Log Again") { watchLog.log(episode, of: title, undoManager: undoManager) }
                Button("Unmark", role: .destructive) { watchLog.unmark(episode, of: title, undoManager: undoManager) }
            } else if isAired {
                Button("Mark Watched") { watchLog.log(episode, of: title, undoManager: undoManager) }
            }
        }
    }

    private var airDateText: String {
        guard let date = AirDate.date(from: episode.airDate) else { return "TBA" }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
