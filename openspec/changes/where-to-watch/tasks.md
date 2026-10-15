# Tasks

## 0. Resolve open question

- [ ] OQ1 (Brandon): empty My services shows no badges or all flatrate providers? Update spec, design D4, and tasks 7–9/12 with the answer

## 1. Extend SwiftData model for provider data

- [ ] Add `SchemaV2` (copy of V1) with `Title.providerDataJSON: Data = Data()` (non-optional, default empty)
- [ ] Add `SchemaV2` to `RyuujiMigrationPlan.schemas` and a `.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)` stage
- [ ] Point `Title` / `WatchEvent` typealiases and `RyuujiStore.makeContainer` at `SchemaV2`
- [ ] Add `Title.watchProviders: WatchProviderData?` (nil when empty/unreadable) and `setWatchProviders(_:)` in `Title+Domain.swift`
- [ ] Verify: a V1 store opens and migrates with `providerDataJSON` empty (ModelTests)

## 2. Define provider data types

- [ ] Create `WatchProviderData` (region, fetchedAt, providers, link) and `ProviderInfo` (id, name, logoPath, displayPriority); `Codable`, `Sendable`, `Equatable`
- [ ] Add raw `TMDBWatchProvidersResponse` and `TMDBProviderListResponse` to `TMDBModels.swift`
- [ ] Add pure `WatchProviderMapper` converting raw responses (flatrate only, sorted by display priority; empty providers when region missing)
- [ ] Add round-trip encode/decode tests

## 3. Extend TMDB client

- [ ] Add `watchProviders(for:region:)` and `providerCatalog(region:)` to `TMDBClient`
- [ ] Implement both in `LiveTMDBClient` using `get`
- [ ] `providerCatalog` fetches `/watch/providers/movie` and `/watch/providers/tv` with `watch_region`, merges by provider ID
- [ ] Implement both in `FakeTMDBClient` (with `failing` and `requestCount` support)
- [ ] Record fixtures: `tv-120089-watch-providers.json`, `movie-372058-watch-providers.json`, `watch-providers-movie-US.json`, `watch-providers-tv-US.json`
- [ ] Decoding tests against fixtures, including a region with no entry

## 4. Fetch provider data in the refresher (not in TitleMapper)

- [ ] Leave `TitleMapper.apply(_:to:)` unchanged and network-free
- [ ] Add `MetadataRefresher.isProviderDue(_:region:now:)` (missing, unreadable, other region, or ≥ 24 h old)
- [ ] `refreshDue` also fetches providers for all provider-due titles (movies and shows) with the same concurrency cap
- [ ] Add `refreshProviders(_:client:region:now:)` for region change and detail Refresh
- [ ] Apply via `title.setWatchProviders(_:)`; on failure keep cache and don't count metadata as failed
- [ ] `RefreshScheduler` reads `providerRegion` from its `defaults` and passes it through
- [ ] Detail Refresh also refreshes that title's providers
- [ ] Tests in `MetadataRefresherTests`: movie gets providers, ended show gets providers, failure keeps cache, region mismatch is due

## 5. Settings: region and My services

- [ ] Add `WhereToWatchSettingsView`; make the `Settings` scene a `TabView` with "Where to Watch" and "About"
- [ ] `@AppStorage("providerRegion")` default "US"; region picker with US, CA, GB, JP, AU, DE, FR, IT, ES, BR, MX
- [ ] `@AppStorage("myServices")` JSON `[Int]`, default empty
- [ ] Load options from `providerCatalog(region:)`; cache per region in UserDefaults (`providerCatalog.{region}`); show cached list offline
- [ ] Error + Retry when no list is available; keep existing selections
- [ ] "Service list powered by JustWatch" caption
- [ ] Verify: settings persist across launches

## 6. Region change handling

- [ ] On region change, trigger `refreshProviders` for all titles immediately
- [ ] Badge views hide data whose region differs from the current region (see task 7)
- [ ] Verify: switching US → GB hides US badges at once and shows GB badges after refetch; switching back offline restores cached US badges

## 7. Provider badge components

- [ ] `ProviderBadgeView`: logo via `TMDBImage.url(_:size:)` with new `Size.logo = "w92"`; small (20×20) and medium (32×32); name-text fallback
- [ ] `ProviderBadgeRow`: region check, My services filter (empty case per OQ1), max 5 + "+N more", renders nothing when nothing matches
- [ ] `JustWatchAttribution` view (link, footer, About variants)
- [ ] Unit-test the filtering/limiting logic as a pure function

## 8. Library and Up Next rows

- [ ] Add small `ProviderBadgeRow` to `LibraryRow` after the score
- [ ] Add small `ProviderBadgeRow` to `UpNextRow` before the log button
- [ ] Add JustWatch footer to Library and Up Next lists when any visible row shows badges
- [ ] Verify: badges sized/positioned correctly and rows don't truncate titles at default window width

## 9. Title detail

- [ ] Add medium `ProviderBadgeRow` below the overview in the header
- [ ] Add "Powered by JustWatch" link under badges (title's `link`, fallback justwatch.com) whenever badges show
- [ ] Verify: badges and attribution appear correctly

## 10. About attribution

- [ ] Add "Powered by JustWatch" with link to https://www.justwatch.com in `AboutView`, below TMDB attribution
- [ ] Verify: visible in both the About window and the Settings About tab; link opens

## 11. Live verification

- [ ] Run against live TMDB: badges, My services list, region switch, attribution in every location
- [ ] Run offline with cached data

## 12. Testing checklist

- [ ] Various My services combinations, including none matching
- [ ] Empty My services (expected result per OQ1)
- [ ] No provider data cached
- [ ] More than 5 matching providers
- [ ] Region change online and offline
- [ ] Movies and ended shows receive provider data
- [ ] JustWatch attribution present wherever provider data appears and in About
