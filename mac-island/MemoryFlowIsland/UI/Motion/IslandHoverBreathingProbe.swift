import CoreGraphics
import Foundation

/// Deterministic acceptance checks for compact hover emphasis. The window owner
/// consumes the visible frame for top anchoring; this probe ensures the visual
/// surface keeps shadow padding out of the interactive hotspot.
enum IslandHoverBreathingProbe {
    @MainActor
    static func validate() throws {
        let compact = IslandShapeEngine.snapshot(for: .compactCollapsed, visualScale: 1)
        let hover = IslandShapeEngine.snapshot(for: .hoverCollapsed, visualScale: 1)
        let activity = IslandShapeEngine.snapshot(for: .activityCollapsed, visualScale: 1)
        let expanded = IslandShapeEngine.snapshot(for: .expandedApp, visualScale: 1)

        guard approximatelyEqual(hover.metrics.width, compact.metrics.width * 1.025),
              approximatelyEqual(hover.metrics.height, 37),
              hover.shadowOutsets.horizontal == 12,
              hover.shadowOutsets.bottom == 17,
              hover.hitTestFrame == hover.visibleFrame,
              hover.contentFrame.width > hover.hitTestFrame.width,
              hover.contentFrame.height > hover.hitTestFrame.height,
              approximatelyEqual(activity.metrics.height, IslandVisualTokens.activity.height),
              approximatelyEqual(expanded.metrics.height, IslandVisualTokens.expandedApp.height) else {
            throw IslandHoverBreathingProbeError.invalidHoverSurface
        }

        let driver = IslandAnimationDriver(initialMetrics: metrics(for: compact))
        driver.animate(
            to: metrics(for: hover),
            transitionID: "hover-enter",
            duration: IslandMotionTokens.hoverDuration,
            curve: .easeInOut,
            at: 0
        )
        driver.advance(at: 0.11)
        let presentationAtLeave = driver.current

        driver.animate(
            to: metrics(for: compact),
            transitionID: "hover-leave",
            duration: IslandMotionTokens.hoverDuration,
            curve: .easeInOut,
            at: 0.11
        )
        guard driver.current == presentationAtLeave else {
            throw IslandHoverBreathingProbeError.retargetSnapped
        }
        driver.advance(at: 0.22)
        guard driver.current.visibleFrame.width < presentationAtLeave.visibleFrame.width,
              driver.current.visibleFrame.height < presentationAtLeave.visibleFrame.height else {
            throw IslandHoverBreathingProbeError.leaveDidNotReverse
        }
    }

    private static func metrics(for snapshot: IslandShapeLayoutSnapshot) -> IslandAnimationMetrics {
        IslandAnimationMetrics(visibleFrame: snapshot.visibleFrame, visualScale: 1)
    }

    private static func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

enum IslandHoverBreathingProbeError: Error, CustomStringConvertible {
    case invalidHoverSurface
    case retargetSnapped
    case leaveDidNotReverse

    var description: String {
        switch self {
        case .invalidHoverSurface:
            return "Hover geometry, shadow, or interactive hotspot diverged from the compact-hover contract."
        case .retargetSnapped:
            return "Hover leave did not start from the current presentation metrics."
        case .leaveDidNotReverse:
            return "Hover leave did not reverse toward compact geometry."
        }
    }
}
