# Spec Delta

## Purpose

Shows everything about one tracked title, and is where the user marks and unmarks individual episodes or whole seasons.

## ADDED Requirements

### Requirement: Title header
The detail view SHALL show the title's poster, name, year, kind (with Anime tag), overview, status, score, and notes. For shows it SHALL also show TMDB show status and overall progress.

#### Scenario: Show header
- **WHEN** the user opens a returning show with 20 of 24 aired episodes watched
- **THEN** the header shows its status, "Returning Series", and "20/24"

### Requirement: Season and episode checklist
For shows, the detail view SHALL list each season with its episodes. Each episode row SHALL show its number, name, air date, a watched checkbox, and a rewatch count when above zero. Unaired episodes SHALL be shown with their air date (or "TBA") and their checkbox SHALL be disabled. Specials SHALL appear in a separate section after regular seasons.

#### Scenario: Check an episode
- **WHEN** the user checks an unwatched aired episode
- **THEN** a watch event is logged for it and the checkbox shows as checked

#### Scenario: Uncheck an episode
- **WHEN** the user unchecks a watched episode
- **THEN** the episode is unmarked and its checkbox shows as unchecked

#### Scenario: Unaired episode
- **WHEN** an episode airs next week
- **THEN** its row shows the air date and its checkbox cannot be checked

### Requirement: Season progress and bulk actions
Each season SHALL show its progress (watched over aired episodes) and offer "Mark season watched". The view SHALL also offer "Mark all watched" for the whole show.

#### Scenario: Mark season from detail
- **WHEN** the user chooses "Mark season watched" on season 1
- **THEN** all aired unwatched episodes of season 1 are logged and season 1 shows full progress

### Requirement: Log again from the checklist
Each watched episode SHALL offer a "Log again" action that records a rewatch.

#### Scenario: Log again from context menu
- **WHEN** the user chooses "Log again" on a watched episode
- **THEN** a new event is recorded and the episode's rewatch count increases by one

### Requirement: Movie detail actions
For movies, the detail view SHALL show a "Mark watched" action when the movie is unwatched. When it is watched, it SHALL show the watch count with "Log again" and "Unmark" actions.

#### Scenario: Mark a movie watched from detail
- **WHEN** the user chooses "Mark watched" on an unwatched movie
- **THEN** a watch event is recorded and the movie becomes Completed
