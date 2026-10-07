# Proposal

## Why

I want one place to track the shows, movies, and anime I plan to watch and have watched. I watch on streaming services, so the app can't detect playback and logging has to be manual and fast. Taiga (taiga.moe) is the inspiration, but it is anime-only and built around playback detection. Ryuuji is a native macOS app that shares no code with Taiga and covers all three kinds of media.

## What Changes

- New macOS app "Ryuuji" (SwiftUI + SwiftData). There is no code yet, so the first task creates the Xcode project.
- TMDB is the only metadata source, using a personal API key. Anime is an ordinary TMDB TV show or movie, tagged `isAnime` when it has the Animation genre and Japanese origin. Season and episode numbering follow TMDB.
- Tracking is an event log, not counters. Each watch is stored as an event. Progress, Up Next, history, and rewatch counts are derived from events and never stored.
- Six statuses: Plan to Watch, Watching, Caught Up, On Hold, Dropped, Completed. Statuses change automatically when episodes are logged or new episodes air, and can be overridden by hand.
- A metadata refresh runs on launch and daily, so newly aired episodes move Caught Up shows back to Watching.
- MVP views:
  - Cmd-K search and quick-add
  - Up Next home view, with one-click "+" and undo
  - Library grouped and filtered by status
  - Title detail with a season/episode checklist and bulk marking
  - History
- The SwiftData schema follows CloudKit's modeling rules, so an iPhone app with sync can be added later without migrating data.

**Changed from the original brief:**
- **Where-to-watch moved to a follow-up change.** The where-to-watch badges and the "My services" setting are deferred so the MVP stays focused on tracking.
- **`ListEntry` merged into `Title`.** List fields (status, score, notes, addedAt) live directly on `Title`, because a title never exists without its list entry.

**Out of scope:**
- Where-to-watch badges and the "My services" setting (next change)
- Menu bar extra
- Stats
- iPhone app and CloudKit sync
- AniList or any second metadata provider
- Seasonal anime chart
- Playback detection
- Guided rewatch flow, i.e. Up Next for a second viewing

## Capabilities

### New Capabilities

- `title-search`: Searching TMDB and adding a title to the list with a starting status, including the Cmd-K quick-add panel and duplicate prevention.
- `title-metadata`: Caching TMDB metadata locally (seasons, episodes, air dates, show status, anime tag), refreshing it, and working offline from the cache.
- `watch-log`: Recording watch events for episodes and movies, including single logging, bulk marking, unmarking, undo, and derived progress and rewatch counts.
- `list-status`: The six statuses, automatic transitions driven by logging and refresh, and manual override rules.
- `up-next`: The home view of titles with a next episode to watch, plus one-click logging.
- `library`: Browsing all tracked titles grouped and filtered by status, and editing status, score, and notes.
- `title-detail`: The per-title view with a season/episode checklist and bulk marking controls.
- `watch-history`: A chronological view of watch events grouped by date.

### Modified Capabilities

None. This is the first change in the project.

## Impact

- **New Xcode project:** macOS app target plus a unit test target. No existing code is affected.
- **External dependency:** TMDB API v3, read-only. The API key is kept out of source control.
- **Attribution:** TMDB's terms require crediting TMDB in the app.
- **Storage:** a local SwiftData store, which becomes the user's source of truth. There is no data to import.
