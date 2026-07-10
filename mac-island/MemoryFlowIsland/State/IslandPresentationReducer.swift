import Foundation

enum IslandPresentationTransitionReason: String, Codable, Equatable {
    case noChange
    case intentIgnored
    case mockScenarioSelected
    case trackpadGestureLocked
    case modeSwitchLocked
    case forceCompactTransitionLocked
    case mockPreviousTrackCommanded
    case mockPlayPauseCommanded
    case mockNextTrackCommanded
    case musicSnapshotAccepted
    case musicSnapshotIgnoredLoggedOut
    case musicStoppedToApp
    case musicCommandRequested
    case modeSwitchedToReview
    case modeSwitchedToTodo
    case activitySwitchedToReview
    case activitySwitchedToTodo
    case activitySwitchedToMusic
    case reminderDueMarkedActive
    case reminderDueOpenedReviewActivity
    case pausedMusicTimedOutToApp
    case greetingLifecycleCompleted
    case hoverEntered
    case hoverLeft
    case pointerSwipedToCompact
    case pointerSwipedToActivity
    case trackpadSwipedUpToCompact
    case trackpadSwipedUpToActivity
    case trackpadSwipedDownToActivity
    case trackpadSwipedDownToExpandedApp
    case trackpadSwipedDownToExpandedMusic
    case tapExpandedToApp
    case tapExpandedToMusic
    case tapCollapsedToCompact
    case tapCollapsedToActivity
    case outsideCollapsedToCompact
    case outsideCollapsedToActivity
    case presentationRetargeted
}

struct IslandPresentationReducerMetadata: Codable, Equatable {
    let mockMusicCommand: IslandHorizontalMusicCommand?
    let musicCommand: IslandHorizontalMusicCommand?

    static let none = IslandPresentationReducerMetadata(
        mockMusicCommand: nil,
        musicCommand: nil
    )
}

struct IslandPresentationReducerResult: Codable, Equatable {
    let state: IslandDomainState
    let reason: IslandPresentationTransitionReason
    let metadata: IslandPresentationReducerMetadata

    var derivedState: IslandDerivedState {
        IslandDerivedState.derive(from: state)
    }
}

enum IslandPresentationReducer {
    static func reduce(
        current state: IslandDomainState,
        intent: IslandInteractionIntent
    ) -> IslandPresentationReducerResult {
        switch intent {
        case let .transitionComplete(identifier):
            return completeTransition(state, identifier: identifier)
        case let .retargetPresentation(target):
            return retargetPresentation(state, target: target)
        case let .mockScenarioSelect(scenarioID):
            guard scenarioID.isEmpty == false else {
                return unchanged(state, reason: .noChange)
            }

            guard let scenario = IslandMockScenario.scenario(id: scenarioID) else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(state, reason: .mockScenarioSelected) { nextState in
                nextState = scenario.initialState
            }
        case .greetingLifecycleCompleted, .greetingFastForward:
            guard state.isGreetingActive else {
                return unchanged(state, reason: .noChange)
            }

            return transition(state, reason: .greetingLifecycleCompleted) { nextState in
                nextState.isGreetingActive = false
                nextState.greetingText = nil
            }
        default:
            break
        }

        if state.isTrackpadGestureLocked,
           isTrackpadIntent(intent) {
            return unchanged(state, reason: .trackpadGestureLocked)
        }

        if state.isModeSwitchLocked,
           shouldRespectModeSwitchLock(intent) {
            return unchanged(state, reason: .modeSwitchLocked)
        }

        if state.isForceCompactLocked,
           shouldRespectForceCompactLock(intent) {
            return unchanged(state, reason: .forceCompactTransitionLocked)
        }

        switch intent {
        case .outsideCollapse:
            return collapseExpanded(
                state,
                compactReason: .outsideCollapsedToCompact,
                activityReason: .outsideCollapsedToActivity
            )
        case .hoverEnter:
            if state.presentationState == .expanded {
                return unchanged(state, reason: .noChange)
            }

            return transition(state, reason: state.isHovered ? .noChange : .hoverEntered) {
                $0.isHovered = true
            }
        case .hoverLeave:
            return transition(state, reason: state.isHovered ? .hoverLeft : .noChange) {
                $0.isHovered = false
            }
        case .tap:
            switch state.presentationState {
            case .expanded:
                return collapseExpanded(
                    state,
                    compactReason: .tapCollapsedToCompact,
                    activityReason: .tapCollapsedToActivity
                )
            case .collapsed, .activity:
                guard state.authState == .loggedIn else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(
                    state,
                    reason: state.primaryMode == .music ? .tapExpandedToMusic : .tapExpandedToApp
                ) {
                    $0.presentationState = .expanded
                    $0.isHovered = false
                }
            }
        case let .pointerSwipe(direction):
            let derivedState = IslandDerivedState.derive(from: state)

            switch direction {
            case .right:
                guard derivedState.showAnyActivity else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .pointerSwipedToCompact) { nextState in
                    nextState.forceCompactMode = true
                    nextState.presentationState = .activity
                    nextState.isHovered = false
                    lockForceCompactTransition(&nextState)
                }
            case .left:
                guard state.presentationState != .expanded,
                      derivedState.hasAnyActivitySource,
                      state.forceCompactMode else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .pointerSwipedToActivity) { nextState in
                    nextState.forceCompactMode = false
                    nextState.presentationState = .activity
                    nextState.isHovered = false
                    lockForceCompactTransition(&nextState)
                }
            }
        case let .trackpadSwipe(direction):
            let derivedState = IslandDerivedState.derive(from: state)

            switch direction {
            case .up:
                if state.presentationState == .expanded {
                    let collapseResult = collapseExpanded(
                        state,
                        compactReason: .trackpadSwipedUpToCompact,
                        activityReason: .trackpadSwipedUpToActivity
                    )

                    return transition(
                        collapseResult.state,
                        reason: collapseResult.reason,
                        metadata: collapseResult.metadata
                    ) { nextState in
                        lockTrackpadGesture(&nextState)
                    }
                }

                guard derivedState.showAnyActivity else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .trackpadSwipedUpToCompact) { nextState in
                    nextState.forceCompactMode = true
                    nextState.presentationState = .activity
                    nextState.isHovered = false
                    lockTrackpadGesture(&nextState)
                    lockForceCompactTransition(&nextState)
                }
            case .down:
                if state.presentationState != .expanded,
                   derivedState.showAnyActivity {
                    return transition(
                        state,
                        reason: state.primaryMode == .music
                            ? .trackpadSwipedDownToExpandedMusic
                            : .trackpadSwipedDownToExpandedApp
                    ) { nextState in
                        nextState.presentationState = .expanded
                        nextState.isHovered = false
                        lockTrackpadGesture(&nextState)
                    }
                }

                guard state.presentationState != .expanded,
                      derivedState.hasAnyActivitySource,
                      state.forceCompactMode else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .trackpadSwipedDownToActivity) { nextState in
                    nextState.forceCompactMode = false
                    nextState.presentationState = .activity
                    nextState.isHovered = false
                    lockTrackpadGesture(&nextState)
                    lockForceCompactTransition(&nextState)
                }
            }
        case let .horizontalMusicCommand(command):
            guard state.primaryMode == .music else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(
                state,
                reason: mockMusicCommandReason(for: command),
                metadata: IslandPresentationReducerMetadata(
                    mockMusicCommand: command,
                    musicCommand: command
                )
            ) { nextState in
                lockTrackpadGesture(&nextState)
            }
        case let .musicSnapshotUpdated(snapshot):
            if state.authState != .loggedIn && state.primaryMode != .music {
                return unchanged(state, reason: .musicSnapshotIgnoredLoggedOut)
            }

            return transition(state, reason: .musicSnapshotAccepted) { nextState in
                nextState.primaryMode = .music
                nextState.presentationState = nextState.presentationState == .expanded ? .expanded : .activity
                nextState.forceCompactMode = false
                nextState.isHovered = false
                nextState.isReminderActive = false
                nextState.isGreetingActive = false
                nextState.greetingText = nil
                nextState.mockSources.music = IslandMockMusicActivity(snapshot: snapshot)
                nextState.mockSources.todo = nil
                if nextState.presentationLockState.isForceCompactLocked == false,
                   state.primaryMode != .music || state.forceCompactMode {
                    lockForceCompactTransition(&nextState)
                }
            }
        case .musicStopped:
            guard state.primaryMode == .music || state.mockSources.music != nil else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(state, reason: .musicStoppedToApp) { nextState in
                nextState.primaryMode = .app
                nextState.presentationState = .collapsed
                nextState.forceCompactMode = true
                nextState.isHovered = false
                nextState.mockSources.music = nil
            }
        case let .musicCommandRequested(command):
            guard state.primaryMode == .music else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(
                state,
                reason: .musicCommandRequested,
                metadata: IslandPresentationReducerMetadata(
                    mockMusicCommand: nil,
                    musicCommand: command
                )
            ) { _ in }
        case .modeSwitchToggle:
            let derivedState = IslandDerivedState.derive(from: state)
            guard state.primaryMode == .app,
                  state.authState == .loggedIn,
                  state.presentationState != .expanded,
                  derivedState.hasAppActivitySource else {
                return unchanged(state, reason: .intentIgnored)
            }

            let nextMode: IslandAppDisplayMode = state.appDisplayMode == .review ? .todo : .review
            return transition(
                state,
                reason: state.presentationState == .activity && state.forceCompactMode == false
                    ? (nextMode == .todo ? .activitySwitchedToTodo : .activitySwitchedToReview)
                    : (nextMode == .todo ? .modeSwitchedToTodo : .modeSwitchedToReview)
            ) { nextState in
                nextState.appDisplayMode = nextMode
                nextState.primaryMode = .app
                nextState.presentationState = .activity
                nextState.forceCompactMode = false
                nextState.isHovered = false
                nextState.isReminderActive = false
                ensureAppMockSource(&nextState, for: nextMode)
                lockModeSwitch(&nextState)
            }
        case .reminderDue:
            guard state.authState == .loggedIn,
                  state.primaryMode == .app,
                  state.appDisplayMode == .review else {
                return unchanged(state, reason: .intentIgnored)
            }

            let shouldOpenActivity = state.forceCompactMode && state.presentationState != .expanded

            return transition(
                state,
                reason: shouldOpenActivity
                    ? .reminderDueOpenedReviewActivity
                    : .reminderDueMarkedActive
            ) { nextState in
                nextState.isReminderActive = true

                guard shouldOpenActivity else {
                    return
                }

                nextState.presentationState = .activity
                nextState.forceCompactMode = false
                nextState.isHovered = false
                lockForceCompactTransition(&nextState)
            }
        case .pausedMusicTimeout:
            guard state.primaryMode == .music || state.mockSources.music != nil else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(state, reason: .pausedMusicTimedOutToApp) { nextState in
                nextState.primaryMode = .app
                nextState.presentationState = .collapsed
                nextState.forceCompactMode = true
                nextState.isHovered = false
                nextState.mockSources.music = nil
            }
        case .transitionComplete,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .mockScenarioSelect,
             .retargetPresentation:
            return unchanged(state, reason: .noChange)
        }
    }

    private static func mockMusicCommandReason(
        for command: IslandHorizontalMusicCommand
    ) -> IslandPresentationTransitionReason {
        switch command {
        case .previousTrack:
            return .mockPreviousTrackCommanded
        case .playPause:
            return .mockPlayPauseCommanded
        case .nextTrack:
            return .mockNextTrackCommanded
        }
    }

    private static func unchanged(
        _ state: IslandDomainState,
        reason: IslandPresentationTransitionReason
    ) -> IslandPresentationReducerResult {
        transition(state, reason: reason) { _ in }
    }

    private static func collapseExpanded(
        _ state: IslandDomainState,
        compactReason: IslandPresentationTransitionReason,
        activityReason: IslandPresentationTransitionReason
    ) -> IslandPresentationReducerResult {
        guard state.presentationState == .expanded else {
            return unchanged(state, reason: .intentIgnored)
        }

        // A forced compact presentation wins even when the expanded source still
        // has activity data. Otherwise retain the source mode for its compact to
        // activity recovery animation.
        let shouldRecoverActivity = state.forceCompactMode == false && hasRecoverableMockActivitySource(state)

        let stageActivityRecovery = shouldRecoverActivity
        return transition(
            state,
            reason: compactReason
        ) {
            $0.presentationState = .collapsed
            if stageActivityRecovery {
                $0.presentationLockState.transitionID = "expandedCollapseRecovery"
            }
            $0.isHovered = false
        }
    }

    private static func hasRecoverableMockActivitySource(_ state: IslandDomainState) -> Bool {
        switch state.primaryMode {
        case .app:
            guard state.authState == .loggedIn else { return false }

            switch state.appDisplayMode {
            case .review:
                return state.mockSources.review != nil
            case .todo:
                return state.mockSources.todo != nil
            }
        case .music:
            return state.mockSources.music != nil
        }
    }

    private static func completeTransition(
        _ state: IslandDomainState,
        identifier: String?
    ) -> IslandPresentationReducerResult {
        guard let identifier else {
            return unchanged(state, reason: .noChange)
        }

        return transition(state, reason: .noChange) {
            switch identifier {
            case "expandedCollapseRecovery":
                if $0.forceCompactMode == false && hasRecoverableMockActivitySource($0) {
                    $0.presentationState = .activity
                }
                if $0.presentationLockState.transitionID == identifier { $0.presentationLockState.transitionID = nil }
            case IslandTransitionLockIdentifier.trackpadGestureCooldown:
                if $0.gestureState == .cooldown {
                    $0.gestureState = .idle
                }
            case IslandTransitionLockIdentifier.forceCompactTransition:
                $0.presentationLockState.isForceCompactLocked = false
                if $0.presentationLockState.transitionID == identifier {
                    $0.presentationLockState.transitionID = nil
                }
            case IslandTransitionLockIdentifier.modeSwitchLock:
                $0.presentationLockState.isModeSwitchLocked = false
                if $0.presentationLockState.transitionID == identifier {
                    $0.presentationLockState.transitionID = nil
                }
            default:
                break
            }
        }
    }

    private static func retargetPresentation(
        _ state: IslandDomainState,
        target: IslandPresentationRetargetTarget
    ) -> IslandPresentationReducerResult {
        transition(state, reason: .presentationRetargeted) {
            $0.presentationState = target.presentationState
            $0.forceCompactMode = target.forceCompactMode
            $0.isHovered = target.isHovered
            if target.locksTrackpadGesture {
                lockTrackpadGesture(&$0)
            }
            unlockPresentationLocks(&$0)
        }
    }

    private static func shouldRespectModeSwitchLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand, .modeSwitchToggle:
            return true
        case .hoverEnter,
             .hoverLeave,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .reminderDue,
             .pausedMusicTimeout,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .mockScenarioSelect,
             .retargetPresentation,
             .transitionComplete:
            return false
        }
    }

    private static func shouldRespectForceCompactLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand, .modeSwitchToggle:
            return true
        case .hoverEnter,
             .hoverLeave,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .reminderDue,
             .pausedMusicTimeout,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .mockScenarioSelect,
             .retargetPresentation,
             .transitionComplete:
            return false
        }
    }

    private static func isTrackpadIntent(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .trackpadSwipe, .horizontalMusicCommand:
            return true
        case .hoverEnter,
             .hoverLeave,
             .tap,
             .outsideCollapse,
             .pointerSwipe,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .modeSwitchToggle,
             .reminderDue,
             .pausedMusicTimeout,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .mockScenarioSelect,
             .retargetPresentation,
             .transitionComplete:
            return false
        }
    }

    private static func lockTrackpadGesture(_ state: inout IslandDomainState) {
        state.gestureState = .cooldown
    }

    private static func lockForceCompactTransition(_ state: inout IslandDomainState) {
        state.presentationLockState.isForceCompactLocked = true
        state.presentationLockState.transitionID = IslandTransitionLockIdentifier.forceCompactTransition
    }

    private static func lockModeSwitch(_ state: inout IslandDomainState) {
        state.presentationLockState.isModeSwitchLocked = true
        state.presentationLockState.transitionID = IslandTransitionLockIdentifier.modeSwitchLock
    }

    private static func ensureAppMockSource(
        _ state: inout IslandDomainState,
        for mode: IslandAppDisplayMode
    ) {
        switch mode {
        case .review:
            if state.mockSources.review == nil {
                state.mockSources.review = IslandMockReviewActivity(
                    pendingCount: 3,
                    completedTodayCount: 2,
                    nextSubjectTitle: "Review"
                )
            }
            state.mockSources.todo = nil
        case .todo:
            if state.mockSources.todo == nil {
                state.mockSources.todo = IslandMockTodoActivity(
                    pendingCount: 4,
                    dueTodayCount: 1,
                    overdueCount: 0,
                    nextTaskTitle: "Todo"
                )
            }
            state.mockSources.review = nil
        }
    }

    private static func unlockPresentationLocks(_ state: inout IslandDomainState) {
        state.presentationLockState.isForceCompactLocked = false
        state.presentationLockState.isModeSwitchLocked = false
        state.presentationLockState.transitionID = nil
    }

    private static func transition(
        _ state: IslandDomainState,
        reason: IslandPresentationTransitionReason,
        metadata: IslandPresentationReducerMetadata = .none,
        mutate: (inout IslandDomainState) -> Void
    ) -> IslandPresentationReducerResult {
        var nextState = state
        mutate(&nextState)

        return IslandPresentationReducerResult(
            state: nextState,
            reason: reason,
            metadata: metadata
        )
    }
}
