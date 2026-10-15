# Design

## Overview

Add where-to-watch functionality by fetching watch provider data from TMDB, caching it on titles, and displaying badges filtered to the user's subscribed services. The feature requires JustWatch attribution per TMDB's terms.

## Key Decisions

**D1. Provider data is cached per title**
- Watch provider data is fetched alongside other metadata and stored on each `Title`
- Refreshed on the same schedule as other metadata (launch, daily, on-demand)
- Stored as JSON to allow easy schema evolution

**D2. "My services" and region are user preferences**
- Stored in UserDefaults as simple arrays/strings
- Default region is "US"
- Default services list is empty (show all available providers until configured)
- Settings exposed in the About/Settings window

**D3. Provider badges shown in Library and detail**
- Library rows show small provider logos after the score
- Title detail header shows larger provider logos
- Only services in "My services" are shown (or all if list is empty)
- Maximum 5 badges displayed with "+N more" indicator

**D4. JustWatch attribution**
- Attribution text "Powered by JustWatch" with link displayed:
  - In About/Settings window below TMDB attribution
  - Possibly in title detail (to be confirmed with user)
- Attribution is required by TMDB terms for using watch provider data

## Data Model

Extend `Title` with:
```swift
var providerDataJSON: Data = Data() // Cached WatchProviderData as JSON
```

New types:
```swift
struct WatchProviderData: Codable {
    var region: String
    var providers: [ProviderInfo]
    var link: String? // JustWatch link
}

struct ProviderInfo: Codable, Identifiable {
    var id: Int // TMDB provider id
    var name: String
    var logoPath: String?
    var displayPriority: Int
}
```

User preferences (UserDefaults):
```swift
@AppStorage("myServices") private var myServicesJSON: Data = Data()
@AppStorage("providerRegion") private var region: String = "US"
```

## TMDB Integration

Extend `TMDBClient` protocol:
```swift
func watchProviders(for key: TitleKey, region: String) async throws -> WatchProviderData
```

TMDB endpoint:
- Movies: `GET /movie/{movie_id}/watch/providers`
- TV Shows: `GET /tv/{tv_id}/watch/providers`

Response structure (extract region-specific data):
```json
{
  "results": {
    "US": {
      "link": "https://www.justwatch.com/...",
      "flatrate": [
        {"logo_path": "/...", "provider_id": 8, "provider_name": "Netflix", "display_priority": 0}
      ]
    }
  }
}
```

Only use `flatrate` (subscription streaming). Ignore `buy`, `rent`, and `ads`.

## UI Components

**ProviderBadgeView**
- Displays provider logo from TMDB
- Small size (20x20) for Library rows
- Medium size (32x32) for title detail
- Falls back to provider name text if logo unavailable

**MyServicesSettingView**
- Multi-select picker of common streaming services
- Stored as array of provider IDs
- Displayed in About/Settings window

**RegionSettingView**
- Picker of common regions (US, CA, GB, JP, etc.)
- Displayed in About/Settings window

## Acceptance Criteria

- Provider badges appear in Library rows and title detail header
- Only services from "My services" are shown (or all if empty)
- Maximum 5 badges with "+N more" indicator
- About/Settings window shows "My services" and region settings
- JustWatch attribution displayed per TMDB terms
- Provider data refreshed on same schedule as other metadata
- Works offline with cached data
