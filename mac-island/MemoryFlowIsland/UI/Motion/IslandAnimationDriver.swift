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

    /// Starts, or retargets, an animation. Retargeting takes the sampled presentation
    /// metrics as its new start point, preserving visual continuity.
    func animate(
        to target: IslandAnimationMetrics,
        transitionID: String,
        duration: TimeInterval,
        curve: IslandMotionTimingCurve,
        at timestamp: TimeInterval,
        completion: Completion? = nil
    ) {
        if isAnimating {
            advance(at: timestamp)
        }

        start = current
        self.target = target
        self.transitionID = transitionID
        self.duration = max(duration, 0)
        self.curve = curve
        startTime = timestamp
        self.completion = completion
        hasCompleted = false
        velocity = .zero

        guard self.duration > 0, start != target else {
            current = target
            progress = 1
            finish()
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
        let eased = easedProgress(normalized, curve: curve)
        current = .interpolate(from: start, to: target, progress: eased)
        progress = normalized
        velocity = interpolatedVelocity(progress: normalized, curve: curve)

        if normalized >= 1 {
            current = target
            finish()
        }
    }

    private func finish() {
        phase = .completed
        progress = 1
        velocity = .zero
        hasCompleted = true
        let completion = completion
        self.completion = nil
        completion?()
    }

    private func interpolatedVelocity(progress: CGFloat, curve: IslandMotionTimingCurve) -> IslandAnimationVelocity {
        guard duration > 0 else { return .zero }
        let multiplier = curveDerivative(progress, curve: curve) / CGFloat(duration)
        return IslandAnimationVelocity(
            origin: CGPoint(
                x: (target.visibleFrame.origin.x - start.visibleFrame.origin.x) * multiplier,
                y: (target.visibleFrame.origin.y - start.visibleFrame.origin.y) * multiplier
            ),
            size: CGSize(
                width: (target.visibleFrame.width - start.visibleFrame.width) * multiplier,
                height: (target.visibleFrame.height - start.visibleFrame.height) * multiplier
            ),
            visualScale: (target.visualScale - start.visualScale) * multiplier
        )
    }

    private func easedProgress(_ progress: CGFloat, curve: IslandMotionTimingCurve) -> CGFloat {
        switch curve {
        case .linear:
            return progress
        case .easeOut:
            return 1 - pow(1 - progress, 2)
        case .easeInOut:
            return progress * progress * (3 - 2 * progress)
        }
    }

    private func curveDerivative(_ progress: CGFloat, curve: IslandMotionTimingCurve) -> CGFloat {
        switch curve {
        case .linear:
            return 1
        case .easeOut:
            return 2 * (1 - progress)
        case .easeInOut:
            return 6 * progress * (1 - progress)
        }
    }
}
