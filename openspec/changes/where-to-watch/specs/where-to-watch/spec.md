# Where to Watch

Users can see which of their subscribed streaming services carry each title.

## Requirements

### Provider badges

- Badges show only `flatrate` providers
- Provider badges appear in Library rows after the score
- Provider badges appear in Up Next rows, before the log button
- Provider badges appear in the title detail header below the overview
- Only providers in "My services" are shown
- When no providers match "My services", nothing is shown (no placeholder or empty state)
- *OQ1 (unresolved):* behavior when "My services" is empty: show no badges, or show all flatrate providers
- Badges are only shown when the cached data's region equals the current region setting
- Maximum 5 badges displayed, ordered by TMDB display priority
- If more than 5 providers match, show a "+N more" indicator
- Badges show provider logo (small in Library and Up Next, medium in detail)
- If logo unavailable, show provider name as text

### My services setting

- User can select which streaming services they subscribe to
- Options are built from TMDB's provider list for the selected region (`/watch/providers/movie` and `/watch/providers/tv`, merged by provider ID); no hardcoded list
- The last successful provider list per region is cached so the picker works offline
- If no list can be loaded, the picker shows an error with Retry and keeps existing selections
- Selections stored as TMDB provider IDs in UserDefaults
- Defaults to an empty selection
- Exposed in the Settings window's "Where to Watch" tab

### Region setting

- User can select their region for provider data
- Defaults to "US"
- Common regions available: US, CA, GB, JP, AU, DE, FR, IT, ES, BR, MX
- Stored in UserDefaults
- Exposed in the Settings window's "Where to Watch" tab

### Region change

- Cached provider data records the region it was fetched for
- On region change, cached data for the old region stops being displayed immediately
- On region change, provider data is refetched for all titles right away, not at the next scheduled refresh
- Offline, no badges are shown until a refetch for the new region succeeds

### JustWatch attribution

- Attribution is required by TMDB terms and is shown wherever provider data appears
- Title detail: "Powered by JustWatch" link under the badges, to the title's JustWatch link (fallback https://www.justwatch.com), whenever badges are shown
- Library and Up Next: one "Provider data powered by JustWatch" footer whenever any visible row shows badges
- My services picker: "Service list powered by JustWatch" caption
- About window and Settings About tab: "Powered by JustWatch" with a link to https://www.justwatch.com, below the TMDB attribution

### Provider data caching

- Provider data is fetched by `MetadataRefresher` through `TMDBClient`; `TitleMapper.apply` performs no network I/O
- Cached as JSON on each Title (`providerDataJSON`, non-optional, empty until first fetch)
- Refreshed on the existing scheduler cadence (launch, every 24 h, on wake when stale) for all titles, movies and shows
- A title's provider data is due when missing, unreadable, for another region, or at least 24 h old
- The detail view's Refresh action also refreshes that title's provider data
- A failed provider fetch keeps the existing cache and does not fail the metadata refresh
- Works offline with cached data
- No provider data shown until first successful fetch

## Scenarios

### Library badges

Given: A title is in the Library  
And: The title is available (flatrate) on Netflix and Hulu in the current region  
And: "My services" includes Netflix  
Then: The Library row shows a Netflix badge  
And: The Hulu badge is not shown  
And: The JustWatch footer is shown below the list

### Up Next badges

Given: A show is in Up Next  
And: The show is available on Crunchyroll in the current region  
And: "My services" includes Crunchyroll  
Then: The Up Next row shows a Crunchyroll badge  
And: The JustWatch footer is shown below the list

### Detail badges

Given: A title detail is open  
And: The title is available on Netflix, Hulu, Disney+, Max, Apple TV+, and Paramount+  
And: "My services" includes all six services  
Then: Five provider badges are shown  
And: A "+1 more" indicator is shown  
And: A "Powered by JustWatch" link is shown under the badges

### None match

Given: "My services" includes Netflix only  
And: A title is available on Hulu only  
Then: No provider badges are shown for that title  
And: No error or empty state is shown

### Empty My services (OQ1, unresolved)

Given: "My services" is empty  
And: A title is available on Netflix and Hulu  
Then: *Pending OQ1:* either no badges are shown, or both Netflix and Hulu badges are shown

### No providers available

Given: A title has no provider data cached  
Or: No flatrate providers are available in the selected region  
Then: No provider badges are shown  
And: No error or empty state is shown

### My services from TMDB

Given: Region is "US"  
When: User opens the Settings "Where to Watch" tab  
Then: The My services list shows TMDB's US movie and TV providers, merged, without duplicates  
And: "Service list powered by JustWatch" is visible

### My services offline

Given: The US provider list was loaded once before  
And: The app is offline  
When: User opens the Settings "Where to Watch" tab  
Then: The cached US provider list is shown and selections are editable

### Region change

Given: Region is set to "US"  
And: US provider data has been cached for all titles  
When: User changes region to "GB"  
Then: US badges disappear immediately  
And: Provider data is refetched for all titles without waiting for the next scheduled refresh  
And: Badges show GB providers once the refetch completes

### Region change offline

Given: Region is "US" with US data cached  
And: The app is offline  
When: User changes region to "GB"  
Then: No badges are shown  
When: User changes region back to "US"  
Then: The cached US badges are shown again

### Movie provider refresh

Given: A movie is in the Library  
And: Its provider data is more than 24 h old  
When: The scheduled refresh runs  
Then: The movie's provider data is refetched

### Provider fetch fails

Given: A title has cached provider data  
When: The provider fetch fails during refresh  
Then: The cached provider data is kept  
And: The title's metadata refresh is not counted as failed

### JustWatch attribution in About

Given: The About window or Settings About tab is open  
Then: "Powered by JustWatch" text with link is visible below the TMDB attribution  
And: The link opens https://www.justwatch.com
