# Tasks

## 1. Project Setup

- [x] 1.1 Create the Xcode project `Ryuuji` in the repo root (macOS > App, SwiftUI, SwiftData storage, Swift Testing), set the deployment target to macOS 27, and verify `xcodebuild -scheme Ryuuji build` succeeds and the empty app launches
- [x] 1.2 Add `.gitignore` for Xcode (DerivedData, xcuserdata, `Secrets.xcconfig`), and verify `git status` shows no build output or user data
- [x] 1.3 Add `Secrets.example.xcconfig` with a `TMDB_TOKEN` key, wire `Secrets.xcconfig` into the build configuration and an Info.plist key, and verify the app can read the token at runtime (a debug log of its presence, not its value)
- [x] 1.4 Write `README.md` with setup steps (get a TMDB read access token, copy the example xcconfig, build), and verify a fresh clone builds by following them

## 2. Domain Core

- [x] 2.1 Define the value types `Kind`, `ListStatus`, `ShowStatus`, `SeasonInfo`/`EpisodeInfo` (Codable, with `schemaVersion`), and `EventRef`, and verify they compile and round-trip through JSON in a test
- [x] 2.2 Implement `AnimeClassifier.isAnime`, and verify tests for the anime-tagging scenarios (Japanese animated show tagged, Western animated show not tagged)
- [x] 2.3 Implement `Progress.compute` (aired rule with injected today, specials excluded, event-to-episode matching by tmdbEpisodeId then season/episode, next episode, remaining count, rewatch counts, orphans), and verify tests for the progress, gap, future-episode, missing-air-date, specials, and rewatch-count scenarios
- [x] 2.4 Implement `StatusEngine` for the `.log`, `.unmark`, and `.refresh` triggers, and verify one test per scenario in `specs/list-status/spec.md`

## 3. Persistence and Logging

- [x] 3.1 Define the SwiftData `Title` and `WatchEvent` models in `SchemaV1` following CloudKit rules (defaults or optionals everywhere, optional relationships, no unique attributes, raw-string enums), with typed accessors and a memoized decode of `episodesData`, and verify that an in-memory container inserts and fetches both models
- [x] 3.2 Implement `TitleRepository.find(tmdbId:kind:)` and an insert-if-absent operation, and verify a test that adding the same TMDB title twice yields one `Title`
- [x] 3.3 Implement `WatchLogService` (`log`, `logAgain`, `bulkMark(season|all)` with a shared `batchId`, `unmark`, `deleteEvent`), each running `StatusEngine`, and verify tests for every scenario in `specs/watch-log/spec.md` against an in-memory container
- [x] 3.4 Add undo registration to `WatchLogService` (one step per action, restoring events and previous status), and verify tests that undo after a single log and after a bulk mark restores the prior events and status

## 4. TMDB Client and Metadata

- [x] 4.1 Implement the `TMDBClient` protocol and URLSession client (Bearer auth, `search/multi` filtered to movie/tv, `movie/{id}`, `tv/{id}` with `append_to_response` season batching of 20), plus a missing-token error, and verify decoding tests against recorded JSON fixtures for a movie, an anime show with 2+ seasons, and a search response
- [x] 4.2 Implement the mapping from TMDB responses to `Title` fields and the `episodesData` blob (including `isAnime`), and verify tests on the fixtures
- [x] 4.3 Implement metadata application on refresh: replace the blob, renumber matched events per D4, keep orphans, never delete events, and verify the renumbered-episode and removed-episode scenarios in tests
- [x] 4.4 Implement `MetadataRefresher` (selection rule, at most 4 concurrent requests, `.refresh` status pass, `lastRefreshedAt` set only on success), and verify tests with a fake client for the new-episode (Caught Up to Watching), show-ends (to Completed), paused-untouched, and refresh-fails scenarios

## 5. App Shell and Quick Add

- [x] 5.1 Build the `NavigationSplitView` shell with Up Next (default), Library, and History sidebar items, the model container, and the shared services in the environment, and verify the app launches to Up Next
- [ ] 5.2 Enlarge the shared `URLCache` and add a reusable poster view (w185/w342), and verify by running the app that posters load and still show offline after the first load
- [x] 5.3 Add the Cmd-K command and quick-add overlay (focused field, Escape to dismiss, 300 ms debounced search, result rows with year, type, poster, Anime tag, and "In list" marker), and verify by running the app that Cmd-K opens the panel from every view
- [x] 5.4 Implement add-from-result (Return adds as Plan to Watch, the status menu or Cmd-1 to Cmd-6 adds with a chosen status, a movie added as Completed logs an event, selecting an existing title opens its detail), plus error and missing-token messages, and verify each `title-search` scenario by running the app

## 6. Up Next

- [x] 6.1 Build the Up Next list (Watching shows with a next episode, sorted by latest activity then addedAt; rows with poster, name, "SxEy · name", "N left", and "+"; empty state mentioning Cmd-K), and verify the row and ordering scenarios by running the app with sample data
- [x] 6.2 Wire "+" to `WatchLogService.log` and Cmd-Z to undo, and wire row selection to title detail, and verify by running the app that "+" advances the row, the last episode removes the row, and Cmd-Z reverts both

## 7. Title Detail

- [x] 7.1 Build the detail header (poster, name, year, kind and Anime tag, overview, TMDB show status, progress) with editable status, score (1 to 10, clearable), and notes, plus a Refresh action, and verify by running the app that edits persist across relaunch
- [x] 7.2 Build the season and episode checklist (per-season progress, unaired rows disabled with date or "TBA", rewatch badge, specials section last, check/uncheck wired to log/unmark, "Log again" context action), and verify each `title-detail` checklist scenario by running the app
- [x] 7.3 Add "Mark season watched" and "Mark all watched", and the movie actions ("Mark watched", watch count, "Log again", "Unmark"), and verify the bulk and movie scenarios by running the app, including Cmd-Z after a bulk mark

## 8. Library

- [x] 8.1 Build the Library with All plus per-status filters showing counts, a kind filter (All, Shows, Movies, Anime), sort options, and items showing poster, name, year, kind, score, and show progress "x/y", and verify the filter, sort, and progress scenarios by running the app with sample data
- [x] 8.2 Add the context menu (change status, set score, open detail, remove with a confirmation dialog that cascades events), and verify the remove and cancel-removal scenarios by running the app

## 9. History

- [x] 9.1 Build History (events newest first, grouped by local day, rows with title, "SxEy · name" or "Movie", time, and a rewatch marker; bulk batches collapsed into one expandable row), and verify the grouping, rewatch, and bulk-row scenarios by running the app
- [x] 9.2 Add delete-event (via `WatchLogService.deleteEvent`, undoable) and row selection opening the title detail, and verify by running the app that deleting the only event for an episode marks it unwatched

## 10. Refresh Scheduling and Attribution

- [x] 10.1 Trigger `MetadataRefresher` on launch, on a 24-hour timer, and on system wake when stale, and verify by running the app (log output) that a refresh runs on launch and that a changed fixture or real airing updates Up Next
- [x] 10.2 Add an About/Settings window with the TMDB logo and the required notice, and verify the attribution scenario by running the app

## 11. Integration Check

- [ ] 11.1 End-to-end pass against live TMDB, with each step checked by running the app:
  1. Cmd-K add a returning anime as Plan to Watch.
  2. Log its first episode from title detail; it becomes Watching and appears in Up Next.
  3. Click "+" through to Caught Up.
  4. Undo once.
  5. Mark season 1 of an ended show watched; it becomes Completed.
  6. Confirm History shows all of the above correctly.
  7. Quit and relaunch; all data persists.
- [x] 11.2 Run the full unit test suite with `xcodebuild test -scheme Ryuuji`, and verify all tests pass
