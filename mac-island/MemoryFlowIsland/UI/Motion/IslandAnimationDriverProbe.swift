import CoreGraphics
import Foundation

struct IslandAnimationDriverProbeRow: Equatable {
    let transition: String
    let timestamp: TimeInterval
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isAnimating: Bool
}

enum IslandAnimationDriverProbe {
    @MainActor
    static func validateSampledFrames() throws -> [IslandAnimationDriverProbeRow] {
        try validateShellSpringOwnership()
        try validateAppleSpringPhysics()
        try validateDirectionalSpringProfiles()
        try validateExpandedCollapseRecoveryContinuity()

        let compact = IslandAnimationMetrics(visibleFrame: CGRect(x: 100, y: 900, width: 120, height: 32), visualScale: 1)
        let activity = IslandAnimationMetrics(visibleFrame: CGRect(x: 70, y: 892, width: 180, height: 40), visualScale: 1)
        let expanded = IslandAnimationMetrics(visibleFrame: CGRect(x: -70, y: 612, width: 460, height: 320), visualScale: 1)
        let driver = IslandAnimationDriver(initialMetrics: compact)
        var completions: [String] = []
        var rows: [IslandAnimationDriverProbeRow] = []

        driver.animate(
            to: activity,
            transitionID: "compact-activity",
            duration: 0.56,
            curve: .easeInOut,
            spring: IslandMotionTokens.appleSpring,
            at: 0
        ) {
            completions.append("compact-activity")
        }
        rows.append(row("compact-activity", timestamp: 0, driver: driver))
        driver.advance(at: 0.28)
        rows.append(row("compact-activity", timestamp: 0.28, driver: driver))
        let activityMidpoint = driver.current
        driver.advance(at: 0.56)
        rows.append(row("compact-activity", timestamp: 0.56, driver: driver))

        driver.animate(
            to: expanded,
            transitionID: "activity-expanded",
            duration: 0.56,
            curve: .easeInOut,
            spring: IslandMotionTokens.appleSpring,
            at: 1
        ) {
            completions.append("activity-expanded")
        }
        driver.advance(at: 1.28)
        rows.append(row("activity-expanded", timestamp: 1.28, driver: driver))
        driver.advance(at: 1.56)
        rows.append(row("activity-expanded", timestamp: 1.56, driver: driver))

        driver.animate(
            to: activity,
            transitionID: "expanded-reverse",
            duration: 0.56,
            curve: .easeInOut,
            spring: IslandMotionTokens.appleSpring,
            at: 2
        )
        driver.advance(at: 2.28)
        let reverseStart = driver.current
        let inheritedVelocity = driver.velocity
        driver.animate(
            to: compact,
            transitionID: "reverse-compact",
            duration: 0.56,
            curve: .easeInOut,
            spring: IslandMotionTokens.appleSpring,
            at: 2.28
        ) {
            completions.append("reverse-compact")
        }
        guard driver.current == reverseStart,
              preservesMomentumDirection(from: inheritedVelocity, to: driver.velocity) else {
            throw IslandAnimationDriverProbeError.retargetSnapped
        }
        driver.advance(at: 2.28 + (1.0 / 60.0))
        guard driver.current.visibleFrame.width < reverseStart.visibleFrame.width,
              driver.velocity.size.width < 0 else {
            throw IslandAnimationDriverProbeError.reverseDidNotMoveTowardCompact
        }
        driver.advance(at: 2.56)
        rows.append(row("reverse-compact", timestamp: 2.56, driver: driver))
        driver.advance(at: 2.84)
        rows.append(row("reverse-compact", timestamp: 2.84, driver: driver))

        let activityOvershootLimit = activity.visibleFrame.width +
            ((activity.visibleFrame.width - compact.visibleFrame.width) * 0.10)
        let expandedOvershootLimit = expanded.visibleFrame.width +
            ((expanded.visibleFrame.width - activity.visibleFrame.width) * 0.10)
        guard activityMidpoint.visibleFrame.width > activity.visibleFrame.width,
              activityMidpoint.visibleFrame.width < activityOvershootLimit,
              rows[3].width > expanded.visibleFrame.width,
              rows[3].width < expandedOvershootLimit,
              driver.current == compact,
              completions == ["compact-activity", "activity-expanded", "reverse-compact"] else {
            throw IslandAnimationDriverProbeError.unexpectedSamples
        }
        try validateRapidRetargeting(
            compact: compact,
            hover: IslandAnimationMetrics(
                visibleFrame: CGRect(x: 94, y: 898, width: 132, height: 36),
                visualScale: 1.02
            ),
            activity: activity,
            expanded: expanded
        )
        return rows
    }

    private static func validateShellSpringOwnership() throws {
        let forward = IslandShellSpringTarget.resolve(
            state: .activityCollapsed,
            presentationShapeMetrics: nil
        )
        let reverse = IslandShellSpringTarget.resolve(
            state: .compactCollapsed,
            presentationShapeMetrics: nil
        )
        guard forward == .swiftUI(.activityCollapsed),
              reverse == .swiftUI(.compactCollapsed),
              forward != reverse else {
            throw IslandAnimationDriverProbeError.shellSpringRetargetWasStale
        }

        let sampledMetrics = IslandShapeMetrics.resolve(
            for: .activityCollapsed,
            visualScale: 1
        )
        let sampledForward = IslandShellSpringTarget.resolve(
            state: .activityCollapsed,
            presentationShapeMetrics: sampledMetrics
        )
        let sampledReverse = IslandShellSpringTarget.resolve(
            state: .compactCollapsed,
            presentationShapeMetrics: sampledMetrics
        )
        guard sampledForward == .displayLinkOwned,
              sampledReverse == .displayLinkOwned else {
            throw IslandAnimationDriverProbeError.displayLinkSamplesWouldBeDoubleEased
        }
    }

    private static func validateAppleSpringPhysics() throws {
        let token = IslandMotionTokens.appleSpring
        let naturalFrequency = sqrt(token.stiffness / token.mass)
        let response = (2 * CGFloat.pi) / naturalFrequency
        let dampingFraction = token.damping / (2 * sqrt(token.stiffness * token.mass))
        guard abs(response - AppleSpringMotion.response) < 0.0001,
              abs(dampingFraction - AppleSpringMotion.dampingFraction) < 0.0001,
              dampingFraction < 1 else {
            throw IslandAnimationDriverProbeError.invalidAppleSpringPhysics
        }
    }

    private static func validateDirectionalSpringProfiles() throws {
        let compact = IslandDerivedState.derive(from: .loggedInReviewCompact)
        let expanded = IslandDerivedState.derive(from: .expandedAppReview)
        let openKind = IslandTransitionKind.resolve(
            previous: compact,
            next: expanded,
            reason: .tapExpandedToApp
        )
        let collapse = IslandMotionTokens.profile(for: .expandedToCompact).shellSpring
        let collapseDampingFraction = collapse.damping / (2 * sqrt(collapse.stiffness * collapse.mass))

        guard openKind == .compactToExpanded,
              openKind.motionTokens.shellSpring == IslandMotionTokens.appleSpring,
              openKind.motionTokens.shellKeyframes.duration == IslandMotionTokens.activityOpenDuration,
              collapseDampingFraction > AppleSpringMotion.dampingFraction,
              collapseDampingFraction < 1 else {
            throw IslandAnimationDriverProbeError.invalidDirectionalSpringProfiles
        }
    }

    @MainActor
    private static func validateExpandedCollapseRecoveryContinuity() throws {
        let expanded = IslandAnimationMetrics(
            visibleFrame: CGRect(x: 526, y: 662, width: 460, height: 320),
            visualScale: 1
        )
        let compact = IslandAnimationMetrics(
            visibleFrame: CGRect(x: 651, y: 950, width: 210, height: 36),
            visualScale: 1
        )
        let activity = IslandAnimationMetrics(
            visibleFrame: CGRect(x: 613, y: 950, width: 286, height: 36),
            visualScale: 1
        )
        let driver = IslandAnimationDriver(initialMetrics: expanded)
        let collapseDuration = IslandMotionTokens.expandedActivityRecoveryCollapseDuration

        driver.animate(
            to: compact,
            transitionID: "expanded-collapse",
            duration: collapseDuration,
            curve: .easeInOut,
            spring: nil,
            at: 0
        )
        driver.advance(at: collapseDuration * 0.25)
        let quarterWidth = driver.current.visibleFrame.width
        driver.advance(at: collapseDuration * 0.5)
        let midpointWidth = driver.current.visibleFrame.width
        driver.advance(at: collapseDuration * 0.75)
        let threeQuarterWidth = driver.current.visibleFrame.width
        driver.advance(at: collapseDuration)

        guard quarterWidth < expanded.visibleFrame.width,
              midpointWidth < quarterWidth,
              threeQuarterWidth < midpointWidth,
              driver.current == compact,
              driver.hasCompleted,
              driver.velocity == .zero else {
            throw IslandAnimationDriverProbeError.expandedRecoverySettledBeforeHandoff
        }

        driver.animate(
            to: activity,
            transitionID: "compact-activity-recovery",
            duration: IslandMotionTokens.expandedActivityRecoveryOpenDuration,
            curve: .easeInOut,
            spring: IslandMotionTokens.appleSpring,
            at: collapseDuration
        )

        guard driver.current == compact,
              driver.isAnimating,
              driver.velocity.size.width == 0 else {
            throw IslandAnimationDriverProbeError.expandedRecoveryHandoffSnapped
        }

        driver.advance(at: collapseDuration + (1.0 / 60.0))
        let firstFrameDelta = driver.current.visibleFrame.width - compact.visibleFrame.width
        guard firstFrameDelta > 0.0001,
              firstFrameDelta <= 32,
              driver.velocity.size.width > 0 else {
            throw IslandAnimationDriverProbeError.expandedRecoveryLostMomentum
        }
    }

    @MainActor
    private static func validateRapidRetargeting(
        compact: IslandAnimationMetrics,
        hover: IslandAnimationMetrics,
        activity: IslandAnimationMetrics,
        expanded: IslandAnimationMetrics
    ) throws {
        let driver = IslandAnimationDriver(initialMetrics: compact)
        var completions: [String] = []

        driver.animate(to: hover, transitionID: "hover", duration: 0.22, curve: .easeInOut, spring: IslandMotionTokens.appleSpring, at: 0) {
            completions.append("hover")
        }
        driver.advance(at: 0.06)
        let hoverPresentation = driver.current
        let hoverVelocity = driver.velocity

        driver.animate(to: activity, transitionID: "activity", duration: 0.56, curve: .easeInOut, spring: IslandMotionTokens.appleSpring, at: 0.06) {
            completions.append("activity")
        }
        guard driver.current == hoverPresentation,
              preservesMomentumDirection(from: hoverVelocity, to: driver.velocity) else {
            throw IslandAnimationDriverProbeError.velocityWasNotSeeded
        }

        driver.advance(at: 0.12)
        driver.animate(to: expanded, transitionID: "expanded", duration: 0.56, curve: .easeInOut, spring: IslandMotionTokens.appleSpring, at: 0.12) {
            completions.append("expanded")
        }
        driver.advance(at: 0.18)
        driver.animate(to: compact, transitionID: "compact", duration: 0.56, curve: .easeInOut, spring: IslandMotionTokens.appleSpring, at: 0.18) {
            completions.append("compact")
        }

        // A delegate callback from the superseded expanded animation must be ignored.
        guard driver.complete(transitionID: "expanded") == false,
              driver.transitionID == "compact" else {
            throw IslandAnimationDriverProbeError.staleCompletionAccepted
        }

        var previousWidth = driver.current.visibleFrame.width
        for frame in 1...34 {
            driver.advance(at: 0.18 + Double(frame) / 60)
            let widthDelta = abs(driver.current.visibleFrame.width - previousWidth)
            guard widthDelta <= 32 else {
                throw IslandAnimationDriverProbeError.unboundedFrameDelta(widthDelta)
            }
            previousWidth = driver.current.visibleFrame.width
        }

        var state = IslandDomainState.loggedInReviewCompact
        state = IslandPresentationReducer.reduce(current: state, intent: .pointerSwipe(.right)).state
        let staleCompletion = IslandPresentationReducer.reduce(
            current: state,
            intent: .transitionComplete(IslandTransitionLockIdentifier.modeSwitchLock)
        )
        guard staleCompletion.state == state else {
            throw IslandAnimationDriverProbeError.staleReducerCompletionAccepted
        }

        guard driver.current == compact,
              completions == ["compact"] else {
            throw IslandAnimationDriverProbeError.rapidSequenceDidNotConverge
        }
    }

    @MainActor
    private static func row(_ transition: String, timestamp: TimeInterval, driver: IslandAnimationDriver) -> IslandAnimationDriverProbeRow {
        IslandAnimationDriverProbeRow(
            transition: transition,
            timestamp: timestamp,
            progress: driver.progress,
            width: driver.current.visibleFrame.width,
            height: driver.current.visibleFrame.height,
            isAnimating: driver.isAnimating
        )
    }

    private static func preservesMomentumDirection(
        from source: IslandAnimationVelocity,
        to retargeted: IslandAnimationVelocity
    ) -> Bool {
        func preserves(_ source: CGFloat, _ retargeted: CGFloat) -> Bool {
            if abs(source) < 0.0001 { return abs(retargeted) < 0.0001 }
            return source * retargeted > 0
        }

        return preserves(source.origin.x, retargeted.origin.x) &&
            preserves(source.origin.y, retargeted.origin.y) &&
            preserves(source.size.width, retargeted.size.width) &&
            preserves(source.size.height, retargeted.size.height) &&
            preserves(source.visualScale, retargeted.visualScale)
    }
}

enum IslandAnimationDriverProbeError: Error, CustomStringConvertible {
    case invalidAppleSpringPhysics
    case invalidDirectionalSpringProfiles
    case shellSpringRetargetWasStale
    case displayLinkSamplesWouldBeDoubleEased
    case retargetSnapped
    case reverseDidNotMoveTowardCompact
    case velocityWasNotSeeded
    case staleCompletionAccepted
    case staleReducerCompletionAccepted
    case unboundedFrameDelta(CGFloat)
    case rapidSequenceDidNotConverge
    case expandedRecoverySettledBeforeHandoff
    case expandedRecoveryHandoffSnapped
    case expandedRecoveryLostMomentum
    case unexpectedSamples

    var description: String {
        switch self {
        case .invalidAppleSpringPhysics: return "Shell motion is not using the shared 0.35/0.70 underdamped spring model."
        case .invalidDirectionalSpringProfiles: return "Direct compact expansion or the reduced-overshoot collapse spring profile is invalid."
        case .shellSpringRetargetWasStale: return "SwiftUI-owned shell spring target did not follow the forward/reverse state sequence."
        case .displayLinkSamplesWouldBeDoubleEased: return "Display-link-owned shell samples changed the SwiftUI spring target."
        case .retargetSnapped: return "Retargeting did not start from live presentation metrics."
        case .reverseDidNotMoveTowardCompact: return "Reverse transition did not preserve a negative width velocity."
        case .velocityWasNotSeeded: return "Retargeting did not retain the sampled presentation velocity."
        case .staleCompletionAccepted: return "A superseded animation completion was accepted."
        case .staleReducerCompletionAccepted: return "A stale reducer completion changed the current transition state."
        case let .unboundedFrameDelta(delta): return "Rapid retarget frame delta exceeded the 32pt bound: \(delta)."
        case .rapidSequenceDidNotConverge: return "Rapid hover, activity, expanded, compact sequence did not converge."
        case .expandedRecoverySettledBeforeHandoff: return "Expanded collapse reached a settled compact frame before the activity recovery handoff."
        case .expandedRecoveryHandoffSnapped: return "Expanded collapse recovery did not retarget from the live presentation frame and velocity."
        case .expandedRecoveryLostMomentum: return "Expanded collapse recovery did not produce a continuous bounded frame after the live-velocity handoff."
        case .unexpectedSamples: return "Animation sample sequence did not reach the expected presentation metrics."
        }
    }
}
