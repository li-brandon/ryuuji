# Where to Watch

Users can see which of their subscribed streaming services carry each title.

## Requirements

### Provider badges

- Provider badges appear in Library rows after the score
- Provider badges appear in title detail header below the overview
- Only providers from "My services" are shown
- If "My services" is empty, all available providers are shown
- Maximum 5 badges displayed
- If more than 5 providers available, show "+N more" indicator
- Badges show provider logo (small in Library, medium in detail)
- If logo unavailable, show provider name as text

### My services setting

- User can select which streaming services they subscribe to
- Setting stored per user (UserDefaults)
- Common services available: Netflix, Amazon Prime Video, Hulu, Disney+, HBO Max, Apple TV+, Paramount+, Peacock, Crunchyroll, etc.
- Services stored as array of TMDB provider IDs
- Exposed in About/Settings window

### Region setting

- User can select their region for provider data
- Defaults to "US"
- Common regions available: US, CA, GB, JP, AU, DE, FR, IT, ES, BR, MX
- Stored per user (UserDefaults)
- Exposed in About/Settings window

### JustWatch attribution

- "Powered by JustWatch" text with link displayed in About/Settings window
- Attribution required by TMDB terms of service
- Link points to JustWatch website

### Provider data caching

- Provider data fetched from TMDB alongside other metadata
- Cached as JSON on each Title
- Refreshed on same schedule as other metadata (launch, daily, on-demand)
- Works offline with cached data
- No provider data shown until first refresh

## Scenarios

### Library badges

Given: A title is in the Library  
And: The title is available on Netflix and Hulu  
And: "My services" includes Netflix  
Then: The Library row shows a Netflix badge  
And: The Hulu badge is not shown

### Detail badges

Given: A title detail is open  
And: The title is available on Netflix, Hulu, Disney+, HBO Max, Apple TV+, and Paramount+  
And: "My services" includes all six services  
Then: Five provider badges are shown  
And: A "+1 more" indicator is shown

### All providers (no filter)

Given: "My services" is empty  
And: A title is available on Netflix and Hulu  
Then: Both Netflix and Hulu badges are shown in Library and detail

### No providers available

Given: A title has no provider data cached  
Or: No providers available in the selected region  
Then: No provider badges are shown  
And: No error or empty state is shown

### Region change

Given: Region is set to "US"  
And: Provider data has been cached  
When: User changes region to "GB"  
Then: Provider data is refreshed for all titles on next metadata refresh  
And: Badges update to show GB providers

### JustWatch attribution

Given: About/Settings window is open  
Then: "Powered by JustWatch" text with link is visible  
And: Link opens JustWatch website when clicked
