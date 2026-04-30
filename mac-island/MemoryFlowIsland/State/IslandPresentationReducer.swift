import Foundation

enum IslandPresentationTransitionReason: String, Codable, Equatable {
    case noChange
    case intentIgnored
    case mockScenarioSelected
    case trackpadGestureLocked
    case modeSwitchLocked
    case forceCompactTransitionLocked
    case mockPreviousTrackCommanded
    case mockNextTrackCommanded
    case reminderDueMarkedActive
    case reminderDueOpenedReviewActivity
    case pausedMusicTimedOutToApp
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
}

struct IslandPresentationReducerMetadata: Codable, Equatable {
    let mockMusicCommand: IslandHorizontalMusicCommand?

    static let none = IslandPresentationReducerMetadata(
        mockMusicCommand: nil
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
        default:
            break
        }

        if state.isTrackpadGestureLocked,
           isTrackpadIntent(intent) {
            return unchanged(state, reason: .trackpadGestureLocked)
        }

        if state.isModeSwitchAnimating,
           shouldRespectModeSwitchLock(intent) {
            return unchanged(state, reason: .modeSwitchLocked)
        }

        if state.isForceCompactTransitioning,
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
                reason: command == .previousTrack
                    ? .mockPreviousTrackCommanded
                    : .mockNextTrackCommanded,
                metadata: IslandPresentationReducerMetadata(
                    mockMusicCommand: command
                )
            ) { nextState in
                lockTrackpadGesture(&nextState)
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
        case .transitionComplete, .mockScenarioSelect:
            return unchanged(state, reason: .noChange)
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

        let hasActivitySource = IslandDerivedState.derive(from: state).hasAnyActivitySource
        let shouldRecoverActivity = hasActivitySource && state.forceCompactMode == false

        return transition(
            state,
            reason: shouldRecoverActivity ? activityReason : compactReason
        ) {
            $0.presentationState = shouldRecoverActivity ? .activity : .collapsed
            $0.isHovered = false
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
            case IslandTransitionLockIdentifier.trackpadGestureCooldown:
                if $0.gestureState == .cooldown {
                    $0.gestureState = .idle
                }
            case IslandTransitionLockIdentifier.forceCompactTransition:
                $0.animationState.isForceCompactTransitioning = false
                if $0.animationState.transitionID == identifier {
                    $0.animationState.transitionID = nil
                }
            case IslandTransitionLockIdentifier.modeSwitchAnimation:
                $0.animationState.isModeSwitchAnimating = false
                if $0.animationState.transitionID == identifier {
                    $0.animationState.transitionID = nil
                }
            default:
                break
            }
        }
    }

    private static func shouldRespectModeSwitchLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand:
            return true
        case .hoverEnter,
             .hoverLeave,
             .reminderDue,
             .pausedMusicTimeout,
             .mockScenarioSelect,
             .transitionComplete:
            return false
        }
    }

    private static func shouldRespectForceCompactLock(_ intent: IslandInteractionIntent) -> Bool {
        switch intent {
        case .tap, .outsideCollapse, .pointerSwipe, .trackpadSwipe, .horizontalMusicCommand:
            return true
        case .hoverEnter,
             .hoverLeave,
             .reminderDue,
             .pausedMusicTimeout,
             .mockScenarioSelect,
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
             .reminderDue,
             .pausedMusicTimeout,
             .mockScenarioSelect,
             .transitionComplete:
            return false
        }
    }

    private static func lockTrackpadGesture(_ state: inout IslandDomainState) {
        state.gestureState = .cooldown
    }

    private static func lockForceCompactTransition(_ state: inout IslandDomainState) {
        state.animationState.isForceCompactTransitioning = true
        state.animationState.transitionID = IslandTransitionLockIdentifier.forceCompactTransition
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
