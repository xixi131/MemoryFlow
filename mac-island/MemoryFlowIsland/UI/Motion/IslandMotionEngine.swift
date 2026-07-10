import CoreGraphics
import Foundation

struct IslandPresentationSnapshot: Equatable {
    let visualState: IslandVisualState
    let visibleFrame: CGRect?
    let visualScale: CGFloat
    let isAnimating: Bool

    static let idle = IslandPresentationSnapshot(visualState: .compactCollapsed, visibleFrame: nil, visualScale: 1, isAnimating: false)
}

struct IslandShellFrameMotionPlan: Equatable {
    let fromFrame: CGRect?
    let toFrame: CGRect?
    let spring: IslandSpringMotionToken
    let keyframes: IslandKeyframeMotionToken
}

struct IslandShapeMorphMotionPlan: Equatable {
    let fromState: IslandVisualState
    let toState: IslandVisualState
    let duration: TimeInterval
}

struct IslandShadowMotionPlan: Equatable {
    let animation: IslandShadowMotionToken
    let targetOpacity: Double
    let targetRadius: CGFloat
    let targetOffsetY: CGFloat
}

struct IslandContentVisibilityMotionPlan: Equatable {
    let enter: IslandContentMotionToken
    let exit: IslandContentMotionToken
}

struct IslandMotionPlan: Equatable {
    let transitionKind: IslandTransitionKind
    let shellFrame: IslandShellFrameMotionPlan
    let shapeMorph: IslandShapeMorphMotionPlan
    let shadow: IslandShadowMotionPlan
    let content: IslandContentVisibilityMotionPlan
    let contentChoreography: IslandContentChoreographyPlan
    let reduceMotion: Bool
    let isRetargeting: Bool

    var duration: TimeInterval { reduceMotion ? 0 : max(shellFrame.keyframes.duration, shapeMorph.duration) }
}

enum IslandMotionEngine {
    static func plan(
        previous: IslandDerivedState,
        next: IslandDerivedState,
        reason: IslandPresentationTransitionReason,
        presentation: IslandPresentationSnapshot,
        reduceMotion: Bool,
        currentSizingResult: IslandWindowSizingResult? = nil,
        nextSizingResult: IslandWindowSizingResult? = nil
    ) -> IslandMotionPlan {
        let kind = IslandTransitionKind.resolve(previous: previous, next: next, reason: reason)
        let tokens = kind.motionTokens
        let scale = nextSizingResult?.diagnostics.visualScale ?? presentation.visualScale
        let shadow = IslandVisualTokens.shadow.appearance(for: next.visualState, visualScale: scale)
        let instant = IslandKeyframeMotionToken(duration: 0, times: [0, 1], curve: .linear)

        return IslandMotionPlan(
            transitionKind: kind,
            shellFrame: IslandShellFrameMotionPlan(
                fromFrame: presentation.visibleFrame ?? currentSizingResult?.visibleFrame,
                toFrame: nextSizingResult?.visibleFrame,
                spring: tokens.shellSpring,
                keyframes: reduceMotion ? instant : tokens.shellKeyframes
            ),
            shapeMorph: IslandShapeMorphMotionPlan(
                fromState: presentation.isAnimating ? presentation.visualState : previous.visualState,
                toState: next.visualState,
                duration: reduceMotion ? 0 : tokens.pathMorphDuration
            ),
            shadow: IslandShadowMotionPlan(
                animation: reduceMotion ? IslandShadowMotionToken(duration: 0, curve: .linear) : tokens.shadow,
                targetOpacity: shadow.opacity,
                targetRadius: shadow.radius,
                targetOffsetY: shadow.offsetY
            ),
            content: IslandContentVisibilityMotionPlan(enter: tokens.contentEnter, exit: tokens.contentExit),
            contentChoreography: IslandContentChoreographyPlan(
                transitionKind: kind,
                shellDuration: reduceMotion ? 0 : tokens.shellKeyframes.duration,
                enter: tokens.contentEnter,
                exit: tokens.contentExit
            ),
            reduceMotion: reduceMotion,
            isRetargeting: presentation.isAnimating
        )
    }
}
