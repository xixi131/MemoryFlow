import Foundation

struct IslandPreviewTransitionState: Equatable {
    let currentState: IslandVisualState
    let targetState: IslandVisualState
    let isAnimating: Bool

    static func idle(at state: IslandVisualState) -> IslandPreviewTransitionState {
        IslandPreviewTransitionState(
            currentState: state,
            targetState: state,
            isAnimating: false
        )
    }

    static func animating(
        from currentState: IslandVisualState,
        to targetState: IslandVisualState
    ) -> IslandPreviewTransitionState {
        IslandPreviewTransitionState(
            currentState: currentState,
            targetState: targetState,
            isAnimating: true
        )
    }

    func retargeting(to newTargetState: IslandVisualState) -> IslandPreviewTransitionState {
        IslandPreviewTransitionState(
            currentState: targetState,
            targetState: newTargetState,
            isAnimating: true
        )
    }

    func completed() -> IslandPreviewTransitionState {
        .idle(at: targetState)
    }
}
