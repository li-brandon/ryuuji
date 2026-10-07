import SwiftData
import SwiftUI

/// Every watch event, newest first, grouped by day (watch-history spec).
struct HistoryView: View {
    @Query(sort: \WatchEvent.watchedAt, order: .reverse) private var events: [WatchEvent]

    var body: some View {
        let model = HistoryModel(events: events)
        Group {
            if events.isEmpty {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Episodes and movies you log will appear here.")
                }
            } else {
                List {
                    ForEach(model.days) { day in
                        Section(day.heading) {
                            ForEach(day.items) { item in
                                switch item {
                                case .single(let event):
                                    HistoryEventRow(event: event, model: model)
                                case .batch(_, let batch):
                                    HistoryBatchRow(events: batch, model: model)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

/// Precomputed grouping, rewatch flags, and episode names for one render.
struct HistoryModel {
    struct Day: Identifiable {
        let start: Date
        let items: [Item]
        var id: Date { start }

        var heading: String {
            let calendar = Calendar.current
            if calendar.isDateInToday(start) { return "Today" }
            if calendar.isDateInYesterday(start) { return "Yesterday" }
            return start.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }
    }

    enum Item: Identifiable {
        case single(WatchEvent)
        case batch(UUID, [WatchEvent])

        var id: String {
            switch self {
            case .single(let event): event.uid.uuidString
            case .batch(let id, _): "batch-" + id.uuidString
            }
        }
    }

    let days: [Day]
    private let rewatches: Set<UUID>

    init(events: [WatchEvent]) {
        let calendar = Calendar.current

        // Events arrive newest first; group by local day, collapsing bulk batches.
        var days: [Day] = []
        var currentStart: Date?
        var items: [Item] = []
        var batchIndex: [UUID: Int] = [:]
        func flush() {
            if let currentStart { days.append(Day(start: currentStart, items: items)) }
            items = []
            batchIndex = [:]
        }
        for event in events {
            let start = calendar.startOfDay(for: event.watchedAt)
            if start != currentStart {
                flush()
                currentStart = start
            }
            if let batchId = event.batchId {
                if let index = batchIndex[batchId], case .batch(let id, let existing) = items[index] {
                    items[index] = .batch(id, existing + [event])
                } else {
                    batchIndex[batchId] = items.count
                    items.append(.batch(batchId, [event]))
                }
            } else {
                items.append(.single(event))
            }
        }
        flush()
        self.days = days

        // A rewatch is any event that isn't the earliest for its episode (or movie).
        struct Key: Hashable {
            var title: PersistentIdentifier?
            var episode: String
        }
        var earliest: [Key: WatchEvent] = [:]
        for event in events {
            let episode = event.tmdbEpisodeId.map(String.init) ?? "\(event.season ?? -1)x\(event.episode ?? -1)"
            let key = Key(title: event.title?.persistentModelID, episode: episode)
            if let current = earliest[key], current.watchedAt <= event.watchedAt { continue }
            earliest[key] = event
        }
        let firsts = Set(earliest.values.map(\.uid))
        self.rewatches = Set(events.map(\.uid)).subtracting(firsts)
    }

    func isRewatch(_ event: WatchEvent) -> Bool {
        rewatches.contains(event.uid)
    }

    /// "S1E3 · Name", "S1E3" when the episode is no longer in TMDB, or "Movie".
    func episodeLabel(_ event: WatchEvent) -> String {
        if event.isMovieEvent { return "Movie" }
        if let title = event.title,
           let episode = EpisodeMatcher(episodes: title.allEpisodes).match(event.ref) {
            return episode.displayName
        }
        return "S\(event.season ?? 0)E\(event.episode ?? 0)"
    }

    /// "Season 1 · 12 episodes" for a batch.
    static func batchLabel(_ events: [WatchEvent]) -> String {
        let seasons = Set(events.compactMap(\.season))
        let count = "\(events.count) episode\(events.count == 1 ? "" : "s")"
        if seasons.count == 1, let season = seasons.first {
            return season == 0 ? "Specials · \(count)" : "Season \(season) · \(count)"
        }
        return count
    }
}

private struct HistoryEventRow: View {
    let event: WatchEvent
    let model: HistoryModel
    var showsTitle = true

    @Environment(WatchLogService.self) private var watchLog
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationLink(value: event.title.map { TitleRoute(key: TitleKey($0)) }) {
            HStack(spacing: 10) {
                if showsTitle {
                    PosterView(path: event.title?.posterPath, width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if showsTitle {
                        Text(event.title?.name ?? "Removed title")
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text(model.episodeLabel(event))
                        .foregroundStyle(showsTitle ? .secondary : .primary)
                        .lineLimit(1)
                }
                Spacer()
                if model.isRewatch(event) {
                    TagView(text: "Rewatch", tint: .purple)
                }
                Text(event.watchedAt, format: .dateTime.hour().minute())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                withAnimation { watchLog.deleteEvent(event, undoManager: undoManager) }
            }
        }
    }
}

private struct HistoryBatchRow: View {
    let events: [WatchEvent]
    let model: HistoryModel
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(events.sorted { ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0) }) { event in
                HistoryEventRow(event: event, model: model, showsTitle: false)
            }
        } label: {
            NavigationLink(value: events.first?.title.map { TitleRoute(key: TitleKey($0)) }) {
                HStack(spacing: 10) {
                    PosterView(path: events.first?.title?.posterPath, width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(events.first?.title?.name ?? "Removed title")
                            .font(.headline)
                            .lineLimit(1)
                        Text(HistoryModel.batchLabel(events))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TagView(text: "Bulk", tint: .blue)
                    if let first = events.first {
                        Text(first.watchedAt, format: .dateTime.hour().minute())
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
