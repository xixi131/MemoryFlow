import CoreGraphics
import Foundation

struct IslandMotionContext: Equatable {
    let currentSizingResult: IslandWindowSizingResult?
    let nextSizingResult: IslandWindowSizingResult?
    let isPreviewInteraction: Bool
    let isRetargeting: Bool
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
    let fadeDuration: TimeInterval
    let targetOpacity: Double
    let targetRadius: CGFloat
    let targetOffsetY: CGFloat
}

struct IslandContentVisibilityMotionPlan: Equatable {
    let enter: IslandFadeMotionToken
    let exit: IslandFadeMotionToken
}

struct IslandMotionPlan: Equatable {
    let transitionKind: IslandTransitionKind
    let shellFrame: IslandShellFrameMotionPlan
    let shapeMorph: IslandShapeMorphMotionPlan
    let shadow: IslandShadowMotionPlan
    let contentVisibility: IslandContentVisibilityMotionPlan
    let isPreviewInteraction: Bool
    let isRetargeting: Bool

    var duration: TimeInterval {
        max(
            shellFrame.keyframes.duration,
            shapeMorph.duration,
            shadow.fadeDuration,
            contentVisibility.enter.duration + contentVisibility.enter.delay,
            contentVisibility.exit.duration + contentVisibility.exit.delay
        )
    }
}

enum IslandMotionEngine {
    static func plan(
        previous: IslandVisualState,
        next: IslandVisualState,
        context: IslandMotionContext
    ) -> IslandMotionPlan {
        let transitionKind = IslandTransitionKind.resolve(previous: previous, next: next)
        let tokens = transitionKind.motionTokens
        let targetVisualScale = context.nextSizingResult?.diagnostics.visualScale
            ?? context.currentSizingResult?.diagnostics.visualScale
            ?? 1
        let targetShadow = IslandVisualTokens.shadow.appearance(
            for: next,
            visualScale: targetVisualScale
        )

        return IslandMotionPlan(
            transitionKind: transitionKind,
            shellFrame: IslandShellFrameMotionPlan(
                fromFrame: context.currentSizingResult?.visibleFrame,
                toFrame: context.nextSizingResult?.visibleFrame,
                spring: tokens.shellSpring,
                keyframes: tokens.shellKeyframes
            ),
            shapeMorph: IslandShapeMorphMotionPlan(
                fromState: previous,
                toState: next,
                duration: tokens.pathMorphDuration
            ),
            shadow: IslandShadowMotionPlan(
                fadeDuration: tokens.shadowFadeDuration,
                targetOpacity: targetShadow.opacity,
                targetRadius: targetShadow.radius,
                targetOffsetY: targetShadow.offsetY
            ),
            contentVisibility: IslandContentVisibilityMotionPlan(
                enter: tokens.contentEnter,
                exit: tokens.contentExit
            ),
            isPreviewInteraction: context.isPreviewInteraction,
            isRetargeting: context.isRetargeting
        )
    }
}
