# Spec Delta

## Purpose

Keeps a local copy of TMDB metadata for every tracked title, including seasons, episodes, air dates, show status, and the anime tag, so the app works offline and can detect newly aired episodes.

## ADDED Requirements

### Requirement: Cache title metadata locally
The system SHALL store, for each tracked title: name, original name, overview, poster, release or first-air date, genres, origin countries, original language, and runtime. For shows it SHALL also store TMDB show status and every season and episode with number, name, air date, and TMDB episode id.

#### Scenario: Show metadata cached on add
- **WHEN** a show is added to the list
- **THEN** all of its seasons and episodes, with air dates, are available locally

#### Scenario: Offline browsing
- **WHEN** the device has no network connection
- **THEN** Up Next, Library, title detail, and History still display using cached metadata, and logging still works

### Requirement: Anime tagging
The system SHALL mark a title as anime when its genres include Animation and either its origin countries include Japan or its original language is Japanese. Anime titles otherwise behave exactly like other movies and shows.

#### Scenario: Japanese animated show
- **WHEN** a show with genre Animation and origin country JP is added
- **THEN** the title is tagged Anime

#### Scenario: Western animated show
- **WHEN** a show with genre Animation, origin country US, and original language English is added
- **THEN** the title is not tagged Anime

### Requirement: Aired episodes
The system SHALL treat an episode as aired when it has an air date on or before the current local date. Episodes without an air date SHALL be treated as unaired.

#### Scenario: Future episode
- **WHEN** an episode's air date is tomorrow
- **THEN** it is shown as unaired and is not offered as a next episode

#### Scenario: Missing air date
- **WHEN** an episode has no air date in TMDB
- **THEN** it is treated as unaired

### Requirement: Specials are separate
The system SHALL treat season 0 (specials) as optional. Specials SHALL NOT count toward progress, Up Next, or automatic status transitions, but the user SHALL be able to log them.

#### Scenario: Unwatched specials do not block completion
- **WHEN** every aired regular episode of an ended show is watched but its specials are not
- **THEN** the show is considered fully watched

### Requirement: Automatic metadata refresh
The system SHALL refresh cached metadata on launch and at least once every 24 hours while running. It SHALL refresh every tracked show whose TMDB status is not Ended or Canceled, and shows not refreshed in the last 7 days. A failed refresh SHALL keep the existing cache and retry on the next cycle.

#### Scenario: New episode appears
- **WHEN** a refresh finds a new episode for a returning show
- **THEN** the episode is added to the local cache

#### Scenario: Refresh fails
- **WHEN** TMDB is unreachable during a refresh
- **THEN** cached metadata is unchanged and no error interrupts the user

### Requirement: Manual refresh
The system SHALL let the user refresh a single title's metadata on demand from its detail view.

#### Scenario: Refresh one title
- **WHEN** the user chooses Refresh on a title's detail view
- **THEN** that title's metadata is re-fetched from TMDB and the view updates

### Requirement: Refresh never loses watch history
Refreshing metadata SHALL NOT delete or alter watch events. If TMDB renumbers an episode, its events SHALL stay attached to the same TMDB episode. Events for episodes TMDB no longer lists SHALL be kept and remain visible in History.

#### Scenario: Episode renumbered
- **WHEN** TMDB moves a watched episode from S1E13 to S2E1
- **THEN** after refresh the episode appears as watched at S2E1

#### Scenario: Episode removed from TMDB
- **WHEN** TMDB no longer lists an episode the user logged
- **THEN** the watch event still appears in History

### Requirement: TMDB attribution
The system SHALL show TMDB attribution, using the TMDB logo and the notice "This product uses the TMDB API but is not endorsed or certified by TMDB", in an About or Settings screen.

#### Scenario: Attribution visible
- **WHEN** the user opens the About screen
- **THEN** the TMDB logo and notice are displayed
