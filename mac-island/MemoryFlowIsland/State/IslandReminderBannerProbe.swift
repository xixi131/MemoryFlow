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
        try validatePolicy()
        return "reminder-banner-probe: PASS; sequence=compactCollapsed->reminderBanner->compactCollapsed->activityCollapsed; kinds=review+todo; recovery=expandedCollapseRecovery; dedup=intentIgnored; policy=timeReached+hasTasksToday+dayRearm+nothingPending"
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

    /// Exercises `IslandReminderDuePolicy.evaluate` directly with an injected
    /// fixed clock so the trigger logic can be asserted headlessly, without
    /// waiting on real time or the reducer sequence above.
    private static func validatePolicy() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        func date(day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
            var components = DateComponents()
            components.timeZone = calendar.timeZone
            components.year = 2026
            components.month = 8
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = second
            guard let resolved = calendar.date(from: components) else {
                preconditionFailure("policy probe: failed to construct fixed clock date")
            }
            return resolved
        }

        func makeState(pendingReviews: Int, dueToday: Int, overdueTasks: Int, reminderTime: String?) -> IslandDomainState {
            var state = IslandDomainState.loggedInReviewCompact
            state.reviewSnapshot = ReviewSnapshot(
                dto: WidgetSummaryDTO(
                    totalPendingReviews: pendingReviews,
                    totalCompletedToday: 0,
                    reminderTime: reminderTime,
                    subjects: []
                )
            )
            state.todoSnapshot = TodoSnapshot(
                stats: TodoStatsDTO(pendingTasks: dueToday + overdueTasks, dueToday: dueToday, overdueTasks: overdueTasks),
                tasks: []
            )
            return state
        }

        let day0AtReminder = date(day: 4, hour: 20, minute: 0)
        let day0TenSecondsLater = date(day: 4, hour: 20, minute: 0, second: 10)
        let day1AtReminder = date(day: 5, hour: 20, minute: 0)

        // 1) Review: time-reached key fires once, then the separate
        //    "has pending reviews today" key fires as a second event, then
        //    both dedup for the remainder of the day.
        var reviewState = makeState(pendingReviews: 3, dueToday: 0, overdueTasks: 0, reminderTime: "20:00")
        guard let reviewTimeEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: reviewState, calendar: calendar),
              reviewTimeEvent.kind == .review,
              reviewTimeEvent.key == "review-time-2026-08-04-20:00" else {
            throw IslandReminderBannerProbeError.failed("policy: review-time key did not fire when the reminder time was reached")
        }
        reviewState.firedReminderKeys.append(reviewTimeEvent.key)

        guard let reviewTodayEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: reviewState, calendar: calendar),
              reviewTodayEvent.kind == .review,
              reviewTodayEvent.key == "review-today-2026-08-04" else {
            throw IslandReminderBannerProbeError.failed("policy: review-today key did not fire as a separate second review event")
        }
        reviewState.firedReminderKeys.append(reviewTodayEvent.key)

        guard IslandReminderDuePolicy.evaluate(now: day0TenSecondsLater, state: reviewState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: a review key refired later the same day after both had already fired")
        }

        // 2) Todo: dueToday + overdueTasks drive the same pair of keys.
        var todoState = makeState(pendingReviews: 0, dueToday: 2, overdueTasks: 1, reminderTime: "20:00")
        guard let todoTimeEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: todoState, calendar: calendar),
              todoTimeEvent.kind == .todo,
              todoTimeEvent.key == "todo-time-2026-08-04-20:00" else {
            throw IslandReminderBannerProbeError.failed("policy: todo-time key did not fire when the reminder time was reached")
        }
        todoState.firedReminderKeys.append(todoTimeEvent.key)

        guard let todoTodayEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: todoState, calendar: calendar),
              todoTodayEvent.kind == .todo,
              todoTodayEvent.key == "todo-today-2026-08-04" else {
            throw IslandReminderBannerProbeError.failed("policy: todo-today key did not fire as a separate second todo event")
        }
        todoState.firedReminderKeys.append(todoTodayEvent.key)

        guard IslandReminderDuePolicy.evaluate(now: day0TenSecondsLater, state: todoState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: a todo key refired later the same day after both had already fired")
        }

        // 3) Advancing the clock to the next day re-arms both kinds.
        var combinedState = reviewState
        combinedState.todoSnapshot = todoState.todoSnapshot
        combinedState.firedReminderKeys = reviewState.firedReminderKeys + todoState.firedReminderKeys

        guard let rearmedReview = IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: combinedState, calendar: calendar),
              rearmedReview.kind == .review,
              rearmedReview.key == "review-time-2026-08-05-20:00" else {
            throw IslandReminderBannerProbeError.failed("policy: review key did not re-arm on the next day")
        }
        combinedState.firedReminderKeys.append(rearmedReview.key)

        guard let rearmedTodo = IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: combinedState, calendar: calendar),
              rearmedTodo.kind == .todo,
              rearmedTodo.key == "todo-time-2026-08-05-20:00" else {
            throw IslandReminderBannerProbeError.failed("policy: todo key did not re-arm on the next day")
        }

        // 4) Nothing pending means nothing fires, regardless of the clock.
        let emptyState = makeState(pendingReviews: 0, dueToday: 0, overdueTasks: 0, reminderTime: "20:00")
        guard IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: emptyState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: an event fired despite zero pending reviews and zero due/overdue todos")
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
