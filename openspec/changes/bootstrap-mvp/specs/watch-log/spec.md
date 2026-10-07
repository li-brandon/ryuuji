# Spec Delta

## Purpose

Records what the user watched as an append-only log of watch events, and derives progress and rewatch counts from that log instead of storing counters.

## ADDED Requirements

### Requirement: Watch events are the source of truth
The system SHALL record each watch as an event holding the title, a timestamp, and (for shows) the season and episode. Progress, next episode, history, and rewatch counts SHALL be derived from events and SHALL NOT be stored separately.

#### Scenario: Progress derived from events
- **WHEN** a show has events for S1E1, S1E2, and S1E2 again
- **THEN** its progress shows 2 distinct episodes watched

### Requirement: Log a single episode
The system SHALL let the user log one episode as watched at the current time.

#### Scenario: Log an episode
- **WHEN** the user logs S1E3 of a show
- **THEN** a watch event for S1E3 is recorded at the current time

### Requirement: Log a movie
The system SHALL let the user log a movie as watched at the current time. Movie events have no season or episode.

#### Scenario: Log a movie
- **WHEN** the user marks a movie watched
- **THEN** a watch event without season or episode is recorded for the movie

### Requirement: Rewatches are repeated events
The system SHALL allow logging an episode or movie that is already watched. Doing so SHALL add another event. The rewatch count of an episode or movie SHALL be its number of events minus one.

#### Scenario: Log again
- **WHEN** the user chooses "Log again" on an already-watched episode
- **THEN** a second event is recorded and the episode shows 1 rewatch

### Requirement: Bulk marking
The system SHALL let the user mark a whole season, or all episodes of a show, as watched in one action. Bulk marking SHALL record one event per aired, not-yet-watched episode in scope, all with the same timestamp. Unaired and already-watched episodes SHALL be skipped.

#### Scenario: Mark season watched
- **WHEN** season 2 has 10 aired episodes, 3 already watched, and 2 unaired, and the user marks season 2 watched
- **THEN** 7 events are recorded with the same timestamp

#### Scenario: Mark all watched skips specials
- **WHEN** the user marks all episodes of a show watched
- **THEN** events are recorded for aired unwatched regular episodes only, not for season 0

### Requirement: Unmark an episode
The system SHALL let the user unmark a watched episode or movie, which removes all of its watch events.

#### Scenario: Unmark
- **WHEN** the user unchecks S1E3, which has 2 events
- **THEN** both events are removed and S1E3 is shown as unwatched

### Requirement: Undo logging
The system SHALL let the user undo the most recent logging action (single log, bulk mark, or unmark) with Cmd-Z. Undo SHALL restore the previous events and the previous status. A bulk mark SHALL undo as one step.

#### Scenario: Undo a mis-click
- **WHEN** the user logs an episode from Up Next and then presses Cmd-Z
- **THEN** the event is removed and the title's status returns to what it was before

#### Scenario: Undo a bulk mark
- **WHEN** the user marks a season watched and then presses Cmd-Z
- **THEN** all events from that bulk mark are removed
