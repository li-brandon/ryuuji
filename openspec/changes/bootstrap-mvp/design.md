# Design

## Context

The repo is empty apart from `openspec/`. Xcode 27 is installed. See proposal.md for motivation and scope, and `specs/` for the behavior contract. Constraints that shape this design:

- Single user, single Mac. The local store is the source of truth.
- TMDB v3 is the only network dependency. It is read-only and rate-limited, at roughly 50 requests per second per IP.
- Sync to an iPhone via CloudKit is a later, additive change. The schema has to follow CloudKit's rules from day one.

## Goals / Non-Goals

**Goals:**
- Logging from Up Next finishes instantly, with no network round-trip.
- All status and progress logic is plain Swift that can be unit-tested without SwiftData or the network.
- The schema can be synced through CloudKit later without migrating existing data.

**Non-Goals:**
- No abstraction over metadata providers. TMDB types are used directly, and a second provider is explicitly out of scope.
- No App Store distribution concerns such as sandbox entitlement review or notarization. The app is built and run locally.
- No custom design system. The app uses standard SwiftUI macOS controls.

## Decisions

### D1. Project setup: Xcode-created project, macOS 27 target
Create the project with Xcode's New Project dialog (macOS > App, SwiftUI, SwiftData storage, Swift Testing). Set the deployment target to macOS 27 to match the development machine; a personal app has no reason to support older systems.
- *Alternative:* XcodeGen or Tuist give a project file that diffs cleanly, but add tooling a solo project doesn't need.
- *Alternative:* A pure Swift package can't produce a proper `.app` bundle with Info.plist and assets without extra work.

### D2. Two synced models; list fields live on `Title`
```
Title  (1) ----< (N) WatchEvent
```
- **`Title`** holds:
  - `tmdbId: Int`
  - `kindRaw: String` (movie or show)
  - `isAnime: Bool`
  - cached display fields
  - `showStatusRaw: String?`
  - `episodesData: Data` (see D3)
  - `lastRefreshedAt: Date?`
  - list fields: `statusRaw: String`, `score: Int?`, `notes: String`, `addedAt: Date`
  - `events: [WatchEvent]?` with cascade delete
- **`WatchEvent`** holds:
  - `title: Title?`
  - `watchedAt: Date`
  - `season: Int?` and `episode: Int?`
  - `tmdbEpisodeId: Int?`
  - `batchId: UUID?` (shared by events created in one bulk mark, so History can group them)

The `ListEntry` model from the brief is merged into `Title`, because a title never exists without its entry.
- *Alternative:* a separate `ListEntry` model. That adds a 1:1 optional relationship which CloudKit can't enforce, for no benefit.

CloudKit rules applied:
- Every property has a default value or is optional.
- Every relationship is optional.
- No `@Attribute(.unique)`.
- Enums are stored as raw `String`s, with typed accessors.

### D3. Episode metadata is a re-fetchable JSON blob, not SwiftData models
Seasons and episodes are stored as `[SeasonInfo]` Codable structs, encoded to `episodesData`. Each episode carries `tmdbId`, `season`, `number`, `name`, `airDate`, and `runtime`. A refresh replaces the blob in one write.
- *Why:* it's cache data that TMDB can rebuild at any time. As models, a long anime would mean thousands of rows to sync through CloudKit, and refreshing would mean a reconciliation diff instead of a replace. The app never needs to query episodes across titles.
- *Alternative:* `Season` and `Episode` `@Model`s. They are queryable, but add sync volume and refresh complexity.
- The blob carries a `schemaVersion`. If decoding fails, the title is treated as needing an immediate refresh rather than crashing.

### D4. Events match episodes by TMDB episode id first
A watch event matches an episode if their `tmdbEpisodeId`s are equal. If the event has no id, it matches on `(season, episode)` instead. After each refresh, the stored `season` and `episode` on matched events are rewritten to TMDB's current numbering. This keeps logs attached when TMDB renumbers, as the `title-metadata` spec requires. Events that match nothing are kept as orphans: they appear in History, but not in progress.

### D5. Pure domain core
A `Domain/` folder of plain value types and functions, independent of SwiftData:
- `Progress.compute(episodes:events:today:)` returns the watched set, aired regular episodes, the next episode, remaining count, and per-episode rewatch counts.
- `StatusEngine.status(after:trigger:current:progress:kind:showStatus:)`, where `trigger` is `.log`, `.unmark`, or `.refresh`. It implements the rules in the `list-status` spec as a single function.
- `AnimeClassifier.isAnime(genres:originCountries:originalLanguage:)`.
- An injected `today` (a `Clock` or `Date` provider), so tests that depend on air dates are deterministic.

Views and services call into this core. The unit tests target it directly.

### D6. `WatchLogService` owns every write that touches events
This is a `@MainActor` service. It performs `log`, `logAgain`, `bulkMark(scope)`, `unmark`, and `deleteEvent`. Each operation:
1. snapshots the previous status and the affected events
2. mutates the data
3. runs `StatusEngine`
4. saves
5. registers one undo action on the window's `UndoManager`, which restores the snapshot

- *Alternative:* SwiftData's built-in `undoManager` on the model context. It records every change, including metadata refreshes and status side effects, as separate undo steps. Explicit registration gives exactly one undo step per user action, as the spec requires.

### D7. TMDB client
A `TMDBClient` protocol with a `URLSession` implementation and a fixture-backed fake for tests. Endpoints used:
- `GET /search/multi`, keeping only `media_type` values `movie` and `tv`
- `GET /movie/{id}`
- `GET /tv/{id}?append_to_response=season/1,season/2,...`, batched at 20 seasons per request, which is TMDB's limit on appended responses

Authentication uses the v4 Read Access Token as a Bearer header. The token comes from a git-ignored `Secrets.xcconfig` and reaches the app through an Info.plist key. If the key is missing, search shows the error defined in the `title-search` spec. Search is debounced by cancelling the previous `Task` and sleeping 300 ms before starting a new one.

### D8. Metadata refresh
A `MetadataRefresher` (`@ModelActor`) runs:
- on launch
- on a 24-hour timer
- on system wake, if the last run was more than 24 hours ago

It selects titles per the `title-metadata` spec: shows not Ended or Canceled, plus anything not refreshed in 7 days. It fetches with at most 4 requests in flight, then applies `StatusEngine` with `.refresh` to each title. Failures are logged and skipped, and `lastRefreshedAt` is updated only on success.

### D9. Navigation and Cmd-K
- A `NavigationSplitView` sidebar with three items: Up Next (the default), Library, and History. Library's status filters appear in its content pane.
- Title detail opens in the detail column.
- Cmd-K is a `CommandMenu` item with `.keyboardShortcut("k")`, so it works in every view. It shows a centered quick-add panel as an overlay.
- In the panel, Return adds with the default status. Each result also has a status menu (Cmd-1 to Cmd-6) for adding with a specific status.

### D10. Images
Posters load from TMDB's image CDN at size `w185` for lists and `w342` for detail. The shared `URLCache` is enlarged to about 200 MB on disk so posters stay visible offline after their first load. Posters are not stored in SwiftData.

### D11. Tests
Swift Testing in the unit test target:
- domain-core tests for every scenario in the `watch-log`, `list-status`, `up-next`, and `title-metadata` (aired, specials, anime) specs
- TMDB decoding tests against recorded JSON fixtures
- `WatchLogService` tests on an in-memory `ModelContainer`

UI is verified by running the app; there are no UI tests in the MVP.

## Risks / Trade-offs

- [TMDB anime numbering differs from the streamer, e.g. one long season versus split cours] → D4 keeps logs safe across renumbering. Further mapping is out of scope; the user follows TMDB numbering.
- [The JSON blob can't be queried, and the whole show is re-decoded per view] → Decode once per title and memoize on the in-memory model. Even long anime are about 1,000 episodes, which is trivial to decode.
- [The blob syncs through CloudKit later as one large field] → The later CloudKit change can exclude it by moving the cache to a separate local-only store. The synced user data (status, score, notes, events) is unaffected.
- [Status recomputation is surprising after a manual override] → The rules are deliberately narrow: refresh only touches Watching and Caught Up. Every log action can be undone with Cmd-Z.
- [TMDB rate limits during a large refresh] → At most 4 concurrent requests, seasons batched with `append_to_response`, and Ended shows are skipped.
- [API token embedded in the local build] → Acceptable for a personal, locally built app. It never enters git.

## Migration Plan

There is no existing data or app, so nothing needs migrating. Future schema changes will use SwiftData `VersionedSchema` starting from this version (`SchemaV1`).
