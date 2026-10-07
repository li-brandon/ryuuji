# Spec Delta

## Purpose

Defines the six list statuses a tracked title can have, when the system changes a status automatically, and how manual changes by the user interact with those automatic transitions.

## ADDED Requirements

### Requirement: Six statuses
Every tracked title SHALL have exactly one status: Plan to Watch, Watching, Caught Up, On Hold, Dropped, or Completed. Caught Up means every aired regular episode is watched and the show is still airing.

#### Scenario: Status always present
- **WHEN** a title is added to the list
- **THEN** it has exactly one of the six statuses

### Requirement: Status recomputed when logging
After any logging action (single log or bulk mark), the system SHALL set the status from progress, whatever the current status. A movie becomes Completed. A show with all aired regular episodes watched becomes Completed if TMDB lists it as Ended or Canceled, otherwise Caught Up. Any other show becomes Watching.

#### Scenario: First episode logged
- **WHEN** a show in Plan to Watch has its first episode logged
- **THEN** its status becomes Watching

#### Scenario: Logging reactivates a paused show
- **WHEN** a show in On Hold or Dropped has an episode logged and unwatched aired episodes remain
- **THEN** its status becomes Watching

#### Scenario: Caught up on a returning show
- **WHEN** the last aired episode of a returning show is logged
- **THEN** its status becomes Caught Up

#### Scenario: Finished an ended show
- **WHEN** the last episode of an ended show is logged
- **THEN** its status becomes Completed

#### Scenario: Movie watched
- **WHEN** a movie is logged as watched
- **THEN** its status becomes Completed

#### Scenario: Rewatching a completed show
- **WHEN** an episode of a Completed, ended show is logged again
- **THEN** its status stays Completed

### Requirement: Status updated after refresh
After a metadata refresh, the system SHALL recompute status only for titles that are Watching or Caught Up, using the logging rules. Titles in Plan to Watch, On Hold, Dropped, or Completed SHALL NOT change status on refresh.

#### Scenario: New episode airs
- **WHEN** a show in Caught Up gets a newly aired episode on refresh
- **THEN** its status becomes Watching

#### Scenario: Show ends
- **WHEN** a Caught Up show is marked Ended by TMDB on refresh and all its episodes are watched
- **THEN** its status becomes Completed

#### Scenario: Paused shows untouched
- **WHEN** a show in On Hold gets a newly aired episode on refresh
- **THEN** its status stays On Hold

### Requirement: Status updated after unmarking
After an unmark, the system SHALL set a title that is Caught Up or Completed to Watching if it now has an aired, unwatched regular episode. A movie that is Completed and has no events left SHALL become Plan to Watch. Other statuses SHALL NOT change on unmark.

#### Scenario: Unmark from Caught Up
- **WHEN** the user unmarks an episode of a Caught Up show
- **THEN** its status becomes Watching

### Requirement: Manual override
The user SHALL be able to set any status on any title at any time. A manual status SHALL persist until the next logging action, unmark, or refresh rule changes it.

#### Scenario: Manually drop a show
- **WHEN** the user sets a Watching show to Dropped
- **THEN** its status is Dropped and it no longer appears in Up Next

#### Scenario: Manual Completed survives refresh
- **WHEN** the user sets a show to Completed and a refresh finds a new episode
- **THEN** its status stays Completed
