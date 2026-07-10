import CoreGraphics
import Foundation

enum IslandGreetingPhase: String, Equatable {
    case hidden
    case entering
    case visible
    case exiting
    case expired
    case cancelled
}

struct IslandGreetingPresentation: Equatable {
    let opacity: Double
    let offsetY: CGFloat
}

struct IslandGreetingTimelineSample: Equatable {
    let phase: IslandGreetingPhase
    let presentation: IslandGreetingPresentation
    let shouldUseGreetingWidth: Bool
}

enum IslandGreetingSequence {
    static let lifecycleDuration: TimeInterval = 10
    static let transitionDuration: TimeInterval = 0.35

    /// Returns a deterministic sample for the scenario runner. The ten-second
    /// lifetime begins when the greeting is presented; its exit finishes at 10.35s.
    static func sample(at elapsed: TimeInterval) -> IslandGreetingTimelineSample {
        let time = max(0, elapsed)
        if time == 0 {
            return IslandGreetingTimelineSample(
                phase: .hidden,
                presentation: presentation(for: .hidden),
                shouldUseGreetingWidth: true
            )
        }
        if time < transitionDuration {
            return IslandGreetingTimelineSample(
                phase: .entering,
                presentation: interpolated(from: .hidden, to: .entering, progress: time / transitionDuration),
                shouldUseGreetingWidth: true
            )
        }
        if time < lifecycleDuration {
            return IslandGreetingTimelineSample(
                phase: .visible,
                presentation: presentation(for: .visible),
                shouldUseGreetingWidth: true
            )
        }
        if time < lifecycleDuration + transitionDuration {
            return IslandGreetingTimelineSample(
                phase: .exiting,
                presentation: interpolated(
                    from: .visible,
                    to: .exiting,
                    progress: (time - lifecycleDuration) / transitionDuration
                ),
                shouldUseGreetingWidth: true
            )
        }
        return IslandGreetingTimelineSample(
            phase: .expired,
            presentation: presentation(for: .expired),
            shouldUseGreetingWidth: false
        )
    }

    static func presentation(for phase: IslandGreetingPhase) -> IslandGreetingPresentation {
        switch phase {
        case .hidden:
            return IslandGreetingPresentation(opacity: 0, offsetY: 6)
        case .entering, .visible:
            return IslandGreetingPresentation(opacity: 1, offsetY: 0)
        case .exiting:
            return IslandGreetingPresentation(opacity: 0, offsetY: -6)
        case .expired, .cancelled:
            return IslandGreetingPresentation(opacity: 0, offsetY: 0)
        }
    }

    private static func interpolated(
        from start: IslandGreetingPhase,
        to end: IslandGreetingPhase,
        progress: TimeInterval
    ) -> IslandGreetingPresentation {
        let t = min(max(progress, 0), 1)
        let source = presentation(for: start)
        let target = presentation(for: end)
        return IslandGreetingPresentation(
            opacity: source.opacity + ((target.opacity - source.opacity) * t),
            offsetY: source.offsetY + ((target.offsetY - source.offsetY) * t)
        )
    }
}

struct IslandGreetingTransitionGate: Equatable {
    private(set) var epoch = 0

    mutating func begin() -> Int {
        epoch += 1
        return epoch
    }

    func accepts(_ candidate: Int) -> Bool {
        epoch == candidate
    }
}
