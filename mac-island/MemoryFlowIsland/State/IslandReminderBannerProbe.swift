import Foundation

enum IslandReminderBannerProbeError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): return message
        }
    }
}

/// Drives the full compact -> banner -> collapse -> activity sequence through
/// `IslandPresentationReducer`, reusing the shared `expandedCollapseRecovery`
/// two-phase animation identifier so the banner's collapse matches the activity
/// expand-then-collapse motion exactly.
enum IslandReminderBannerProbe {
    static func run() throws -> String {
        try validateSequence(
            kind: .review,
            baseState: reviewBaseState(),
            key: "k1"
        )
        try validateSequence(
            kind: .todo,
            baseState: todoBaseState(),
            key: "k2"
        )
        return "reminder-banner-probe: PASS; sequence=compactCollapsed->reminderBanner->compactCollapsed->activityCollapsed; kinds=review+todo; recovery=expandedCollapseRecovery; dedup=intentIgnored"
    }

    private static func validateSequence(
        kind: IslandReminderKind,
        baseState: IslandDomainState,
        key: String
    ) throws {
        let initialDerived = IslandDerivedState.derive(from: baseState)
        guard initialDerived.visualState == .compactCollapsed else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) base state was not compactCollapsed: \(initialDerived.visualState)"
            )
        }

        let due = IslandPresentationReducer.reduce(
            current: baseState,
            intent: .reminderBannerDue(kind: kind, key: key)
        )
        guard due.reason == .reminderBannerPresented,
              due.derivedState.visualState == .reminderBanner,
              due.derivedState.previewContent.kind == .reminderBanner,
              due.derivedState.previewContent.title == kind.message,
              due.state.reminderBanner?.kind == kind,
              due.state.presentationState == .expanded,
              due.state.forceCompactMode == false,
              due.state.appDisplayMode == kind.displayMode,
              due.state.isReminderActive == (kind == .review),
              due.state.firedReminderKeys.contains(key) else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) reminderBannerDue did not open the banner: reason=\(due.reason) visualState=\(due.derivedState.visualState)"
            )
        }

        let dismissed = IslandPresentationReducer.reduce(
            current: due.state,
            intent: .reminderBannerDismissed
        )
        guard dismissed.reason == .reminderBannerDismissed,
              dismissed.derivedState.visualState == .compactCollapsed,
              dismissed.state.reminderBanner == nil,
              dismissed.state.presentationLockState.transitionID == "expandedCollapseRecovery" else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) reminderBannerDismissed did not stage the shared collapse recovery: reason=\(dismissed.reason) visualState=\(dismissed.derivedState.visualState)"
            )
        }

        let completed = IslandPresentationReducer.reduce(
            current: dismissed.state,
            intent: .transitionComplete("expandedCollapseRecovery")
        )
        guard completed.derivedState.visualState == .activityCollapsed,
              completed.state.presentationLockState.transitionID == nil else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) expandedCollapseRecovery did not resolve to activityCollapsed: \(completed.derivedState.visualState)"
            )
        }

        switch kind {
        case .review:
            guard completed.derivedState.showReviewActivity else {
                throw IslandReminderBannerProbeError.failed(
                    "review sequence did not end with showReviewActivity == true"
                )
            }
        case .todo:
            guard completed.derivedState.showTodoActivity,
                  completed.state.appDisplayMode == .todo else {
                throw IslandReminderBannerProbeError.failed(
                    "todo sequence did not end with showTodoActivity == true and appDisplayMode == .todo"
                )
            }
        }

        let repeated = IslandPresentationReducer.reduce(
            current: completed.state,
            intent: .reminderBannerDue(kind: kind, key: key)
        )
        guard repeated.reason == .intentIgnored else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) repeated reminderBannerDue with key \(key) did not return .intentIgnored: \(repeated.reason)"
            )
        }
    }

    private static func reviewBaseState() -> IslandDomainState {
        var state = IslandDomainState.loggedInReviewCompact
        state.reviewSnapshot = ReviewSnapshot(
            dto: WidgetSummaryDTO(
                totalPendingReviews: 3,
                totalCompletedToday: 1,
                reminderTime: nil,
                subjects: []
            )
        )
        return state
    }

    private static func todoBaseState() -> IslandDomainState {
        var state = IslandDomainState.loggedInTodoCompact
        state.todoSnapshot = TodoSnapshot(
            stats: TodoStatsDTO(pendingTasks: 2, dueToday: 1, overdueTasks: 0),
            tasks: [
                TodoTaskDTO(
                    id: 1,
                    title: "Reminder banner probe todo",
                    status: "todo",
                    priority: "normal",
                    dueDate: nil,
                    dueTime: nil,
                    overdue: false,
                    dueToday: true
                )
            ]
        )
        return state
    }
}
