# Design

## Overview

Add where-to-watch functionality by fetching watch provider data from TMDB, caching it on titles, and displaying badges filtered to the user's subscribed services. Provider data requires JustWatch attribution per TMDB's terms, everywhere it is shown.

## Key Decisions

**D1. Provider data is cached per title, fetched by the refresher**
- `MetadataRefresher` fetches provider data through `TMDBClient` and writes it to each `Title` via a pure mapper function. `TitleMapper.apply(_:to:)` stays pure: it never performs network I/O and its signature is unchanged.
- Provider fetch failures are independent of metadata fetch failures: a failed provider fetch keeps the existing cache and does not count the title's metadata refresh as failed.
- Stored as JSON (`providerDataJSON`) for easy schema evolution, mirroring `episodesData`.
- Cadence: the existing `RefreshScheduler` (launch, every 24 h, wake when stale) calls `refreshDue`, which now also refreshes provider data for **every** title (movies and shows, including ended shows) whose provider cache is due (see D5). The detail view's Refresh action refreshes provider data for that title too.

**D2. "My services" and region are user preferences**
- Stored in UserDefaults via `@AppStorage`
- Default region is "US"
- Default My services selection is empty; what an empty selection displays is **Open Question OQ1**
- Edited in a new "Where to Watch" tab of the `Settings` scene

**D3. My services list comes from TMDB**
- The picker's options are TMDB's provider list for the selected region: `GET /watch/providers/movie?watch_region={region}` and `GET /watch/providers/tv?watch_region={region}`, merged by `provider_id` and sorted by the region's display priority, then name.
- No hardcoded service list. The last successful list per region is cached in UserDefaults (`providerCatalog.{region}`) so the picker works offline; it is re-fetched when the Settings tab appears or the region changes.
- If no list is available (first launch offline), the picker shows an inline "Couldn't load services from TMDB" message with a Retry button; already-selected IDs are preserved.
- Selections are stored as TMDB provider IDs, so they survive provider renames.

**D4. Badges shown in Library, Up Next, and detail**
- Only `flatrate` providers are badged
- Library rows: small logos after the score
- Up Next rows: small logos in the trailing area, before the log button
- Title detail header: medium logos below the overview
- Filtered to My services (empty-selection behavior per OQ1); when none match, nothing is shown (no placeholder, no empty state)
- Maximum 5 badges, then a "+N more" indicator; ordered by TMDB `display_priority`

**D5. Region change invalidates cached provider data immediately**
- Each cached `WatchProviderData` records the `region` it was fetched for.
- Badges are only rendered when the cached region equals the current region setting. Changing region therefore hides old-region badges immediately; there is no window of stale badges.
- Changing region also triggers an immediate provider-only refresh for all titles (via `MetadataRefresher`), without waiting for the next scheduled run. Offline, titles simply show no badges until a refresh succeeds.
- A title's provider cache is *due* when it is missing, unreadable, from a different region, or `fetchedAt` is ≥ 24 h old.
- Old-region data is overwritten on the next successful fetch, not eagerly deleted (no write storm on region change).

**D6. JustWatch attribution wherever provider data appears**
- About window and Settings About tab: JustWatch logo/text "Powered by JustWatch" with a link to https://www.justwatch.com, below the TMDB attribution.
- Title detail: a "Powered by JustWatch" link directly under the badges, pointing to the title's JustWatch `link` from the TMDB response (fallback: https://www.justwatch.com). Shown whenever badges are shown.
- Library and Up Next: a single "Provider data powered by JustWatch" footer below the list, shown whenever at least one visible row shows badges (per-row text would be noise).
- My services picker: "Service list powered by JustWatch" caption under the list.
- Attribution is a requirement, not optional.

## Data Model

Add `SchemaV2` with `Title` identical to V1 plus one attribute, and a lightweight stage in `RyuujiMigrationPlan`:

```swift
// SchemaV2.Title — CloudKit rules (V1 design D2): non-optional with a default.
/// JSON-encoded `WatchProviderData`. Empty until the first provider fetch.
var providerDataJSON: Data = Data()
```

```swift
nonisolated enum RyuujiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

typealias Title = SchemaV2.Title
typealias WatchEvent = SchemaV2.WatchEvent
```

`providerDataJSON` is **non-optional with a default of empty `Data()`** everywhere (model, tasks, tests). Empty data means "never fetched". This matches `episodesData` and satisfies lightweight migration; no custom stage is needed. `RyuujiStore.makeContainer` switches to `Schema(versionedSchema: SchemaV2.self)`.

Domain types (`nonisolated`, `Codable`, `Sendable`, `Equatable`):
```swift
nonisolated struct WatchProviderData: Codable, Sendable, Equatable {
    var region: String
    var fetchedAt: Date
    var providers: [ProviderInfo]   // flatrate only, sorted by displayPriority
    var link: String?               // JustWatch link for this title/region
}

nonisolated struct ProviderInfo: Codable, Sendable, Equatable, Identifiable {
    var id: Int                     // TMDB provider_id
    var name: String
    var logoPath: String?
    var displayPriority: Int
}
```

`Title` extension (in `Title+Domain.swift`):
```swift
/// Cached providers, or nil if never fetched or unreadable.
var watchProviders: WatchProviderData? { get }
func setWatchProviders(_ data: WatchProviderData)
```

User preferences (UserDefaults):
```swift
@AppStorage("providerRegion") private var region: String = "US"
@AppStorage("myServices") private var myServicesJSON: Data = Data()   // JSON [Int]
// "providerCatalog.{region}" — JSON [ProviderInfo], last successful provider list
```

## TMDB Integration

Extend `TMDBClient`:
```swift
/// Flatrate providers for one title in `region`. Returns empty providers when TMDB has no
/// entry for the region (not an error).
func watchProviders(for key: TitleKey, region: String) async throws -> WatchProviderData
/// TMDB's provider list for `region`, movie and TV merged by id.
func providerCatalog(region: String) async throws -> [ProviderInfo]
```

Implemented in `LiveTMDBClient` (via its existing `get` helper) and `FakeTMDBClient`.

Endpoints:
- `GET /movie/{id}/watch/providers`, `GET /tv/{id}/watch/providers`
- `GET /watch/providers/movie?watch_region={region}`, `GET /watch/providers/tv?watch_region={region}`

Per-title response (only `results[region].flatrate` is used; `buy`, `rent`, `ads` ignored):
```json
{
  "id": 120089,
  "results": {
    "US": {
      "link": "https://www.themoviedb.org/tv/120089/watch?locale=US",
      "flatrate": [
        {"logo_path": "/...", "provider_id": 283, "provider_name": "Crunchyroll", "display_priority": 0}
      ]
    }
  }
}
```

Raw response types (`TMDBWatchProvidersResponse`, `TMDBProviderListResponse`) live in `TMDBModels.swift` and decode with `TMDBJSON.decoder`. `convertFromSnakeCase` also rewrites dictionary keys, but ISO region codes contain no underscores, so `results["US"]` is unaffected. Converting raw responses to `WatchProviderData` / `[ProviderInfo]` is a pure function (`WatchProviderMapper`), unit-tested against fixtures.

Provider logos use `TMDBImage.url(_:size:)` with a new `Size.logo = "w92"` case (sharp at 32 pt on Retina).

## Refresher Integration

- `MetadataRefresher.refreshDue(client:region:...)` keeps its current metadata selection (`isDue`, shows only) and additionally selects all titles where `isProviderDue(_:region:now:)` is true.
- Provider fetches go through the same bounded concurrency (`maxConcurrentRequests`) as metadata fetches.
- New `refreshProviders(_ keys: [TitleKey], client:region:now:)` for region-change and detail Refresh.
- `RefreshScheduler` reads the region from its `defaults` and passes it through.
- Results are applied with `title.setWatchProviders(_:)`; `TitleMapper.apply` is untouched.

## UI Components

**ProviderBadgeView** — logo from TMDB; small (20×20) and medium (32×32); falls back to provider name text when there's no logo or it fails to load.

**ProviderBadgeRow** — takes `WatchProviderData?`, region, and My services; applies the region check (D5), filter (D4/OQ1), and 5 + "+N more" limit. Renders nothing when there's nothing to show. Shared by Library, Up Next, and detail.

**JustWatchAttribution** — small reusable view (variants: link-only, footer caption, About block).

**WhereToWatchSettingsView** — region picker (US, CA, GB, JP, AU, DE, FR, IT, ES, BR, MX) and the My services multi-select from the TMDB catalog (D3), with JustWatch caption. The `Settings` scene becomes a `TabView` with "Where to Watch" and "About" (`AboutView`) tabs.

## Open Questions

**OQ1 (for Brandon): What does an empty My services selection show?**
- The ticket AC says "nothing shown when none match", which read literally means an empty selection shows **no badges** (and the feature is invisible until configured).
- The earlier draft of this design said an empty selection shows **all** flatrate providers, so the feature is useful out of the box.
- These conflict. This spec does not pick one; requirements, scenarios, and tasks that depend on it are marked *OQ1*. Implementation of those paths is blocked until resolved.

## Acceptance Criteria

- Provider badges appear in Library rows, Up Next rows, and the title detail header
- Only flatrate providers in My services for the current region are shown; nothing when none match (empty selection per OQ1)
- Maximum 5 badges with "+N more" indicator
- Settings shows region and a My services multi-select built from TMDB's provider list
- JustWatch attribution shown wherever provider data appears and in About
- Provider data refreshed on the existing `MetadataRefresher` cadence for movies and shows; works offline from cache
- Changing region hides old-region badges immediately and refetches
- Verified by running the app against live TMDB
