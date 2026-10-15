# Proposal

## Why

Users want to know which streaming services carry each title in their library, so they can quickly find where to watch something. TMDB provides watch provider data per region, but the MVP doesn't expose it yet. This change adds where-to-watch badges filtered to a user's "My services" setting, plus the required JustWatch attribution per TMDB's terms.

## What Changes

- New "My services" setting: a list of streaming services the user subscribes to (e.g., Netflix, HBO Max, Hulu, Apple TV)
- Region setting (defaults to US), since provider data is region-specific
- Where-to-watch badges in Library rows and title detail, showing which of "My services" carry the title
- JustWatch attribution text and link per TMDB requirements
- TMDB client extended to fetch watch provider data
- SwiftData schema extended to cache provider data per title

**Changed from initial scope:**
- None

**Out of scope:**
- Filtering Library by availability on specific services
- Notifications when a title becomes available on a service
- Provider links (deeplinks to the service)

## Capabilities

### New Capabilities

- `where-to-watch`: Display watch provider badges filtered to the user's subscribed services, with region selection and JustWatch attribution

### Modified Capabilities

- `title-metadata`: Extend to fetch and cache watch provider data from TMDB
- `library`: Show provider badges on each title row
- `title-detail`: Show provider badges in the header

### Unmodified Capabilities

All other capabilities remain unchanged.
