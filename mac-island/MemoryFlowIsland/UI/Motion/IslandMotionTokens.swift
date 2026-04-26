import CoreGraphics
import Foundation

enum IslandMotionTimingCurve: String, Equatable {
    case easeInOut
    case easeOut
    case linear
}

struct IslandSpringMotionToken: Equatable {
    let stiffness: CGFloat
    let damping: CGFloat
    let mass: CGFloat
}

struct IslandKeyframeMotionToken: Equatable {
    let duration: TimeInterval
    let times: [Double]
    let curve: IslandMotionTimingCurve
}

struct IslandFadeMotionToken: Equatable {
    let duration: TimeInterval
    let delay: TimeInterval
    let blurRadius: CGFloat
    let curve: IslandMotionTimingCurve
}

struct IslandShadowFadeMotionToken: Equatable {
    let duration: TimeInterval
    let curve: IslandMotionTimingCurve
}

struct IslandMotionTokenSet: Equatable {
    let shellSpring: IslandSpringMotionToken
    let shellKeyframes: IslandKeyframeMotionToken
    let pathMorphDuration: TimeInterval
    let contentEnter: IslandFadeMotionToken
    let contentExit: IslandFadeMotionToken
    let shadowFade: IslandShadowFadeMotionToken
}

enum IslandMotionTokens {
    static let windowsBaselineSpring = IslandSpringMotionToken(
        stiffness: 280,
        damping: 30,
        mass: 1.2
    )

    static let activityOpenDuration: TimeInterval = 0.56
    static let activityCollapseDuration: TimeInterval = 0.85
    static let activityCollapseSegmentedTimes: [Double] = [0, 0.45, 0.55, 1]
    static let activityOpenSegmentedTimes: [Double] = [0, 0.2, 0.34, 1]
    static let activityOpenContentDelay: TimeInterval = 0.10
    static let activityOpenContentDuration: TimeInterval = 0.26
    static let expandedContentFadeInDuration: TimeInterval = 0.30
    static let expandedContentFadeOutDuration: TimeInterval = 0.15
    static let shellPathMorphDuration: TimeInterval = 0.40
    static let shadowFadeDuration: TimeInterval = 0.26

    static func profile(for transitionKind: IslandTransitionKind) -> IslandMotionTokenSet {
        switch transitionKind {
        case .compactToActivity, .activityToExpanded:
            return IslandMotionTokenSet(
                shellSpring: windowsBaselineSpring,
                shellKeyframes: IslandKeyframeMotionToken(
                    duration: activityOpenDuration,
                    times: activityOpenSegmentedTimes,
                    curve: .easeInOut
                ),
                pathMorphDuration: shellPathMorphDuration,
                contentEnter: IslandFadeMotionToken(
                    duration: activityOpenContentDuration,
                    delay: activityOpenContentDelay,
                    blurRadius: 4,
                    curve: .easeOut
                ),
                contentExit: IslandFadeMotionToken(
                    duration: expandedContentFadeOutDuration,
                    delay: 0,
                    blurRadius: 5,
                    curve: .easeOut
                ),
                shadowFade: IslandShadowFadeMotionToken(
                    duration: shadowFadeDuration,
                    curve: .easeOut
                )
            )
        case .activityToCompact, .expandedToActivity, .expandedToCompact:
            return IslandMotionTokenSet(
                shellSpring: windowsBaselineSpring,
                shellKeyframes: IslandKeyframeMotionToken(
                    duration: activityCollapseDuration,
                    times: activityCollapseSegmentedTimes,
                    curve: .easeInOut
                ),
                pathMorphDuration: shellPathMorphDuration,
                contentEnter: IslandFadeMotionToken(
                    duration: expandedContentFadeOutDuration,
                    delay: 0,
                    blurRadius: 0,
                    curve: .easeOut
                ),
                contentExit: IslandFadeMotionToken(
                    duration: expandedContentFadeOutDuration,
                    delay: 0,
                    blurRadius: 5,
                    curve: .easeOut
                ),
                shadowFade: IslandShadowFadeMotionToken(
                    duration: shadowFadeDuration,
                    curve: .easeOut
                )
            )
        case .hoverEnter, .hoverLeave:
            return IslandMotionTokenSet(
                shellSpring: windowsBaselineSpring,
                shellKeyframes: IslandKeyframeMotionToken(
                    duration: 0.22,
                    times: [0, 1],
                    curve: .easeOut
                ),
                pathMorphDuration: 0.22,
                contentEnter: IslandFadeMotionToken(
                    duration: 0.12,
                    delay: 0,
                    blurRadius: 0,
                    curve: .easeOut
                ),
                contentExit: IslandFadeMotionToken(
                    duration: 0.12,
                    delay: 0,
                    blurRadius: 0,
                    curve: .easeOut
                ),
                shadowFade: IslandShadowFadeMotionToken(
                    duration: shadowFadeDuration,
                    curve: .easeOut
                )
            )
        case .defaultProfile:
            return IslandMotionTokenSet(
                shellSpring: windowsBaselineSpring,
                shellKeyframes: IslandKeyframeMotionToken(
                    duration: 0.18,
                    times: [0, 1],
                    curve: .easeOut
                ),
                pathMorphDuration: 0.18,
                contentEnter: IslandFadeMotionToken(
                    duration: 0.12,
                    delay: 0,
                    blurRadius: 0,
                    curve: .easeOut
                ),
                contentExit: IslandFadeMotionToken(
                    duration: 0.12,
                    delay: 0,
                    blurRadius: 0,
                    curve: .easeOut
                ),
                shadowFade: IslandShadowFadeMotionToken(
                    duration: shadowFadeDuration,
                    curve: .easeOut
                )
            )
        }
    }
}
