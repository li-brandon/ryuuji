/// What caused a status recomputation.
nonisolated enum StatusTrigger: Sendable {
    /// A single log or bulk mark.
    case log
    /// An unmark or a deleted history event.
    case unmark
    /// A metadata refresh.
    case refresh
}

/// The automatic status rules from the list-status spec.
nonisolated enum StatusEngine {
    static func status(
        after trigger: StatusTrigger,
        current: ListStatus,
        kind: Kind,
        progress: Progress,
        showStatus: ShowStatus
    ) -> ListStatus {
        switch trigger {
        case .log:
            return fromProgress(current: current, kind: kind, progress: progress, showStatus: showStatus)

        case .refresh:
            guard current == .watching || current == .caughtUp else { return current }
            return fromProgress(current: current, kind: kind, progress: progress, showStatus: showStatus)

        case .unmark:
            switch kind {
            case .movie:
                return current == .completed && progress.eventCount == 0 ? .planToWatch : current
            case .show:
                let reopened = (current == .caughtUp || current == .completed) && progress.remaining > 0
                return reopened ? .watching : current
            }
        }
    }

    /// The status implied by progress alone.
    private static func fromProgress(
        current: ListStatus,
        kind: Kind,
        progress: Progress,
        showStatus: ShowStatus
    ) -> ListStatus {
        switch kind {
        case .movie:
            return progress.eventCount > 0 ? .completed : current
        case .show:
            let allAiredWatched = progress.hasAiredRegular && progress.remaining == 0
            guard allAiredWatched else { return .watching }
            return showStatus.isFinished ? .completed : .caughtUp
        }
    }
}
