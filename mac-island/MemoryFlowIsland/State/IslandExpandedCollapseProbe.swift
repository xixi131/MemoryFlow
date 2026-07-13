import Foundation

struct IslandExpandedCollapseProbeRow: Equatable {
    let source: String
    let input: String
    let firstVisualState: IslandVisualState
    let finalVisualState: IslandVisualState
    let firstReason: IslandPresentationTransitionReason
    let recoversOriginalActivity: Bool
    let trackpadCooldownActive: Bool
    let usesSharedRecoveryTransition: Bool
}

enum IslandExpandedCollapseProbe {
    static func rows() -> [IslandExpandedCollapseProbeRow] {
        let sources: [(String, IslandDomainState)] = [
            ("review", .mockExpandedReview),
            ("todo", .mockExpandedTodo),
            ("live-review", liveExpandedReviewState()),
            ("live-todo", liveExpandedTodoState()),
            ("music", .mockExpandedMusic)
        ]
        let inputs: [(String, IslandInteractionIntent)] = [
            ("tap", .tap),
            ("outside", .outsideCollapse),
            ("trackpad-up", .trackpadSwipe(.up))
        ]

        return sources.flatMap { source, initialState in
            inputs.map { input, intent in
                row(source: source, input: input, initialState: initialState, intent: intent)
            }
        }
    }

    static func validate() throws {
        let rows = rows()
        guard rows.count == 15,
              rows.allSatisfy({
                  $0.firstVisualState == .compactCollapsed &&
                      $0.finalVisualState == .activityCollapsed &&
                      $0.recoversOriginalActivity &&
                      $0.usesSharedRecoveryTransition
              }) else {
            throw IslandExpandedCollapseProbeError.activityRecoveryFailed(rows)
        }

        let expectedReasons: [String: IslandPresentationTransitionReason] = [
            "tap": .tapCollapsedToCompact,
            "outside": .outsideCollapsedToCompact,
            "trackpad-up": .trackpadSwipedUpToCompact
        ]
        guard rows.allSatisfy({ $0.firstReason == expectedReasons[$0.input] }),
              rows.filter({ $0.input == "trackpad-up" }).allSatisfy(\.trackpadCooldownActive),
              rows.filter({ $0.input != "trackpad-up" }).allSatisfy({ $0.trackpadCooldownActive == false }) else {
            throw IslandExpandedCollapseProbeError.inputSemanticsFailed(rows)
        }

        let forceCompactRows = [
            forcedCompactRow(source: "review", state: .mockExpandedReview),
            forcedCompactRow(source: "todo", state: .mockExpandedTodo),
            forcedCompactRow(source: "live-review", state: liveExpandedReviewState()),
            forcedCompactRow(source: "live-todo", state: liveExpandedTodoState()),
            forcedCompactRow(source: "music", state: .mockExpandedMusic)
        ]
        guard forceCompactRows.allSatisfy({ $0.presentationState == .collapsed && $0.forceCompactMode }),
              forceCompactRows.allSatisfy({ IslandDerivedState.derive(from: $0).visualState == .compactCollapsed }),
              forceCompactRows.allSatisfy({ $0.presentationLockState.transitionID == nil }) else {
            throw IslandExpandedCollapseProbeError.forceCompactFailed
        }
    }

    private static func row(
        source: String,
        input: String,
        initialState: IslandDomainState,
        intent: IslandInteractionIntent
    ) -> IslandExpandedCollapseProbeRow {
        let first = IslandPresentationReducer.reduce(current: initialState, intent: intent)
        let completed = IslandPresentationReducer.reduce(
            current: first.state,
            intent: .transitionComplete("expandedCollapseRecovery")
        )

        return IslandExpandedCollapseProbeRow(
            source: source,
            input: input,
            firstVisualState: first.derivedState.visualState,
            finalVisualState: completed.derivedState.visualState,
            firstReason: first.reason,
            recoversOriginalActivity: completed.state.primaryMode == initialState.primaryMode &&
                completed.state.appDisplayMode == initialState.appDisplayMode &&
                completed.state.forceCompactMode == false,
            trackpadCooldownActive: completed.state.gestureState == .cooldown,
            usesSharedRecoveryTransition: first.state.presentationLockState.transitionID == "expandedCollapseRecovery"
        )
    }

    private static func forcedCompactRow(source: String, state: IslandDomainState) -> IslandDomainState {
        var forced = state
        forced.forceCompactMode = true
        let first = IslandPresentationReducer.reduce(current: forced, intent: .outsideCollapse)
        return IslandPresentationReducer.reduce(
            current: first.state,
            intent: .transitionComplete("expandedCollapseRecovery")
        ).state
    }

    private static func liveExpandedReviewState() -> IslandDomainState {
        var state = IslandDomainState.expandedAppReview
        state.mockSources.review = nil
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

    private static func liveExpandedTodoState() -> IslandDomainState {
        var state = IslandDomainState.expandedAppReview
        state.appDisplayMode = .todo
        state.mockSources.review = nil
        state.mockSources.todo = nil
        state.todoSnapshot = TodoSnapshot(
            stats: TodoStatsDTO(pendingTasks: 2, dueToday: 1, overdueTasks: 0),
            tasks: [
                TodoTaskDTO(
                    id: 1,
                    title: "Live todo",
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

enum IslandExpandedCollapseProbeError: Error {
    case activityRecoveryFailed([IslandExpandedCollapseProbeRow])
    case inputSemanticsFailed([IslandExpandedCollapseProbeRow])
    case forceCompactFailed
}
