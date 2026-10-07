# Ryuuji

A native macOS app (SwiftUI + SwiftData) for tracking the shows, movies, and anime you want to watch and have watched. Inspired by [Taiga](https://taiga.moe), but shares no code with it. Metadata comes from [TMDB](https://www.themoviedb.org).

## Requirements

- macOS 27
- Xcode 27
- A free TMDB account

## Setup

1. **Get a TMDB token.** Sign in at themoviedb.org, open *Settings > API*, and copy the **API Read Access Token** (the long one, not the short "API Key").
2. **Create your secrets file.**
   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```
   Paste the token after `TMDB_TOKEN = `. `Config/Secrets.xcconfig` is git-ignored.
3. **Build and run.** Open `Ryuuji.xcodeproj` and press Cmd-R, or build from the terminal:
   ```sh
   xcodebuild -project Ryuuji.xcodeproj -scheme Ryuuji -derivedDataPath build build
   open build/Build/Products/Debug/Ryuuji.app
   ```

Without a token the app still builds and runs; search will tell you a token is missing.

## Install

```sh
scripts/install.sh
```

This builds a Release copy, quits Ryuuji if it's running, and replaces `/Applications/Ryuuji.app`. Run it again whenever you want to update the installed app. Your library is kept between installs.

## Tests

```sh
xcodebuild -project Ryuuji.xcodeproj -scheme Ryuuji -derivedDataPath build test
```

## Project layout

- `Ryuuji/` contains app sources. The Xcode project syncs this folder automatically, so new files need no project edits.
- `RyuujiTests/` contains unit tests (Swift Testing).
- `Config/` contains build configuration and the secrets template.
- `openspec/` contains specs and change proposals.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.
