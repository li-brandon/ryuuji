# Proposal

## Why

Users want to know which streaming services carry each title in their library, so they can quickly find where to watch something. TMDB provides watch provider data per region, but the MVP doesn't expose it yet. This change adds where-to-watch badges filtered to a user's "My services" setting, plus the JustWatch attribution TMDB's terms require for provider data.

## What Changes

- New "My services" setting: a multi-select built from TMDB's provider list for the selected region (`GET /watch/providers/{movie,tv}`)
- Region setting (defaults to US), since provider data is region-specific
- Where-to-watch badges for flatrate providers in Library rows, Up Next rows, and title detail
- JustWatch attribution wherever provider data appears (detail, Library, Up Next, My services picker) and in About
- `TMDBClient` extended to fetch per-title watch providers and the provider list
- SwiftData schema extended (SchemaV2, lightweight migration) to cache provider data per title
- `MetadataRefresher` fetches provider data for all titles (movies and shows) on the existing scheduler cadence; region changes invalidate cached data

**Changed from initial scope:**
- None. Behavior with an empty "My services" selection is unresolved (see design.md Open Questions).

**Out of scope:**
- Filtering Library by availability on specific services
- Notifications when a title becomes available on a service
- Provider deeplinks into each service's app/site (only the JustWatch link TMDB returns is used)
- `buy`, `rent`, and `ads` providers

## Capabilities

### New Capabilities

- `where-to-watch`: Display watch provider badges filtered to the user's subscribed services, with region selection and JustWatch attribution

### Modified Capabilities

- `title-metadata`: Fetch and cache watch provider data from TMDB on the refresh schedule
- `library`: Show provider badges on each title row
- `up-next`: Show provider badges on each row
- `title-detail`: Show provider badges in the header
- `about`: Add JustWatch attribution; Settings gains region and My services

### Unmodified Capabilities

All other capabilities remain unchanged.
