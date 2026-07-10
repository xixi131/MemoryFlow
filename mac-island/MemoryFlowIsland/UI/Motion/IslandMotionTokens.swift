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

struct IslandContentMotionToken: Equatable {
    let duration: TimeInterval
    let delay: TimeInterval
    let blurRadius: CGFloat
    let curve: IslandMotionTimingCurve
}

struct IslandShadowMotionToken: Equatable {
    let duration: TimeInterval
    let curve: IslandMotionTimingCurve
}

struct IslandShellWidthKeyframe: Equatable {
    let time: Double
    let width: CGFloat
}

struct IslandMotionTokenSet: Equatable {
    let shellSpring: IslandSpringMotionToken
    let shellKeyframes: IslandKeyframeMotionToken
    let pathMorphDuration: TimeInterval
    let contentEnter: IslandContentMotionToken
    let contentExit: IslandContentMotionToken
    let shadow: IslandShadowMotionToken
}

enum IslandMotionTokens {
    // These parity values are traced from the Windows DynamicIslandWidget baseline.
    static let windowsBaselineSpring = IslandSpringMotionToken(stiffness: 280, damping: 30, mass: 1.2)
    static let activityOpenDuration: TimeInterval = 0.56
    static let activityCollapseDuration: TimeInterval = 0.85
    static let activityOpenTimes: [Double] = [0, 0.2, 0.34, 1]
    static let activityCollapseTimes: [Double] = [0, 0.45, 0.55, 1]
    static let activityCollapseMidWidth: CGFloat = 155
    static let activityCollapseCompactContentDelay = activityCollapseDuration * activityCollapseTimes[2]
    static let activityContentEnterDelay: TimeInterval = 0.10
    static let activityContentEnterDuration: TimeInterval = 0.26
    static let activityContentEnterBlur: CGFloat = 4
    static let modeSwitchCompactDuration: TimeInterval = 0.32
    static let modeSwitchReopenDelay: TimeInterval = 0.07
    static let hoverDuration: TimeInterval = 0.22

    static func profile(for kind: IslandTransitionKind) -> IslandMotionTokenSet {
        switch kind {
        case .hoverEnter, .hoverLeave:
            return profile(duration: hoverDuration, times: [0, 1], enter: 0.12, exit: 0.12)
        case .compactToActivity, .reminderOpen, .musicTakeover:
            return profile(
                duration: activityOpenDuration,
                times: activityOpenTimes,
                enter: activityContentEnterDuration,
                enterDelay: activityContentEnterDelay,
                exit: 0.15
            )
        case .activityToCompact, .expandedToCompact, .reminderRecover:
            return profile(duration: activityCollapseDuration, times: activityCollapseTimes, enter: 0.15, exit: 0.15)
        case .activityToExpanded, .expandedToActivity:
            return profile(duration: activityOpenDuration, times: activityOpenTimes, enter: 0.30, exit: 0.15)
        case .modeSwitch:
            return profile(
                duration: modeSwitchCompactDuration + modeSwitchReopenDelay + activityOpenDuration,
                times: [0, 0.32 / 0.95, 0.39 / 0.95, 1],
                enter: activityContentEnterDuration,
                enterDelay: modeSwitchCompactDuration + modeSwitchReopenDelay + activityContentEnterDelay,
                exit: 0.15
            )
        case .defaultProfile:
            return profile(duration: 0.18, times: [0, 1], enter: 0.12, exit: 0.12)
        }
    }

    static func activityCollapseFrames(
        fromWidth: CGFloat,
        compactWidth: CGFloat
    ) -> [IslandShellWidthKeyframe] {
        let midWidth = max(activityCollapseMidWidth, compactWidth)
        return zip(activityCollapseTimes, [fromWidth, midWidth, midWidth, compactWidth]).map {
            IslandShellWidthKeyframe(time: $0.0, width: $0.1)
        }
    }

    private static func profile(
        duration: TimeInterval,
        times: [Double],
        enter: TimeInterval,
        enterDelay: TimeInterval = 0,
        exit: TimeInterval
    ) -> IslandMotionTokenSet {
        IslandMotionTokenSet(
            shellSpring: windowsBaselineSpring,
            shellKeyframes: IslandKeyframeMotionToken(duration: duration, times: times, curve: .easeInOut),
            pathMorphDuration: min(duration, 0.40),
            contentEnter: IslandContentMotionToken(duration: enter, delay: enterDelay, blurRadius: activityContentEnterBlur, curve: .easeOut),
            contentExit: IslandContentMotionToken(duration: exit, delay: 0, blurRadius: 5, curve: .easeOut),
            shadow: IslandShadowMotionToken(duration: min(duration, 0.26), curve: .easeOut)
        )
    }
}
