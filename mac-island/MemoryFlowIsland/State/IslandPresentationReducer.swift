import Foundation

enum IslandPresentationTransitionReason: String, Codable, Equatable {
    case noChange
    case intentIgnored
    case mockPreviousTrackCommanded
    case mockNextTrackCommanded
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
        case .transitionComplete:
            return unchanged(state, reason: .noChange)
        case let .mockScenarioSelect(scenarioID):
            return unchanged(
                state,
                reason: scenarioID.isEmpty ? .noChange : .intentIgnored
            )
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

                return transition(state, reason: .pointerSwipedToCompact) {
                    $0.forceCompactMode = true
                    $0.presentationState = .activity
                    $0.isHovered = false
                }
            case .left:
                guard state.presentationState != .expanded,
                      derivedState.hasAnyActivitySource,
                      state.forceCompactMode else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .pointerSwipedToActivity) {
                    $0.forceCompactMode = false
                    $0.presentationState = .activity
                    $0.isHovered = false
                }
            }
        case let .trackpadSwipe(direction):
            let derivedState = IslandDerivedState.derive(from: state)

            switch direction {
            case .up:
                if state.presentationState == .expanded {
                    return collapseExpanded(
                        state,
                        compactReason: .trackpadSwipedUpToCompact,
                        activityReason: .trackpadSwipedUpToActivity
                    )
                }

                guard derivedState.showAnyActivity else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .trackpadSwipedUpToCompact) {
                    $0.forceCompactMode = true
                    $0.presentationState = .activity
                    $0.isHovered = false
                }
            case .down:
                if state.presentationState != .expanded,
                   derivedState.showAnyActivity {
                    return transition(
                        state,
                        reason: state.primaryMode == .music
                            ? .trackpadSwipedDownToExpandedMusic
                            : .trackpadSwipedDownToExpandedApp
                    ) {
                        $0.presentationState = .expanded
                        $0.isHovered = false
                    }
                }

                guard state.presentationState != .expanded,
                      derivedState.hasAnyActivitySource,
                      state.forceCompactMode else {
                    return unchanged(state, reason: .intentIgnored)
                }

                return transition(state, reason: .trackpadSwipedDownToActivity) {
                    $0.forceCompactMode = false
                    $0.presentationState = .activity
                    $0.isHovered = false
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
            ) { _ in }
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
