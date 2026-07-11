import CoreGraphics
import Foundation

/// Geometry values sampled by the shell animator. These are deliberately state-free so
/// geometry can be retargeted without waiting for a reducer or view transaction.
struct IslandAnimationMetrics: Equatable {
    var visibleFrame: CGRect
    var visualScale: CGFloat

    static func interpolate(
        from start: IslandAnimationMetrics,
        to end: IslandAnimationMetrics,
        progress: CGFloat
    ) -> IslandAnimationMetrics {
        let progress = min(max(progress, 0), 1)
        return IslandAnimationMetrics(
            visibleFrame: CGRect(
                x: start.visibleFrame.origin.x + (end.visibleFrame.origin.x - start.visibleFrame.origin.x) * progress,
                y: start.visibleFrame.origin.y + (end.visibleFrame.origin.y - start.visibleFrame.origin.y) * progress,
                width: start.visibleFrame.width + (end.visibleFrame.width - start.visibleFrame.width) * progress,
                height: start.visibleFrame.height + (end.visibleFrame.height - start.visibleFrame.height) * progress
            ),
            visualScale: start.visualScale + (end.visualScale - start.visualScale) * progress
        )
    }
}

struct IslandAnimationVelocity: Equatable {
    var origin: CGPoint
    var size: CGSize
    var visualScale: CGFloat

    static let zero = IslandAnimationVelocity(origin: .zero, size: .zero, visualScale: 0)
}

enum IslandAnimationPhase: Equatable {
    case idle
    case running
    case completed
}

struct IslandAnimationSample: Equatable {
    let current: IslandAnimationMetrics
    let target: IslandAnimationMetrics
    let progress: CGFloat
    let phase: IslandAnimationPhase
    let velocity: IslandAnimationVelocity
    let transitionID: String?
    let hasCompleted: Bool
}

/// Main-thread animation state driven by an external display-linked clock.
///
/// `advance(at:)` accepts monotonic Core Animation media time. The window and shape
/// owners can therefore apply the exact same sampled metrics without using timers.
@MainActor
final class IslandAnimationDriver {
    typealias Completion = () -> Void

    private(set) var current: IslandAnimationMetrics
    private(set) var target: IslandAnimationMetrics
    private(set) var progress: CGFloat = 1
    private(set) var phase: IslandAnimationPhase = .idle
    private(set) var velocity: IslandAnimationVelocity = .zero
    private(set) var transitionID: String?
    private(set) var hasCompleted = false

    private var start: IslandAnimationMetrics
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var curve: IslandMotionTimingCurve = .linear
    private var spring: IslandSpringMotionToken?
    private var startVelocity: IslandAnimationVelocity = .zero
    private var completion: Completion?

    init(initialMetrics: IslandAnimationMetrics) {
        current = initialMetrics
        target = initialMetrics
        start = initialMetrics
    }

    var isAnimating: Bool {
        phase == .running
    }

    var sample: IslandAnimationSample {
        IslandAnimationSample(
            current: current,
            target: target,
            progress: progress,
            phase: phase,
            velocity: velocity,
            transitionID: transitionID,
            hasCompleted: hasCompleted
        )
    }

    func reset(to metrics: IslandAnimationMetrics) {
        current = metrics
        target = metrics
        start = metrics
        progress = 1
        phase = .idle
        velocity = .zero
        transitionID = nil
        hasCompleted = false
        completion = nil
        spring = nil
    }

    /// Starts, or retargets, an animation. A retarget captures the presentation
    /// snapshot and its velocity before installing the replacement target. The seed
    /// is bounded relative to the new distance so rapid reversals remain stable.
    func animate(
        to target: IslandAnimationMetrics,
        transitionID: String,
        duration: TimeInterval,
        curve: IslandMotionTimingCurve,
        spring: IslandSpringMotionToken? = nil,
        at timestamp: TimeInterval,
        completion: Completion? = nil
    ) {
        let presentationVelocity: IslandAnimationVelocity
        if isAnimating {
            advance(at: timestamp)
            presentationVelocity = velocity
        } else {
            presentationVelocity = .zero
        }

        start = current
        self.target = target
        self.transitionID = transitionID
        self.duration = max(duration, 0)
        self.curve = curve
        self.spring = spring
        startTime = timestamp
        self.completion = completion
        hasCompleted = false
        startVelocity = boundedVelocity(
            presentationVelocity,
            from: start,
            to: target,
            duration: self.duration
        )
        velocity = startVelocity

        guard self.duration > 0, start != target else {
            current = target
            progress = 1
            finish(expectedTransitionID: transitionID)
            return
        }

        progress = 0
        phase = .running
    }

    /// Called by a display link with Core Animation's monotonic media timestamp.
    func advance(at timestamp: TimeInterval) {
        guard isAnimating else { return }

        let elapsed = max(timestamp - startTime, 0)
        let normalized = min(CGFloat(elapsed / duration), 1)
        current = interpolatedMetrics(progress: normalized)
        progress = normalized
        velocity = interpolatedVelocity(progress: normalized)

        if normalized >= 1 {
            current = target
            finish(expectedTransitionID: transitionID)
        }
    }

    /// Allows a Core Animation completion delegate to report completion without an
    /// older animation unlocking a newer reducer transition.
    @discardableResult
    func complete(transitionID: String) -> Bool {
        guard isAnimating, self.transitionID == transitionID else { return false }
        current = target
        progress = 1
        finish(expectedTransitionID: transitionID)
        return true
    }

    private func finish(expectedTransitionID: String?) {
        guard transitionID == expectedTransitionID else { return }
        phase = .completed
        progress = 1
        velocity = .zero
        hasCompleted = true
        let completion = completion
        self.completion = nil
        completion?()
    }

    private func interpolatedMetrics(progress: CGFloat) -> IslandAnimationMetrics {
        let t = min(max(progress, 0), 1)
        let eased = easedProgress(t, curve: curve, spring: spring)
        let velocityWeight = t * (1 - t) * CGFloat(duration)
        return IslandAnimationMetrics(
            visibleFrame: CGRect(
                x: start.visibleFrame.origin.x +
                    (target.visibleFrame.origin.x - start.visibleFrame.origin.x) * eased + startVelocity.origin.x * velocityWeight,
                y: start.visibleFrame.origin.y +
                    (target.visibleFrame.origin.y - start.visibleFrame.origin.y) * eased + startVelocity.origin.y * velocityWeight,
                width: start.visibleFrame.width +
                    (target.visibleFrame.width - start.visibleFrame.width) * eased + startVelocity.size.width * velocityWeight,
                height: start.visibleFrame.height +
                    (target.visibleFrame.height - start.visibleFrame.height) * eased + startVelocity.size.height * velocityWeight
            ),
            visualScale: start.visualScale +
                (target.visualScale - start.visualScale) * eased + startVelocity.visualScale * velocityWeight
        )
    }

    private func interpolatedVelocity(progress: CGFloat) -> IslandAnimationVelocity {
        guard duration > 0 else { return .zero }
        let t = min(max(progress, 0), 1)
        let multiplier = curveDerivative(t, curve: curve, spring: spring) / CGFloat(duration)
        let velocityWeightDerivative = 1 - 2 * t
        return IslandAnimationVelocity(
            origin: CGPoint(
                x: (target.visibleFrame.origin.x - start.visibleFrame.origin.x) * multiplier + startVelocity.origin.x * velocityWeightDerivative,
                y: (target.visibleFrame.origin.y - start.visibleFrame.origin.y) * multiplier + startVelocity.origin.y * velocityWeightDerivative
            ),
            size: CGSize(
                width: (target.visibleFrame.width - start.visibleFrame.width) * multiplier + startVelocity.size.width * velocityWeightDerivative,
                height: (target.visibleFrame.height - start.visibleFrame.height) * multiplier + startVelocity.size.height * velocityWeightDerivative
            ),
            visualScale: (target.visualScale - start.visualScale) * multiplier + startVelocity.visualScale * velocityWeightDerivative
        )
    }

    private func boundedVelocity(
        _ velocity: IslandAnimationVelocity,
        from start: IslandAnimationMetrics,
        to target: IslandAnimationMetrics,
        duration: TimeInterval
    ) -> IslandAnimationVelocity {
        guard duration > 0 else { return .zero }
        let duration = CGFloat(duration)
        func bound(_ velocity: CGFloat, delta: CGFloat) -> CGFloat {
            guard delta != 0 else { return 0 }
            let maximum = abs(delta) * 1.5 / duration
            return min(max(velocity, -maximum), maximum)
        }

        return IslandAnimationVelocity(
            origin: CGPoint(
                x: bound(velocity.origin.x, delta: target.visibleFrame.origin.x - start.visibleFrame.origin.x),
                y: bound(velocity.origin.y, delta: target.visibleFrame.origin.y - start.visibleFrame.origin.y)
            ),
            size: CGSize(
                width: bound(velocity.size.width, delta: target.visibleFrame.width - start.visibleFrame.width),
                height: bound(velocity.size.height, delta: target.visibleFrame.height - start.visibleFrame.height)
            ),
            visualScale: bound(velocity.visualScale, delta: target.visualScale - start.visualScale)
        )
    }

    private func easedProgress(
        _ progress: CGFloat,
        curve: IslandMotionTimingCurve,
        spring: IslandSpringMotionToken?
    ) -> CGFloat {
        if let spring {
            return springProgress(progress, token: spring)
        }

        switch curve {
        case .linear:
            return progress
        case .easeOut:
            return 1 - pow(1 - progress, 2)
        case .easeInOut:
            return progress * progress * (3 - 2 * progress)
        }
    }

    private func curveDerivative(
        _ progress: CGFloat,
        curve: IslandMotionTimingCurve,
        spring: IslandSpringMotionToken?
    ) -> CGFloat {
        if let spring {
            let epsilon: CGFloat = 0.0005
            let lower = max(progress - epsilon, 0)
            let upper = min(progress + epsilon, 1)
            guard upper > lower else { return 0 }
            return (springProgress(upper, token: spring) - springProgress(lower, token: spring)) /
                (upper - lower)
        }

        switch curve {
        case .linear:
            return 1
        case .easeOut:
            return 2 * (1 - progress)
        case .easeInOut:
            return 6 * progress * (1 - progress)
        }
    }

    private func springProgress(_ progress: CGFloat, token: IslandSpringMotionToken) -> CGFloat {
        let t = min(max(progress, 0), 1) * CGFloat(duration)
        let endTime = CGFloat(duration)
        let raw = springResponse(at: t, token: token)
        let end = springResponse(at: endTime, token: token)
        guard abs(end) > 0.0001 else { return progress }
        return raw / end
    }

    private func springResponse(at t: CGFloat, token: IslandSpringMotionToken) -> CGFloat {
        let mass = max(token.mass, 0.001)
        let stiffness = max(token.stiffness, 0.001)
        let damping = max(token.damping, 0)
        let omega0 = sqrt(stiffness / mass)
        let dampingRatio = damping / (2 * sqrt(stiffness * mass))

        guard dampingRatio < 1 else {
            return 1 - exp(-omega0 * t)
        }

        let dampedOmega = omega0 * sqrt(max(1 - (dampingRatio * dampingRatio), 0.0001))
        let envelope = exp(-dampingRatio * omega0 * t)
        let phase = cos(dampedOmega * t) +
            (dampingRatio / sqrt(max(1 - (dampingRatio * dampingRatio), 0.0001))) * sin(dampedOmega * t)
        return 1 - (envelope * phase)
    }
}
