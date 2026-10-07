import SwiftUI

/// About / Settings screen with the TMDB attribution required by its terms.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Ryuuji")
                    .font(.largeTitle.bold())
                Text(version)
                    .foregroundStyle(.secondary)
                Text("Track the shows, movies, and anime you watch.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 10) {
                Image("TMDBLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                    .accessibilityLabel("The Movie Database (TMDB)")
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Link("themoviedb.org", destination: URL(string: "https://www.themoviedb.org")!)
            }

            Divider()

            Label(
                AppConfig.tmdbToken == nil ? "No TMDB token configured. Search is unavailable." : "TMDB token configured.",
                systemImage: AppConfig.tmdbToken == nil ? "exclamationmark.triangle" : "checkmark.seal"
            )
            .font(.caption)
            .foregroundStyle(AppConfig.tmdbToken == nil ? .orange : .secondary)
        }
        .padding(28)
        .frame(width: 400)
    }
}
