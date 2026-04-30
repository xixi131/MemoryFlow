import Foundation

struct IslandPreviewLayoutInput: Equatable {
    let visualState: IslandVisualState
    let widthConstraints: IslandWidthConstraints
}

struct IslandPhase5PreviewReducerUpdate: Equatable {
    let previousState: IslandDomainState
    let currentState: IslandDomainState
    let previousDerivedState: IslandDerivedState
    let currentDerivedState: IslandDerivedState
    let reducerResult: IslandPresentationReducerResult

    var previousLayoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: previousDerivedState.visualState,
            widthConstraints: previousDerivedState.widthConstraints
        )
    }

    var currentLayoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: currentDerivedState.visualState,
            widthConstraints: currentDerivedState.widthConstraints
        )
    }
}

struct IslandPhase5PreviewStateContainer: Equatable {
    var domainState: IslandDomainState

    init(initialState: IslandDomainState = .loggedInReviewCompact) {
        self.domainState = initialState
    }

    var derivedState: IslandDerivedState {
        IslandDerivedState.derive(from: domainState)
    }

    var layoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: derivedState.visualState,
            widthConstraints: derivedState.widthConstraints
        )
    }

    mutating func dispatch(intent: IslandInteractionIntent) -> IslandPhase5PreviewReducerUpdate {
        let previousState = domainState
        let previousDerivedState = IslandDerivedState.derive(from: previousState)
        let reducerResult = IslandPresentationReducer.reduce(
            current: previousState,
            intent: intent
        )
        domainState = reducerResult.state

        return IslandPhase5PreviewReducerUpdate(
            previousState: previousState,
            currentState: reducerResult.state,
            previousDerivedState: previousDerivedState,
            currentDerivedState: reducerResult.derivedState,
            reducerResult: reducerResult
        )
    }
}
