# Spec Delta

## Purpose

Provides the home view, showing what to watch next for every show in progress, and lets the user log the next episode with a single click.

## ADDED Requirements

### Requirement: Up Next is the home view
The app SHALL open to Up Next. Up Next SHALL list every show with status Watching that has a next episode. The next episode is the first aired, unwatched regular episode in season/episode order.

#### Scenario: Show with next episode
- **WHEN** a Watching show has watched S1E1 to S1E4 and S1E5 has aired
- **THEN** Up Next lists the show with next episode S1E5

#### Scenario: Gap in progress
- **WHEN** a Watching show has S1E1 and S1E3 watched but not S1E2
- **THEN** the next episode is S1E2

#### Scenario: Excluded titles
- **WHEN** a show is Caught Up, On Hold, Dropped, Plan to Watch, or Completed
- **THEN** it does not appear in Up Next

### Requirement: Up Next row content
Each Up Next row SHALL show the poster, the title name, the next episode as "S<season>E<episode>" with the episode name, the number of aired episodes remaining, and a "+" button.

#### Scenario: Row details
- **WHEN** a show's next episode is S2E5 "The Return" and 6 aired episodes remain
- **THEN** the row shows "S2E5 · The Return" and "6 left"

### Requirement: One-click logging
Clicking "+" on a row SHALL log that row's next episode immediately, with no confirmation. The row SHALL then advance to the new next episode. If no next episode remains, the row SHALL leave Up Next as the status changes.

#### Scenario: Advance after logging
- **WHEN** the user clicks "+" on a row whose next episode is S1E5
- **THEN** S1E5 is logged and the row now shows S1E6

#### Scenario: Caught up after logging
- **WHEN** the user clicks "+" on the last aired episode of a returning show
- **THEN** the show becomes Caught Up and leaves Up Next

### Requirement: Up Next ordering
Up Next SHALL be sorted by most recent watch activity first, falling back to the date added for shows with no events.

#### Scenario: Recently watched first
- **WHEN** show A was last logged yesterday and show B an hour ago
- **THEN** show B is listed above show A

### Requirement: Open title from Up Next
Selecting a row (anywhere except "+") SHALL open that title's detail view.

#### Scenario: Open detail
- **WHEN** the user clicks a row's poster or name
- **THEN** the title's detail view opens

### Requirement: Empty state
When Up Next is empty, the view SHALL say so and point the user to Cmd-K to add titles.

#### Scenario: Nothing in progress
- **WHEN** no show is Watching with a next episode
- **THEN** Up Next shows an empty state mentioning Cmd-K
