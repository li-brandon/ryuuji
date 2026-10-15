# Tasks

## 1. Extend SwiftData model for provider data

- [ ] Add `providerDataJSON: Data` property to `Title` model
- [ ] Add helper method `var watchProviders: WatchProviderData?` to decode cached JSON
- [ ] Verify: Migration-free (optional property)

## 2. Define provider data types

- [ ] Create `WatchProviderData` struct (region, providers, link)
- [ ] Create `ProviderInfo` struct (id, name, logoPath, displayPriority)
- [ ] Make both `Codable` for JSON storage
- [ ] Add decoding tests

## 3. Extend TMDB client for watch providers

- [ ] Add `watchProviders(for:region:)` method to `TMDBClient` protocol
- [ ] Implement in `URLSessionTMDBClient`
- [ ] Parse TMDB response and extract flatrate providers only
- [ ] Add decoding test with recorded fixture
- [ ] Verify: Error handling for missing region data

## 4. Integrate provider fetching into metadata refresh

- [ ] Fetch provider data in `TitleMapper.apply()`
- [ ] Store as JSON on `Title.providerDataJSON`
- [ ] Use current region setting from UserDefaults
- [ ] Verify: Refresher updates provider data on schedule

## 5. Add user settings for My services and region

- [ ] Add `@AppStorage("myServices")` array in settings view
- [ ] Add `@AppStorage("providerRegion")` string in settings view
- [ ] Default region to "US"
- [ ] Default My services to empty array
- [ ] Create multi-select picker for common services (Netflix, Hulu, etc.)
- [ ] Create single-select picker for common regions
- [ ] Verify: Settings persist across launches

## 6. Create provider badge component

- [ ] Create `ProviderBadgeView` with logo from TMDB image path
- [ ] Support small (20x20) and medium (32x32) sizes
- [ ] Fall back to provider name text if logo unavailable
- [ ] Use TMDB logo size w45 for badges
- [ ] Verify: Logos load and display correctly

## 7. Add provider badges to Library rows

- [ ] Read My services setting
- [ ] Filter providers to My services (or show all if empty)
- [ ] Display up to 5 badges after score
- [ ] Show "+N more" text if more than 5
- [ ] Verify: Badges appear correctly sized and positioned

## 8. Add provider badges to title detail

- [ ] Add provider badges section below overview in detail header
- [ ] Use medium size badges
- [ ] Filter and limit same as Library
- [ ] Verify: Badges appear correctly in detail view

## 9. Add JustWatch attribution

- [ ] Add "Powered by JustWatch" text with link to About/Settings window
- [ ] Place below TMDB attribution
- [ ] Link to https://www.justwatch.com
- [ ] Verify: Attribution visible and link works

## 10. Testing and verification

- [ ] Test with various service combinations
- [ ] Test with empty My services (show all)
- [ ] Test with no provider data cached
- [ ] Test with more than 5 providers
- [ ] Test region change and refresh
- [ ] Test offline with cached data
- [ ] Verify TMDB attribution requirements met
