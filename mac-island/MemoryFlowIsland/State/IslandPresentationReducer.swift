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
    case musicTakeoverStarted
    case musicSnapshotAccepted
    case musicSnapshotRetargeted
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
    case loginRequiredPresented
    case loginRequiredDismissed
    case updatePromptPresented
    case updatePromptUpdateRequested
    case updatePromptLaterRequested
    case updateDownloadStarted
    case updateDownloadProgressed
    case updateDownloadEnded
    case outsideCollapsedToCompact
    case outsideCollapsedToActivity
    case presentationRetargeted
}

private extension IslandInteractionIntent {
    var isMockPlaybackStart: Bool {
        if case .mockPlaybackStarted = self {
            return true
        }
        return false
    }
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
        case let .updateDownloadStarted(progress):
            guard state.updateDownloadProgress == nil else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .updateDownloadStarted) {
                $0.updatePrompt = nil
                $0.updateDownloadProgress = progress
                $0.isHovered = false
            }
        case let .updateDownloadProgressed(progress):
            guard let previous = state.updateDownloadProgress else {
                return unchanged(state, reason: .intentIgnored)
            }
            guard previous != progress,
                  (progress.percentage ?? previous.percentage ?? 0) >= (previous.percentage ?? 0) else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .updateDownloadProgressed) {
                $0.updateDownloadProgress = progress
            }
        case .updateDownloadEnded:
            guard state.updateDownloadProgress != nil else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .updateDownloadEnded) {
                $0.updateDownloadProgress = nil
                $0.isHovered = false
            }
        case let .updatePromptAvailable(prompt):
            guard state.updatePrompt != prompt else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .updatePromptPresented) {
                $0.updatePrompt = prompt
                $0.isHovered = false
            }
        case .updatePromptUpdateRequested:
            guard state.updatePrompt != nil else {
                return unchanged(state, reason: .intentIgnored)
            }
            return transition(state, reason: .updatePromptUpdateRequested) {
                $0.updatePrompt = nil
                $0.isHovered = false
            }
        case .updatePromptLaterRequested:
            guard state.updatePrompt != nil else {
                return unchanged(state, reason: .intentIgnored)
            }
            return transition(state, reason: .updatePromptLaterRequested) {
                $0.updatePrompt = nil
                $0.isHovered = false
            }
        case .loginRequiredRequested:
            guard state.authState == .loggedOut,
                  state.primaryMode == .app else {
                return unchanged(state, reason: .intentIgnored)
            }
            guard state.isLoginRequiredPresented == false else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .loginRequiredPresented) {
                $0.isLoginRequiredPresented = true
                $0.isHovered = false
            }
        case .loginRequiredDismissed:
            guard state.isLoginRequiredPresented else {
                return unchanged(state, reason: .noChange)
            }
            return transition(state, reason: .loginRequiredDismissed) {
                $0.isLoginRequiredPresented = false
                $0.isHovered = false
            }
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
        case .loginRequiredRequested, .loginRequiredDismissed,
             .updatePromptAvailable, .updatePromptUpdateRequested, .updatePromptLaterRequested,
             .updateDownloadStarted, .updateDownloadProgressed, .updateDownloadEnded:
            return unchanged(state, reason: .noChange)
        case .outsideCollapse:
            if state.updatePrompt != nil {
                return unchanged(state, reason: .intentIgnored)
            }
            if state.isLoginRequiredPresented {
                return reduce(current: state, intent: .loginRequiredDismissed)
            }
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
            if state.isLoginRequiredPresented {
                return unchanged(state, reason: .noChange)
            }
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
                    if $0.presentationLockState.transitionID == "expandedCollapseRecovery" {
                        $0.presentationLockState.transitionID = nil
                    }
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
        case let .mockPlaybackStarted(snapshot), let .musicSnapshotUpdated(snapshot):
            if state.authState != .loggedIn && state.primaryMode != .music {
                return unchanged(state, reason: .musicSnapshotIgnoredLoggedOut)
            }

            let isAlreadyInMusic = state.primaryMode == .music
            let reason: IslandPresentationTransitionReason
            if isAlreadyInMusic {
                reason = .musicSnapshotRetargeted
            } else if intent.isMockPlaybackStart {
                reason = .musicTakeoverStarted
            } else {
                reason = .musicSnapshotAccepted
            }

            return transition(state, reason: reason) { nextState in
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

            return exitMusic(state, reason: .musicStoppedToApp)
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
        case .modeSwitchToggle, .modeSwitchMutate:
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
                if intent == .modeSwitchToggle {
                    nextState.presentationState = .activity
                    nextState.forceCompactMode = false
                }
                nextState.isHovered = false
                nextState.isReminderActive = false
                ensureAppMockSource(&nextState, for: nextMode)
                lockModeSwitch(&nextState)
            }
        case let .reminderDue(key):
            guard state.authState == .loggedIn,
                  state.primaryMode == .app,
                  state.appDisplayMode == .review,
                  state.forceCompactMode,
                  state.presentationState != .expanded,
                  state.lastReminderDueKey != key else {
                return unchanged(state, reason: .intentIgnored)
            }

            return transition(
                state,
                reason: .reminderDueOpenedReviewActivity
            ) { nextState in
                nextState.isReminderActive = true
                nextState.lastReminderDueKey = key
                nextState.presentationState = .activity
                nextState.forceCompactMode = false
                nextState.isHovered = false
                lockForceCompactTransition(&nextState)
            }
        case .pausedMusicTimeout:
            guard state.primaryMode == .music || state.mockSources.music != nil else {
                return unchanged(state, reason: .intentIgnored)
            }

            return exitMusic(state, reason: .pausedMusicTimedOutToApp)
        case .transitionComplete,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .updatePromptAvailable,
             .updatePromptUpdateRequested,
             .updatePromptLaterRequested,
             .updateDownloadStarted,
             .updateDownloadProgressed,
             .updateDownloadEnded,
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

    /// Music content must leave before the shell resolves the retained app surface.
    /// The app display mode and compact guard are already authoritative on the state.
    private static func exitMusic(
        _ state: IslandDomainState,
        reason: IslandPresentationTransitionReason
    ) -> IslandPresentationReducerResult {
        transition(state, reason: reason) { nextState in
            nextState.primaryMode = .app
            nextState.presentationState = state.forceCompactMode ? .collapsed : .activity
            nextState.forceCompactMode = state.forceCompactMode
            nextState.isHovered = false
            nextState.mockSources.music = nil
            ensureAppMockSource(&nextState, for: state.appDisplayMode)
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
        let shouldRecoverActivity = state.forceCompactMode == false && hasRecoverableActivitySource(state)

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

    private static func hasRecoverableActivitySource(_ state: IslandDomainState) -> Bool {
        switch state.primaryMode {
        case .app:
            guard state.authState == .loggedIn else { return false }

            switch state.appDisplayMode {
            case .review:
                return state.reviewSnapshot != nil || state.mockSources.review != nil
            case .todo:
                return state.todoSnapshot != nil || state.mockSources.todo != nil
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
        let isCurrentCompletion = identifier == IslandTransitionLockIdentifier.trackpadGestureCooldown
            ? state.gestureState == .cooldown
            : state.presentationLockState.transitionID == identifier
        guard isCurrentCompletion else {
            return unchanged(state, reason: .noChange)
        }

        return transition(state, reason: .noChange) {
            switch identifier {
            case "expandedCollapseRecovery":
                if $0.forceCompactMode == false && hasRecoverableActivitySource($0) {
                    $0.presentationState = .activity
                }
                $0.presentationLockState.transitionID = nil
            case IslandTransitionLockIdentifier.trackpadGestureCooldown:
                if $0.gestureState == .cooldown {
                    $0.gestureState = .idle
                }
            case IslandTransitionLockIdentifier.forceCompactTransition:
                $0.presentationLockState.isForceCompactLocked = false
                $0.presentationLockState.transitionID = nil
            case IslandTransitionLockIdentifier.modeSwitchLock:
                $0.presentationLockState.isModeSwitchLocked = false
                $0.presentationLockState.transitionID = nil
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
            let preservesModeSwitchLock = $0.presentationLockState.isModeSwitchLocked
            $0.presentationState = target.presentationState
            $0.forceCompactMode = target.forceCompactMode
            $0.isHovered = target.isHovered
            if target.locksTrackpadGesture {
                lockTrackpadGesture(&$0)
            }
            unlockPresentationLocks(&$0)
            if preservesModeSwitchLock {
                $0.presentationLockState.isModeSwitchLocked = true
                $0.presentationLockState.transitionID = IslandTransitionLockIdentifier.modeSwitchLock
            }
        }
    }

    private static func shouldRespectModeSwitchLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand, .modeSwitchToggle, .modeSwitchMutate, .loginRequiredRequested, .loginRequiredDismissed:
            return true
        case .hoverEnter,
             .hoverLeave,
             .mockPlaybackStarted,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .reminderDue,
             .pausedMusicTimeout,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .updatePromptAvailable,
             .updatePromptUpdateRequested,
             .updatePromptLaterRequested,
             .updateDownloadStarted,
             .updateDownloadProgressed,
             .updateDownloadEnded,
             .mockScenarioSelect,
             .retargetPresentation,
             .transitionComplete:
            return false
        }
    }

    private static func shouldRespectForceCompactLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand, .modeSwitchToggle, .modeSwitchMutate, .loginRequiredRequested, .loginRequiredDismissed:
            return true
        case .hoverEnter,
             .hoverLeave,
             .mockPlaybackStarted,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .reminderDue,
             .pausedMusicTimeout,
             .greetingLifecycleCompleted,
             .greetingFastForward,
             .updatePromptAvailable,
             .updatePromptUpdateRequested,
             .updatePromptLaterRequested,
             .updateDownloadStarted,
             .updateDownloadProgressed,
             .updateDownloadEnded,
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
             .loginRequiredRequested,
             .loginRequiredDismissed,
             .updatePromptAvailable,
             .updatePromptUpdateRequested,
             .updatePromptLaterRequested,
             .updateDownloadStarted,
             .updateDownloadProgressed,
             .updateDownloadEnded,
             .outsideCollapse,
             .pointerSwipe,
             .mockPlaybackStarted,
             .musicSnapshotUpdated,
             .musicStopped,
             .musicCommandRequested,
             .modeSwitchToggle,
             .modeSwitchMutate,
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
