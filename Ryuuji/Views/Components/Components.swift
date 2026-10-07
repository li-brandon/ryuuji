import SwiftUI

/// A TMDB poster at 2:3, with a placeholder while loading or when missing.
struct PosterView: View {
    var path: String?
    var size: TMDBImage.Size = .list
    var width: CGFloat

    var body: some View {
        AsyncImage(url: TMDBImage.url(path, size: size)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: width > 80 ? 8 : 4))
        .overlay {
            RoundedRectangle(cornerRadius: width > 80 ? 8 : 4)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: width * 0.3))
            }
    }
}

/// A small capsule label such as "Anime" or "Movie".
struct TagView: View {
    var text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

/// Kind and anime tags for a title.
struct KindTags: View {
    var kind: Kind
    var isAnime: Bool

    var body: some View {
        HStack(spacing: 4) {
            TagView(text: kind.label)
            if isAnime {
                TagView(text: "Anime", tint: .pink)
            }
        }
    }
}

extension EpisodeInfo {
    /// "S2E5 · The Return"
    var displayName: String {
        name.isEmpty ? code : "\(code) · \(name)"
    }
}

extension Title {
    /// "2022 · Returning Series"
    var subtitle: String {
        var parts: [String] = []
        if let year { parts.append(year) }
        if kind == .show, showStatus != .unknown { parts.append(showStatus.rawValue) }
        if kind == .movie, let runtime { parts.append("\(runtime) min") }
        return parts.joined(separator: " · ")
    }
}

/// The status picker used in the detail view and context menus.
struct StatusPicker: View {
    @Bindable var title: Title

    var body: some View {
        Picker("Status", selection: $title.status) {
            ForEach(ListStatus.allCases) { status in
                Label(status.label, systemImage: status.systemImage).tag(status)
            }
        }
    }
}

/// Score picker: none or 1–10.
struct ScorePicker: View {
    @Bindable var title: Title

    var body: some View {
        Picker("Score", selection: $title.score) {
            Text("No Score").tag(Int?.none)
            Divider()
            ForEach((1...10).reversed(), id: \.self) { score in
                Text("\(score)").tag(Int?.some(score))
            }
        }
    }
}
