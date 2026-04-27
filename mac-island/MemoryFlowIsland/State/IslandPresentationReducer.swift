import Foundation

enum IslandPresentationTransitionReason: String, Codable, Equatable {
    case noChange
    case intentIgnored
    case hoverEntered
    case hoverLeft
    case tapExpandedToApp
    case tapExpandedToMusic
    case tapCollapsedToCompact
    case tapCollapsedToActivity
    case outsideCollapsedToCompact
    case outsideCollapsedToActivity
}

struct IslandPresentationReducerResult: Codable, Equatable {
    let state: IslandDomainState
    let reason: IslandPresentationTransitionReason

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
        case .pointerSwipe,
             .trackpadSwipe,
             .horizontalMusicCommand:
            return unchanged(state, reason: .intentIgnored)
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
        mutate: (inout IslandDomainState) -> Void
    ) -> IslandPresentationReducerResult {
        var nextState = state
        mutate(&nextState)

        return IslandPresentationReducerResult(
            state: nextState,
            reason: reason
        )
    }
}
