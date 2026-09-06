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
        try validateAutoDismissTiming()
        try validateExternalAgentNotice()
        try validateAgentCompletionLogEvents()
        try validateToonFlowAgentModes()
        return "reminder-banner-probe: PASS; sequence=compactCollapsed->reminderBanner->compactCollapsed->activityCollapsed; kinds=review+todo; recovery=expandedCollapseRecovery; dedup=intentIgnored; policy=onceDailyPerKind+timeGated+dayRearm+nothingPending; autoDismissHold=2.0s+expandedCollapseRecovery; externalAgentNotice=present+tapDismiss; agentLogs=claudeEndTurn+claudeApprovalWait+claudeUserQuestionWait+chatGPTTaskComplete+chatGPTUserInputWait; toonFlow=allAgentModes+agentAnswersOnly; reminderActiveNeverSet=true"
    }

    private static func validateToonFlowAgentModes() throws {
        guard ToonFlowDatabaseWatcher.agentName(for: "123:scriptAgent") == "剧本 Agent",
              ToonFlowDatabaseWatcher.agentName(for: "123:productionAgent:1") == "生产 Agent",
              ToonFlowDatabaseWatcher.agentName(for: "123:videoPlanningAgent") == "videoPlanningAgent",
              ToonFlowDatabaseWatcher.agentName(for: "not-an-agent") == nil else {
            throw IslandReminderBannerProbeError.failed("ToonFlow agent modes were not recognized")
        }
    }

    private static func validateExternalAgentNotice() throws {
        let notice = IslandExternalAgentNotice(
            source: .toonFlow,
            sourceTitle: "ToonFlow",
            title: "《项目》剧本 Agent 已完成",
            detail: "assistant:decision"
        )
        let presented = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .externalAgentNoticePresented(notice)
        )
        guard presented.reason == .externalAgentNoticePresented,
              presented.derivedState.visualState == .expandedApp,
              presented.derivedState.previewContent.kind == .externalAgentNotification,
              presented.derivedState.previewContent.title == "《项目》剧本 Agent 已完成",
              presented.derivedState.previewContent.externalAgentStatusTitle == "《项目》剧本 Agent 已完成",
              presented.state.presentationState == .expanded else {
            throw IslandReminderBannerProbeError.failed("external agent notice did not open its dedicated notification state")
        }

        let waitingNotice = IslandExternalAgentNotice(
            source: .codex,
            sourceTitle: "ChatGPT",
            title: "ChatGPT 正在等待你的操作",
            detail: "等待你的选择或输入"
        )
        let waiting = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .externalAgentNoticePresented(waitingNotice)
        )
        guard waiting.derivedState.previewContent.title == "ChatGPT 正在等待你的操作",
              waiting.derivedState.previewContent.eyebrow == "ChatGPT",
              waiting.derivedState.previewContent.externalAgentStatusTitle == "正在等待你的操作",
              waiting.derivedState.previewContent.externalAgentIsWaitingForAction else {
            throw IslandReminderBannerProbeError.failed("external agent waiting notice lost its action-required title")
        }

        let dismissed = IslandPresentationReducer.reduce(current: presented.state, intent: .tap)
        guard dismissed.reason == .externalAgentNoticeDismissed,
              dismissed.derivedState.visualState == .compactCollapsed,
              dismissed.state.externalAgentNotice == nil else {
            throw IslandReminderBannerProbeError.failed("external agent notice tap did not restore the normal compact island")
        }
    }

    private static func validateAgentCompletionLogEvents() throws {
        let claudeCompletion = Data("""
        {"type":"assistant","isSidechain":false,"message":{"stop_reason":"end_turn"}}
        """.utf8)
        let claudeToolUse = Data("""
        {"type":"assistant","isSidechain":false,"message":{"stop_reason":"tool_use"}}
        """.utf8)
        let codexCompletion = Data("""
        {"type":"event_msg","payload":{"type":"task_complete"}}
        """.utf8)
        let claudePermissionRequest = Data("""
        {"type":"assistant","isSidechain":false,"message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"rm -f /tmp/probe"}}]}}
        """.utf8)
        let claudeUserQuestion = Data("""
        {"type":"assistant","isSidechain":false,"message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"toolu_ask","name":"AskUserQuestion","input":{"questions":[{"question":"Pick one"}]}}]}}
        """.utf8)
        let claudeToolResult = Data("""
        {"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_1"}]}}
        """.utf8)
        let claudeReadOnlyToolUse = Data("""
        {"type":"assistant","isSidechain":false,"message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"toolu_2","name":"Bash","input":{"command":"rg TODO README.md"}}]}}
        """.utf8)
        let codexUserInput = Data("""
        {"type":"response_item","payload":{"type":"function_call","name":"request_user_input"}}
        """.utf8)

        guard AgentCompletionLogWatcher.completionEvent(from: claudeCompletion, source: .claudeCode)?.source == .claudeCode,
              AgentCompletionLogWatcher.completionEvent(from: claudeToolUse, source: .claudeCode) == nil,
              AgentCompletionLogWatcher.completionEvent(from: codexCompletion, source: .codex)?.source == .codex,
              AgentCompletionLogWatcher.claudeToolUseIDs(from: claudePermissionRequest) == ["toolu_1"],
              AgentCompletionLogWatcher.claudePermissionSensitiveToolUseIDs(from: claudePermissionRequest) == ["toolu_1"],
              AgentCompletionLogWatcher.claudePermissionSensitiveToolUseIDs(from: claudeReadOnlyToolUse).isEmpty,
              AgentCompletionLogWatcher.claudeResolvedToolUseIDs(from: claudeToolResult) == ["toolu_1"],
              AgentCompletionLogWatcher.waitingForUserEvent(from: claudeUserQuestion, source: .claudeCode)?.title == "Claude Code 正在等待你的操作",
              AgentCompletionLogWatcher.waitingForUserEvent(from: codexUserInput, source: .codex)?.source == .codex else {
            throw IslandReminderBannerProbeError.failed("agent completion and user-input log parsing did not distinguish terminal, auto-resolved, and waiting events")
        }
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
              due.state.isReminderActive == false,
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
              completed.state.presentationLockState.transitionID == nil,
              completed.state.isReminderActive == false else {
            throw IslandReminderBannerProbeError.failed(
                "\(kind.rawValue) expandedCollapseRecovery did not resolve to activityCollapsed: \(completed.derivedState.visualState), isReminderActive=\(completed.state.isReminderActive)"
            )
        }

        switch kind {
        case .review:
            guard completed.derivedState.showReviewActivity,
                  completed.derivedState.previewContent.kind == .reviewActivity,
                  completed.derivedState.previewContent.tone == .review else {
                throw IslandReminderBannerProbeError.failed(
                    "review sequence did not land on the plain reviewActivity/.review tone (got kind=\(completed.derivedState.previewContent.kind) tone=\(completed.derivedState.previewContent.tone)) — must render identically to the todo case, not the old reminderActivity/.reminder mock content"
                )
            }
        case .todo:
            guard completed.derivedState.showTodoActivity,
                  completed.state.appDisplayMode == .todo,
                  completed.derivedState.previewContent.kind == .todoActivity,
                  completed.derivedState.previewContent.tone == .todo else {
                throw IslandReminderBannerProbeError.failed(
                    "todo sequence did not end with showTodoActivity == true, appDisplayMode == .todo, and plain todoActivity/.todo content (got kind=\(completed.derivedState.previewContent.kind) tone=\(completed.derivedState.previewContent.tone))"
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

        let day0BeforeReminder = date(day: 4, hour: 19, minute: 59)
        let day0AtReminder = date(day: 4, hour: 20, minute: 0)
        let day0TenSecondsLater = date(day: 4, hour: 20, minute: 0, second: 10)
        let day0MuchLater = date(day: 4, hour: 23, minute: 0)
        let day1AtReminder = date(day: 5, hour: 20, minute: 0)

        // 1) Review: with a reminder time configured, nothing fires before it
        //    is reached, no matter how many items are pending.
        let reviewStateBeforeTime = makeState(pendingReviews: 3, dueToday: 0, overdueTasks: 0, reminderTime: "20:00")
        guard IslandReminderDuePolicy.evaluate(now: day0BeforeReminder, state: reviewStateBeforeTime, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: review fired before its configured reminder time was reached")
        }

        // 2) Once reached, EXACTLY ONE event fires for review — no matter how
        //    many pending items — and it never fires again the same day, even
        //    hours later with the same (or a larger) pending count.
        var reviewState = reviewStateBeforeTime
        guard let reviewEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: reviewState, calendar: calendar),
              reviewEvent.kind == .review,
              reviewEvent.key == "review-2026-08-04" else {
            throw IslandReminderBannerProbeError.failed("policy: review did not fire exactly once when the reminder time was reached")
        }
        reviewState.firedReminderKeys.append(reviewEvent.key)

        guard IslandReminderDuePolicy.evaluate(now: day0TenSecondsLater, state: reviewState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: review refired 10s later the same day (should be deduped for the whole day)")
        }
        reviewState.reviewSnapshot = ReviewSnapshot(
            dto: WidgetSummaryDTO(totalPendingReviews: 9, totalCompletedToday: 0, reminderTime: "20:00", subjects: [])
        )
        guard IslandReminderDuePolicy.evaluate(now: day0MuchLater, state: reviewState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: review refired later the same day even though the pending count grew — must still be capped at once per day")
        }

        // 3) Todo: dueToday + overdueTasks drive the same single-fire-per-day
        //    key, independently of review.
        var todoState = makeState(pendingReviews: 0, dueToday: 2, overdueTasks: 1, reminderTime: "20:00")
        guard let todoEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: todoState, calendar: calendar),
              todoEvent.kind == .todo,
              todoEvent.key == "todo-2026-08-04" else {
            throw IslandReminderBannerProbeError.failed("policy: todo did not fire exactly once when the reminder time was reached")
        }
        todoState.firedReminderKeys.append(todoEvent.key)

        guard IslandReminderDuePolicy.evaluate(now: day0TenSecondsLater, state: todoState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: todo refired 10s later the same day (should be deduped for the whole day)")
        }

        // 4) No reminder time configured: fires immediately as soon as
        //    something is pending, still capped at once per day.
        var noTimeState = makeState(pendingReviews: 1, dueToday: 0, overdueTasks: 0, reminderTime: nil)
        guard let noTimeEvent = IslandReminderDuePolicy.evaluate(now: day0BeforeReminder, state: noTimeState, calendar: calendar),
              noTimeEvent.kind == .review,
              noTimeEvent.key == "review-2026-08-04" else {
            throw IslandReminderBannerProbeError.failed("policy: review with no configured reminder time did not fire immediately once something was pending")
        }
        noTimeState.firedReminderKeys.append(noTimeEvent.key)
        guard IslandReminderDuePolicy.evaluate(now: day0MuchLater, state: noTimeState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: no-configured-time review refired later the same day")
        }

        // 5) Advancing the clock to the next day re-arms both kinds.
        var combinedState = reviewState
        combinedState.todoSnapshot = todoState.todoSnapshot
        combinedState.firedReminderKeys = reviewState.firedReminderKeys + todoState.firedReminderKeys

        guard let rearmedReview = IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: combinedState, calendar: calendar),
              rearmedReview.kind == .review,
              rearmedReview.key == "review-2026-08-05" else {
            throw IslandReminderBannerProbeError.failed("policy: review key did not re-arm on the next day")
        }
        combinedState.firedReminderKeys.append(rearmedReview.key)

        guard let rearmedTodo = IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: combinedState, calendar: calendar),
              rearmedTodo.kind == .todo,
              rearmedTodo.key == "todo-2026-08-05" else {
            throw IslandReminderBannerProbeError.failed("policy: todo key did not re-arm on the next day")
        }

        // 6) Nothing pending means nothing fires, regardless of the clock.
        let emptyState = makeState(pendingReviews: 0, dueToday: 0, overdueTasks: 0, reminderTime: "20:00")
        guard IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: emptyState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: an event fired despite zero pending reviews and zero due/overdue todos")
        }
    }

    /// Task 026: `IslandWindowController.scheduleReminderBannerDismiss()`
    /// schedules the real `.reminderBannerDismissed` dispatch after
    /// `IslandMotionTokens.reminderBannerHoldDuration`, which this probe
    /// cannot exercise headlessly (no real `DispatchQueue.main.asyncAfter`
    /// wait here). Instead it asserts the two facts that make that live
    /// behavior correct: the scheduled hold duration is exactly 2.0 seconds,
    /// and the resulting dismiss transition stages the shared
    /// `expandedCollapseRecovery` completion identifier rather than a new,
    /// bespoke collapse path — so the eventual collapse motion is guaranteed
    /// to reuse `startActiveMotion`'s existing 0.32s non-spring recovery.
    private static func validateAutoDismissTiming() throws {
        guard IslandMotionTokens.reminderBannerHoldDuration == 2.0 else {
            throw IslandReminderBannerProbeError.failed(
                "reminderBannerHoldDuration expected 2.0, got \(IslandMotionTokens.reminderBannerHoldDuration)"
            )
        }

        let baseState = reviewBaseState()
        let due = IslandPresentationReducer.reduce(
            current: baseState,
            intent: .reminderBannerDue(kind: .review, key: "auto-dismiss-timing-check")
        )
        guard due.reason == .reminderBannerPresented else {
            throw IslandReminderBannerProbeError.failed(
                "auto-dismiss timing probe setup: reminderBannerDue did not present the banner: \(due.reason)"
            )
        }

        let dismissed = IslandPresentationReducer.reduce(
            current: due.state,
            intent: .reminderBannerDismissed
        )
        guard dismissed.reason == .reminderBannerDismissed,
              dismissed.state.presentationLockState.transitionID == "expandedCollapseRecovery" else {
            throw IslandReminderBannerProbeError.failed(
                "auto-dismiss did not stage the shared expandedCollapseRecovery completion identifier: transitionID=\(String(describing: dismissed.state.presentationLockState.transitionID))"
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
