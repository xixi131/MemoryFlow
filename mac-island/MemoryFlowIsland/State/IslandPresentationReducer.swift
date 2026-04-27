import Foundation

enum IslandPresentationTransitionReason: String, Codable, Equatable {
    case noChange
    case intentIgnored
}

struct IslandPresentationReducerResult: Codable, Equatable {
    let state: IslandDomainState
    let reason: IslandPresentationTransitionReason
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
            return unchanged(
                state,
                reason: state.presentationState == .expanded ? .noChange : .intentIgnored
            )
        case .hoverEnter,
             .hoverLeave,
             .tap,
             .pointerSwipe,
             .trackpadSwipe,
             .horizontalMusicCommand:
            return unchanged(state, reason: .intentIgnored)
        }
    }

    private static func unchanged(
        _ state: IslandDomainState,
        reason: IslandPresentationTransitionReason
    ) -> IslandPresentationReducerResult {
        IslandPresentationReducerResult(
            state: state,
            reason: reason
        )
    }
}
