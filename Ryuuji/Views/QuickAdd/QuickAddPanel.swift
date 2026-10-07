import AppKit
import SwiftData
import SwiftUI
import os // TEMP

/// The Cmd-K search-and-add overlay (title-search spec).
struct QuickAddPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Query private var titles: [Title]

    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var selection: SearchItem.ID?
    @State private var phase: Phase = .idle
    @State private var adding: Set<SearchItem.ID> = []
    @State private var addError: String?
    @FocusState private var fieldFocused: Bool
    @State private var escapeMonitor: Any?

    enum Phase: Equatable {
        case idle
        case searching
        case done
        case failed(String)
    }

    /// Status of every title already in the list, by TMDB key.
    private var inList: [TitleKey: ListStatus] {
        Dictionary(titles.map { (TitleKey($0), $0.status) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                searchField
                Divider()
                content
                    .frame(maxHeight: 420)
                footer
            }
            .frame(width: 600)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(.top, 80)
            .background(statusShortcuts)
        }
        .transition(.opacity)
        .onAppear {
            if let seed = appState.quickAddSeedQuery {
                query = seed
                appState.quickAddSeedQuery = nil
            }
        }
        .task {
            // Focus once the overlay is in the window; setting it in onAppear is too early
            // and the sidebar keeps first responder.
            try? await Task.sleep(for: .milliseconds(50))
            fieldFocused = true
        }
        .onAppear(perform: installEscapeMonitor)
        .onDisappear(perform: removeEscapeMonitor)
        .task(id: query) { await search() }
    }

    // MARK: Pieces

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search movies and shows", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { addSelected(as: .planToWatch) }
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
            if phase == .searching {
                ProgressView().controlSize(.small)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .failed(let message):
            hint(message, systemImage: "exclamationmark.triangle")
        case .done where results.isEmpty:
            hint("No movies or shows match “\(query)”.", systemImage: "magnifyingglass")
        case .idle:
            hint("Type to search TMDB. Return adds as Plan to Watch; ⌘1–⌘6 picks a status.", systemImage: "sparkle.magnifyingglass")
        default:
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results) { item in
                            QuickAddRow(
                                item: item,
                                existingStatus: inList[item.key],
                                isSelected: item.id == selection,
                                isAdding: adding.contains(item.id),
                                add: { status in add(item, as: status) }
                            )
                            .id(item.id)
                            .onTapGesture { selection = item.id }
                            .onTapGesture(count: 2) { add(item, as: .planToWatch) }
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selection) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let addError {
                Label(addError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else {
                Text("↩ Add · ⌘1 Plan · ⌘2 Watching · ⌘3 Caught Up · ⌘4 On Hold · ⌘5 Dropped · ⌘6 Completed")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("esc").foregroundStyle(.tertiary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial.opacity(0.6))
    }

    private func hint(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    /// Invisible buttons that give ⌘1–⌘6 to "add selected with status".
    private var statusShortcuts: some View {
        ZStack {
            ForEach(Array(ListStatus.allCases.enumerated()), id: \.element) { index, status in
                Button("") { addSelected(as: status) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            phase = .idle
            return
        }
        // Debounce: task(id:) cancels this sleep when the query changes again.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        phase = .searching
        do {
            let found = try await services.client.search(trimmed).compactMap(SearchItem.init)
            guard !Task.isCancelled else { return }
            results = found
            selection = found.first?.id
            phase = .done
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            phase = .failed(error.localizedDescription)
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selection } ?? -1
        let next = min(max(current + delta, 0), results.count - 1)
        selection = results[next].id
    }

    private func addSelected(as status: ListStatus) {
        guard let item = results.first(where: { $0.id == selection }) ?? results.first else { return }
        add(item, as: status)
    }

    private func add(_ item: SearchItem, as status: ListStatus) {
        guard !adding.contains(item.id) else { return }
        addError = nil
        adding.insert(item.id)
        Task {
            defer { adding.remove(item.id) }
            do {
                switch try await services.adder.add(item, status: status) {
                case .added:
                    // Stay open so several titles can be added in a row; the row now shows "In list".
                    break
                case .existing(let title):
                    close()
                    appState.sidebar = appState.sidebar ?? .upNext
                    appState.open(title)
                }
            } catch {
                addError = "Couldn't add “\(item.name)”: \(error.localizedDescription)"
            }
        }
    }

    /// The focused text field consumes Escape before SwiftUI's key handlers or a
    /// cancel-action button see it, so catch it at the event level while the panel is open.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            AppConfig.logger.info("TEMP keyDown \(event.keyCode, privacy: .public)")
            guard event.keyCode == 53 else { return event } // Escape
            close()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    private func close() {
        appState.isQuickAddPresented = false
    }
}

private struct QuickAddRow: View {
    let item: SearchItem
    let existingStatus: ListStatus?
    let isSelected: Bool
    let isAdding: Bool
    let add: (ListStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PosterView(path: item.posterPath, width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let year = item.year {
                        Text(year).foregroundStyle(.secondary).font(.caption)
                    }
                    KindTags(kind: item.kind, isAnime: item.isAnime)
                }
            }
            Spacer()
            if isAdding {
                ProgressView().controlSize(.small)
            } else if let existingStatus {
                Label("In list · \(existingStatus.label)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Menu {
                    ForEach(ListStatus.allCases) { status in
                        Button(status.label) { add(status) }
                    }
                } label: {
                    Text("Add")
                } primaryAction: {
                    add(.planToWatch)
                }
                .menuStyle(.button)
                .fixedSize()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}
