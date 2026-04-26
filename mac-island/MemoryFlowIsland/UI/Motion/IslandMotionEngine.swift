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
    let animation: IslandShadowFadeMotionToken
    let targetOpacity: Double
    let targetRadius: CGFloat
    let targetOffsetY: CGFloat
}

struct IslandContentVisibilityMotionPlan: Equatable {
    let visible: IslandPreviewContentVisibilityInput
    let hidden: IslandPreviewContentVisibilityInput
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
            shadow.animation.duration,
            contentVisibility.visible.duration + contentVisibility.visible.delay,
            contentVisibility.hidden.duration + contentVisibility.hidden.delay
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
                animation: tokens.shadowFade,
                targetOpacity: targetShadow.opacity,
                targetRadius: targetShadow.radius,
                targetOffsetY: targetShadow.offsetY
            ),
            contentVisibility: IslandContentVisibilityMotionPlan(
                visible: IslandPreviewContentVisibilityInput(
                    opacity: next == .compactCollapsed ? 0 : 1,
                    blurRadius: tokens.contentEnter.blurRadius,
                    delay: tokens.contentEnter.delay,
                    duration: tokens.contentEnter.duration,
                    curve: tokens.contentEnter.curve
                ),
                hidden: IslandPreviewContentVisibilityInput(
                    opacity: 0,
                    blurRadius: tokens.contentExit.blurRadius,
                    delay: tokens.contentExit.delay,
                    duration: tokens.contentExit.duration,
                    curve: tokens.contentExit.curve
                )
            ),
            isPreviewInteraction: context.isPreviewInteraction,
            isRetargeting: context.isRetargeting
        )
    }
}
