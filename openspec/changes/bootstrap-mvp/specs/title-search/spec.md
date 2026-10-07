# Spec Delta

## Purpose

Lets the user find movies and TV shows (including anime) on TMDB and add them to their list quickly, with a starting status, from anywhere in the app.

## ADDED Requirements

### Requirement: Quick-add panel opens from anywhere
The system SHALL open a search panel when the user presses Cmd-K, regardless of which view is active. The panel SHALL focus its search field on open and close on Escape.

#### Scenario: Open with Cmd-K
- **WHEN** the user presses Cmd-K while viewing Up Next, Library, History, or a title detail
- **THEN** the search panel opens with the search field focused

#### Scenario: Dismiss with Escape
- **WHEN** the search panel is open and the user presses Escape
- **THEN** the panel closes without adding anything

### Requirement: Search TMDB movies and TV shows
The system SHALL search TMDB for movies and TV shows matching the typed query and list results with name, year, type (Movie or Show), poster, and an Anime tag when applicable. People results SHALL be excluded.

#### Scenario: Mixed results
- **WHEN** the user types "Frieren"
- **THEN** matching shows and movies appear with their year, type, and poster, and anime results show an Anime tag

#### Scenario: Search is debounced
- **WHEN** the user types several characters in quick succession
- **THEN** the system issues a search only after typing pauses, not once per keystroke

#### Scenario: Search fails
- **WHEN** TMDB is unreachable or returns an error
- **THEN** the panel shows an error message and nothing is added to the list

#### Scenario: No API key configured
- **WHEN** the app has no TMDB API key configured and the user searches
- **THEN** the panel explains that a TMDB API key is required instead of showing results

### Requirement: Add a title with a starting status
The system SHALL add the selected result to the list with status Plan to Watch by default, and SHALL let the user pick any of the six statuses at add time. Adding SHALL fetch and cache the title's full metadata.

#### Scenario: Default add
- **WHEN** the user selects a result and presses Return
- **THEN** the title is added with status Plan to Watch and its metadata (including seasons and episodes for shows) is cached

#### Scenario: Add with a chosen status
- **WHEN** the user picks Watching from the status picker for a result and confirms
- **THEN** the title is added with status Watching

#### Scenario: Add movie as Completed
- **WHEN** the user adds a movie with status Completed
- **THEN** the title is added with status Completed and a watch event for the movie is recorded at the current time

### Requirement: No duplicate titles
The system SHALL keep at most one list entry per TMDB title (identified by TMDB id and type). Results already in the list SHALL be marked as such.

#### Scenario: Result already in list
- **WHEN** a search result is already in the user's list
- **THEN** the result shows an "In list" marker with its current status

#### Scenario: Selecting an existing title
- **WHEN** the user selects a result that is already in the list
- **THEN** no new entry is created and the app opens that title's detail view
