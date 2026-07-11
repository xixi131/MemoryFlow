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

        let compact = IslandAnimationMetrics(visibleFrame: CGRect(x: 100, y: 900, width: 120, height: 32), visualScale: 1)
        let activity = IslandAnimationMetrics(visibleFrame: CGRect(x: 70, y: 892, width: 180, height: 40), visualScale: 1)
        let expanded = IslandAnimationMetrics(visibleFrame: CGRect(x: -70, y: 612, width: 460, height: 320), visualScale: 1)
        let driver = IslandAnimationDriver(initialMetrics: compact)
        var completions: [String] = []
        var rows: [IslandAnimationDriverProbeRow] = []

        driver.animate(to: activity, transitionID: "compact-activity", duration: 0.56, curve: .easeInOut, at: 0) {
            completions.append("compact-activity")
        }
        rows.append(row("compact-activity", timestamp: 0, driver: driver))
        driver.advance(at: 0.28)
        rows.append(row("compact-activity", timestamp: 0.28, driver: driver))
        let activityMidpoint = driver.current
        driver.advance(at: 0.56)
        rows.append(row("compact-activity", timestamp: 0.56, driver: driver))

        driver.animate(to: expanded, transitionID: "activity-expanded", duration: 0.56, curve: .easeInOut, at: 1) {
            completions.append("activity-expanded")
        }
        driver.advance(at: 1.28)
        rows.append(row("activity-expanded", timestamp: 1.28, driver: driver))
        driver.advance(at: 1.56)
        rows.append(row("activity-expanded", timestamp: 1.56, driver: driver))

        driver.animate(to: activity, transitionID: "expanded-reverse", duration: 0.56, curve: .easeInOut, at: 2)
        driver.advance(at: 2.28)
        let reverseStart = driver.current
        driver.animate(to: compact, transitionID: "reverse-compact", duration: 0.56, curve: .easeInOut, at: 2.28) {
            completions.append("reverse-compact")
        }
        guard driver.current == reverseStart else { throw IslandAnimationDriverProbeError.retargetSnapped }
        driver.advance(at: 2.56)
        rows.append(row("reverse-compact", timestamp: 2.56, driver: driver))
        guard driver.current.visibleFrame.width < reverseStart.visibleFrame.width,
              driver.velocity.size.width < 0 else {
            throw IslandAnimationDriverProbeError.reverseDidNotMoveTowardCompact
        }
        driver.advance(at: 2.84)
        rows.append(row("reverse-compact", timestamp: 2.84, driver: driver))

        guard activityMidpoint.visibleFrame.width > compact.visibleFrame.width,
              activityMidpoint.visibleFrame.width < activity.visibleFrame.width,
              rows[3].width > activity.visibleFrame.width,
              rows[3].width < expanded.visibleFrame.width,
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

    @MainActor
    private static func validateRapidRetargeting(
        compact: IslandAnimationMetrics,
        hover: IslandAnimationMetrics,
        activity: IslandAnimationMetrics,
        expanded: IslandAnimationMetrics
    ) throws {
        let driver = IslandAnimationDriver(initialMetrics: compact)
        var completions: [String] = []

        driver.animate(to: hover, transitionID: "hover", duration: 0.22, curve: .easeInOut, at: 0) {
            completions.append("hover")
        }
        driver.advance(at: 0.06)
        let hoverPresentation = driver.current
        let hoverVelocity = driver.velocity

        driver.animate(to: activity, transitionID: "activity", duration: 0.56, curve: .easeInOut, at: 0.06) {
            completions.append("activity")
        }
        guard driver.current == hoverPresentation,
              driver.velocity.size.width == hoverVelocity.size.width,
              driver.velocity.origin.x == hoverVelocity.origin.x else {
            throw IslandAnimationDriverProbeError.velocityWasNotSeeded
        }

        driver.advance(at: 0.12)
        driver.animate(to: expanded, transitionID: "expanded", duration: 0.56, curve: .easeInOut, at: 0.12) {
            completions.append("expanded")
        }
        driver.advance(at: 0.18)
        driver.animate(to: compact, transitionID: "compact", duration: 0.56, curve: .easeInOut, at: 0.18) {
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
}

enum IslandAnimationDriverProbeError: Error, CustomStringConvertible {
    case shellSpringRetargetWasStale
    case displayLinkSamplesWouldBeDoubleEased
    case retargetSnapped
    case reverseDidNotMoveTowardCompact
    case velocityWasNotSeeded
    case staleCompletionAccepted
    case staleReducerCompletionAccepted
    case unboundedFrameDelta(CGFloat)
    case rapidSequenceDidNotConverge
    case unexpectedSamples

    var description: String {
        switch self {
        case .shellSpringRetargetWasStale: return "SwiftUI-owned shell spring target did not follow the forward/reverse state sequence."
        case .displayLinkSamplesWouldBeDoubleEased: return "Display-link-owned shell samples changed the SwiftUI spring target."
        case .retargetSnapped: return "Retargeting did not start from live presentation metrics."
        case .reverseDidNotMoveTowardCompact: return "Reverse transition did not preserve a negative width velocity."
        case .velocityWasNotSeeded: return "Retargeting did not retain the sampled presentation velocity."
        case .staleCompletionAccepted: return "A superseded animation completion was accepted."
        case .staleReducerCompletionAccepted: return "A stale reducer completion changed the current transition state."
        case let .unboundedFrameDelta(delta): return "Rapid retarget frame delta exceeded the 32pt bound: \(delta)."
        case .rapidSequenceDidNotConverge: return "Rapid hover, activity, expanded, compact sequence did not converge."
        case .unexpectedSamples: return "Animation sample sequence did not reach the expected presentation metrics."
        }
    }
}
