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
        return rows
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
    case retargetSnapped
    case reverseDidNotMoveTowardCompact
    case unexpectedSamples

    var description: String {
        switch self {
        case .retargetSnapped: return "Retargeting did not start from live presentation metrics."
        case .reverseDidNotMoveTowardCompact: return "Reverse transition did not preserve a negative width velocity."
        case .unexpectedSamples: return "Animation sample sequence did not reach the expected presentation metrics."
        }
    }
}
