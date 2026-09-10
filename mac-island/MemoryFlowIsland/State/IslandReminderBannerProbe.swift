import AppKit
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
        try validateRepeatCopyAndStyle()
        try validateAutoDismissTiming()
        try validateExternalAgentNotice()
        try validateMusicArtworkUpdates()
        try validateAgentCompletionLogEvents()
        try validateToonFlowAgentModes()
        return "reminder-banner-probe: PASS; sequence=compactCollapsed->reminderBanner->compactCollapsed->activityCollapsed; kinds=review+todo; recovery=expandedCollapseRecovery; dedup=intentIgnored; policy=hourlyReviewRepeat+onceDailyTodo+timeGated+dayRearm+nothingPending+reminderDisabledSilences; repeatCopy=variedNudges+deterministic; repeatStyle=compactFirst+mixedShells; autoDismissHold=2.0s/6.0s+expandedCollapseRecovery; externalAgentNotice=present+tapDismiss; agentLogs=claudeEndTurn+claudeApprovalWait+claudeUserQuestionWait+chatGPTTaskComplete+chatGPTUserInputWait; toonFlow=allAgentModes+agentAnswersOnly; reminderActiveNeverSet=true"
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

        for initial in [IslandDomainState.musicActivity, .expandedMusic] {
            let overMusic = IslandPresentationReducer.reduce(
                current: initial, intent: .externalAgentNoticePresented(notice)
            )
            let updated = IslandPresentationReducer.reduce(
                current: overMusic.state, intent: .musicSnapshotUpdated(.mockPlaybackStart)
            )
            for result in [overMusic, updated] {
                guard result.derivedState.visualState == .expandedApp,
                      result.derivedState.previewContent.kind == .externalAgentNotification,
                      result.derivedState.previewContent.music == nil else {
                    throw IslandReminderBannerProbeError.failed("agent notice shell rendered music template")
                }
            }
            let closed = IslandPresentationReducer.reduce(current: updated.state, intent: .tap)
            guard closed.state.externalAgentNotice == nil,
                  closed.state.primaryMode == .music,
                  closed.state.mockSources.music != nil else {
                throw IslandReminderBannerProbeError.failed("dismissing agent notice lost music")
            }
        }
    }

    private static func validateMusicArtworkUpdates() throws {
        var fixtures: [Data] = []
        for color in [NSColor.red, .green, .blue] {
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            for x in 0..<2 {
                for y in 0..<2 { bitmap.setColor(color, atX: x, y: y) }
            }
            fixtures.append(bitmap.representation(using: .png, properties: [:])!)
        }
        for data in fixtures + fixtures.reversed() {
            guard let actual = IslandMusicArtworkCache.image(for: data)?.tiffRepresentation,
                  actual == NSImage(data: data)?.tiffRepresentation else {
                throw IslandReminderBannerProbeError.failed("artwork cache returned another track's image")
            }
        }
        guard IslandMusicArtworkCache.image(for: nil) == nil,
              IslandMusicArtworkCache.image(for: Data([0])) == nil else {
            throw IslandReminderBannerProbeError.failed("missing artwork retained a previous image")
        }
        print("music-display-regression: PASS; artwork=threeTracks+reverse+missing; agentNotice=activity+expanded+snapshotUpdate+dismiss")
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
            intent: .reminderBannerDue(IslandReminderAnnouncement(kind: kind, key: key))
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
            intent: .reminderBannerDue(IslandReminderAnnouncement(kind: kind, key: key))
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
        //    many pending items — and it does not refire within the same hourly
        //    slot. It DOES refire in the next slot, because an unfinished review
        //    queue is nagged once an hour until it is cleared.
        var reviewState = reviewStateBeforeTime
        guard let reviewEvent = IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: reviewState, calendar: calendar),
              reviewEvent.kind == .review,
              reviewEvent.key == "review-2026-08-04#0",
              reviewEvent.repeatIndex == 0 else {
            throw IslandReminderBannerProbeError.failed("policy: review did not fire exactly once when the reminder time was reached")
        }
        reviewState.firedReminderKeys.append(reviewEvent.key)

        guard IslandReminderDuePolicy.evaluate(now: day0TenSecondsLater, state: reviewState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: review refired 10s later (should be deduped within the hourly slot)")
        }
        guard IslandReminderDuePolicy.evaluate(
            now: date(day: 4, hour: 20, minute: 59),
            state: reviewState,
            calendar: calendar
        ) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: review refired 59 minutes in — the repeat interval is one hour")
        }
        reviewState.reviewSnapshot = ReviewSnapshot(
            dto: WidgetSummaryDTO(totalPendingReviews: 9, totalCompletedToday: 0, reminderTime: "20:00", subjects: [])
        )
        guard let hourlyRepeat = IslandReminderDuePolicy.evaluate(now: date(day: 4, hour: 21, minute: 0), state: reviewState, calendar: calendar),
              hourlyRepeat.key == "review-2026-08-04#1",
              hourlyRepeat.repeatIndex == 1 else {
            throw IslandReminderBannerProbeError.failed("policy: review did not re-announce one hour later while the queue was still pending")
        }
        reviewState.firedReminderKeys.append(hourlyRepeat.key)
        guard let laterRepeat = IslandReminderDuePolicy.evaluate(now: day0MuchLater, state: reviewState, calendar: calendar),
              laterRepeat.key == "review-2026-08-04#3",
              laterRepeat.repeatIndex == 3 else {
            throw IslandReminderBannerProbeError.failed("policy: review repeat slot did not track elapsed hours since the reminder time")
        }
        reviewState.firedReminderKeys.append(laterRepeat.key)

        // 2b) The reminder master switch (web settings → 复习提醒) silences
        //     everything, however much is pending.
        var disabledState = makeState(pendingReviews: 5, dueToday: 0, overdueTasks: 0, reminderTime: "20:00")
        disabledState.reviewSnapshot = ReviewSnapshot(
            dto: WidgetSummaryDTO(
                totalPendingReviews: 5,
                totalCompletedToday: 0,
                reminderTime: "20:00",
                subjects: [],
                reminderEnabled: false
            )
        )
        guard IslandReminderDuePolicy.evaluate(now: day0AtReminder, state: disabledState, calendar: calendar) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: a reminder fired even though reminderEnabled was false")
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
              noTimeEvent.key == "review-2026-08-04#19" else {
            throw IslandReminderBannerProbeError.failed("policy: review with no configured reminder time did not fire immediately once something was pending")
        }
        noTimeState.firedReminderKeys.append(noTimeEvent.key)
        guard IslandReminderDuePolicy.evaluate(
            now: date(day: 4, hour: 19, minute: 59, second: 59),
            state: noTimeState,
            calendar: calendar
        ) == nil else {
            throw IslandReminderBannerProbeError.failed("policy: no-configured-time review refired inside the same hour bucket")
        }
        guard let noTimeRepeat = IslandReminderDuePolicy.evaluate(now: day0MuchLater, state: noTimeState, calendar: calendar),
              noTimeRepeat.key == "review-2026-08-04#23" else {
            throw IslandReminderBannerProbeError.failed("policy: no-configured-time review did not fall into the next hour bucket")
        }

        // 5) Advancing the clock to the next day re-arms both kinds.
        var combinedState = reviewState
        combinedState.todoSnapshot = todoState.todoSnapshot
        combinedState.firedReminderKeys = reviewState.firedReminderKeys + todoState.firedReminderKeys

        guard let rearmedReview = IslandReminderDuePolicy.evaluate(now: day1AtReminder, state: combinedState, calendar: calendar),
              rearmedReview.kind == .review,
              rearmedReview.key == "review-2026-08-05#0" else {
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

    /// Repeat reminders must not read as the same notification stuck on loop:
    /// the copy varies, the shell alternates between the small banner and the
    /// large list, and both choices are deterministic for a given dedup key so
    /// a re-render can never make the island flicker between two variants.
    private static func validateRepeatCopyAndStyle() throws {
        let openers = (0..<8).map {
            IslandReminderCopy.message(for: .review, repeatIndex: 0, key: "review-2026-08-04#\($0)")
        }
        guard openers.allSatisfy({ IslandReminderCopy.reviewOpeners.contains($0) }) else {
            throw IslandReminderBannerProbeError.failed("copy: the first reminder of the day used a non-opener line")
        }

        let nudges = (1..<12).map {
            IslandReminderCopy.message(for: .review, repeatIndex: $0, key: "review-2026-08-04#\($0)")
        }
        guard nudges.allSatisfy({ IslandReminderCopy.reviewNudges.contains($0) }) else {
            throw IslandReminderBannerProbeError.failed("copy: a repeat reminder used a line outside the nudge pool")
        }
        guard Set(nudges).count >= 3 else {
            throw IslandReminderBannerProbeError.failed(
                "copy: repeat reminders barely varied their wording (distinct=\(Set(nudges).count))"
            )
        }

        // Deterministic: the same key always resolves to the same line/shell.
        guard IslandReminderCopy.message(for: .review, repeatIndex: 4, key: "stable-key")
                == IslandReminderCopy.message(for: .review, repeatIndex: 4, key: "stable-key"),
              IslandReminderCopy.style(for: .review, repeatIndex: 4, key: "stable-key", hasListContent: true)
                == IslandReminderCopy.style(for: .review, repeatIndex: 4, key: "stable-key", hasListContent: true) else {
            throw IslandReminderBannerProbeError.failed("copy: message/style selection was not deterministic for a fixed key")
        }

        // The first reminder is always the small shell; repeats mix both.
        guard IslandReminderCopy.style(for: .review, repeatIndex: 0, key: "review-2026-08-04#0", hasListContent: true) == .compact else {
            throw IslandReminderBannerProbeError.failed("style: the first reminder of the day should use the small shell")
        }
        let repeatStyles = (1..<12).map {
            IslandReminderCopy.style(for: .review, repeatIndex: $0, key: "review-2026-08-04#\($0)", hasListContent: true)
        }
        guard repeatStyles.contains(.expanded), repeatStyles.contains(.compact) else {
            throw IslandReminderBannerProbeError.failed("style: repeat reminders did not alternate between the small and large shells")
        }
        // Without review content to list, the large shell would be an empty box.
        guard (1..<12).allSatisfy({
            IslandReminderCopy.style(for: .review, repeatIndex: $0, key: "k#\($0)", hasListContent: false) == .compact
        }) else {
            throw IslandReminderBannerProbeError.failed("style: the large shell was used with nothing to list")
        }

        // The expanded announcement must reach the big shell and carry the queue.
        var state = reviewBaseState()
        state.reviewSnapshot = ReviewSnapshot(
            dto: WidgetSummaryDTO(
                totalPendingReviews: 2,
                totalCompletedToday: 0,
                reminderTime: "20:00",
                subjects: [],
                reviewItems: [
                    ReviewItemDTO(
                        id: 1,
                        subjectId: 9,
                        title: "子串",
                        chapterTitle: "第 1 周 · 数组与字符串基础（24 题）",
                        learnedAt: "2026-08-22T09:30:00"
                    ),
                    ReviewItemDTO(
                        id: 2,
                        subjectId: 9,
                        title: "哈希",
                        chapterTitle: "第 1 周 · 数组与字符串基础（24 题）",
                        learnedAt: "2026-08-11T09:30:00"
                    )
                ]
            )
        )
        let expanded = IslandPresentationReducer.reduce(
            current: state,
            intent: .reminderBannerDue(
                IslandReminderAnnouncement(
                    kind: .review,
                    key: "expanded-style-check",
                    style: .expanded,
                    message: "再不复习就要忘光啦"
                )
            )
        )
        guard expanded.reason == .reminderBannerPresented,
              expanded.derivedState.visualState == .reminderBannerExpanded,
              expanded.derivedState.previewContent.kind == .reminderBannerExpanded,
              expanded.derivedState.previewContent.title == "再不复习就要忘光啦",
              expanded.derivedState.previewContent.review?.items.count == 2,
              expanded.derivedState.previewContent.review?.items.first?.title == "子串",
              expanded.derivedState.previewContent.review?.items.first?.subtitle == "第 1 周 · 数组与字符串基础（24 题）",
              expanded.derivedState.previewContent.review?.items.first?.dateText == "8月22日",
              expanded.derivedState.previewContent.review?.items.first?.subjectID == "9" else {
            throw IslandReminderBannerProbeError.failed(
                "expanded reminder did not resolve to the large shell with its review list: state=\(expanded.derivedState.visualState) kind=\(expanded.derivedState.previewContent.kind)"
            )
        }

        guard IslandMotionTokens.reminderBannerExpandedHoldDuration > IslandMotionTokens.reminderBannerHoldDuration else {
            throw IslandReminderBannerProbeError.failed("the large reminder must stay open longer than the one-line banner")
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
            intent: .reminderBannerDue(IslandReminderAnnouncement(kind: .review, key: "auto-dismiss-timing-check"))
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
