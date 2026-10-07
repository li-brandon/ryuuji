# Spec Delta

## Purpose

Lets the user browse and manage every tracked title, grouped and filtered by status, and edit each title's status, score, and notes.

## ADDED Requirements

### Requirement: Browse by status
The Library SHALL let the user view all tracked titles or only the titles in one status. Each status SHALL show the number of titles it contains.

#### Scenario: Filter to one status
- **WHEN** the user selects Plan to Watch in the Library
- **THEN** only titles with status Plan to Watch are shown

#### Scenario: Status counts
- **WHEN** the user has 3 titles in Watching
- **THEN** the Watching entry shows a count of 3

### Requirement: Filter by kind
The Library SHALL let the user narrow titles to All, Shows, Movies, or Anime. This filter SHALL combine with the status filter.

#### Scenario: Anime in Watching
- **WHEN** the user selects Watching and Anime
- **THEN** only anime titles with status Watching are shown

### Requirement: Sort titles
The Library SHALL let the user sort titles by name, date added, or most recent activity.

#### Scenario: Sort by name
- **WHEN** the user sorts by name
- **THEN** titles are listed alphabetically

### Requirement: Library item content
Each Library item SHALL show the poster, name, year, kind (with Anime tag when applicable), and score if set. For shows it SHALL also show progress as watched over aired regular episodes.

#### Scenario: Show progress
- **WHEN** a show has 8 of 12 aired regular episodes watched
- **THEN** its Library item shows "8/12"

### Requirement: Edit list fields
The user SHALL be able to change a title's status, set or clear a score from 1 to 10, and edit free-text notes, from the Library (context menu) or the title detail view.

#### Scenario: Set a score
- **WHEN** the user sets a score of 9 on a title
- **THEN** the title shows score 9 in the Library and detail view

#### Scenario: Change status from context menu
- **WHEN** the user right-clicks a title and chooses On Hold
- **THEN** the title's status becomes On Hold

### Requirement: Remove a title
The user SHALL be able to remove a title from the list after confirming. Removing a title SHALL delete its watch events.

#### Scenario: Remove with confirmation
- **WHEN** the user removes a title and confirms
- **THEN** the title and its events are deleted and no longer appear in Library, Up Next, or History

#### Scenario: Cancel removal
- **WHEN** the user chooses to remove a title and then cancels
- **THEN** nothing is deleted
