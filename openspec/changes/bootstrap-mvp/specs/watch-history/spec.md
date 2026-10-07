# Spec Delta

## Purpose

Shows every recorded watch event in chronological order, so the user can see what they watched and when, and correct mistakes.

## ADDED Requirements

### Requirement: Chronological history
The History view SHALL list all watch events, newest first, grouped by local calendar day. Each row SHALL show the title name, the episode as "S<season>E<episode>" with episode name (or "Movie"), and the time.

#### Scenario: Grouped by day
- **WHEN** the user logged two episodes today and one yesterday
- **THEN** History shows a Today group with two rows above a Yesterday group with one row

### Requirement: Rewatch indicator
History rows for events that are not the first event for that episode or movie SHALL be marked as rewatches.

#### Scenario: Rewatch marked
- **WHEN** the user logs S1E1 of a show a second time
- **THEN** the newer History row for S1E1 is marked as a rewatch

### Requirement: Bulk events grouped
Events recorded by one bulk mark SHALL be shown as a single collapsible History row naming the title and the range of episodes.

#### Scenario: Bulk row
- **WHEN** the user marks season 1 (12 episodes) watched
- **THEN** History shows one row such as "Season 1 · 12 episodes" that expands to the individual episodes

### Requirement: Delete a history event
The user SHALL be able to delete an individual event from History. Deleting an event SHALL apply the same status rules as unmarking when no events remain for that episode or movie.

#### Scenario: Delete a mistaken log
- **WHEN** the user deletes a History event for S1E3, which had only that one event
- **THEN** the event is removed and S1E3 is shown as unwatched

### Requirement: Open title from History
Selecting a History row SHALL open that title's detail view.

#### Scenario: Navigate to title
- **WHEN** the user clicks a History row
- **THEN** that title's detail view opens
