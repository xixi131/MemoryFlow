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
        let activityHover = IslandShapeEngine.snapshot(for: .activityHoverCollapsed, visualScale: 1)
        let expanded = IslandShapeEngine.snapshot(for: .expandedApp, visualScale: 1)

        guard approximatelyEqual(
                  hover.metrics.width,
                  compact.metrics.width * IslandVisualTokens.hover.collapsedWidthScale
              ),
              approximatelyEqual(hover.metrics.height, IslandVisualTokens.hover.collapsedHeight),
              hover.shadowOutsets.horizontal == IslandVisualTokens.shadow.hoverBuffer.horizontal,
              hover.shadowOutsets.bottom == IslandVisualTokens.shadow.hoverBuffer.bottom,
              hover.hitTestFrame == hover.visibleFrame,
              hover.contentFrame.width > hover.hitTestFrame.width,
              hover.contentFrame.height > hover.hitTestFrame.height,
              approximatelyEqual(activity.metrics.height, IslandVisualTokens.activity.height),
              approximatelyEqual(
                  activityHover.metrics.width,
                  activity.metrics.width * IslandVisualTokens.hover.collapsedWidthScale
              ),
              approximatelyEqual(activityHover.metrics.height, IslandVisualTokens.hover.collapsedHeight),
              activityHover.shadowOutsets.horizontal == hover.shadowOutsets.horizontal,
              activityHover.shadowOutsets.bottom == hover.shadowOutsets.bottom,
              approximatelyEqual(expanded.metrics.height, IslandVisualTokens.expandedApp.height) else {
            throw IslandHoverBreathingProbeError.invalidHoverSurface
        }

        try validatePixelAlignedExpansion()

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

    private static func validatePixelAlignedExpansion() throws {
        let attachment = TopAttachmentMetrics(
            kind: .menuBar,
            topBandFrame: CGRect(x: 900, y: 1_000, width: 200.5, height: 30),
            notchFrame: nil,
            menuBarHeight: 30,
            safeTopInset: 0,
            pixelScale: 2,
            availableTopWidth: 1_440,
            centerX: 1_000.25
        )
        let compactSizing = IslandWindowSizingEngine.resolve(
            state: .compactCollapsed,
            attachmentMetrics: attachment,
            widthConstraints: .none
        )
        let hoverSizing = IslandWindowSizingEngine.resolve(
            state: .hoverCollapsed,
            attachmentMetrics: attachment,
            widthConstraints: .none
        )
        let compactMetrics = IslandShapeMetrics.resolve(
            for: .compactCollapsed,
            visualScale: attachment.visualScale,
            horizontalScale: attachment.horizontalVisualScale
        )
        let hoverMetrics = IslandShapeMetrics.resolve(
            for: .hoverCollapsed,
            visualScale: attachment.visualScale,
            horizontalScale: attachment.horizontalVisualScale
        )

        guard approximatelyEqual(compactSizing.visibleFrame.midX, attachment.centerX),
              approximatelyEqual(hoverSizing.visibleFrame.midX, attachment.centerX),
              approximatelyEqual(compactSizing.visibleFrame.maxY, hoverSizing.visibleFrame.maxY),
              hoverSizing.visibleFrame.minY < compactSizing.visibleFrame.minY else {
            throw IslandHoverBreathingProbeError.asymmetricOrClippedExpansion
        }

        for progress in stride(from: CGFloat(0), through: 1, by: 0.1) {
            let sizing = IslandWindowSizingEngine.resolveAnimatedSample(
                from: compactSizing,
                to: hoverSizing,
                progress: progress,
                attachmentMetrics: attachment
            )
            let leftGrowth = compactSizing.visibleFrame.minX - sizing.visibleFrame.minX
            let rightGrowth = sizing.visibleFrame.maxX - compactSizing.visibleFrame.maxX
            let interpolated = compactMetrics.interpolated(to: hoverMetrics, progress: progress)
            let fitted = IslandShapeEngine.metrics(interpolated, fittedTo: sizing.visibleSize)
            let rendered = IslandShapeEngine.snapshot(
                for: fitted,
                state: progress >= 0.5 ? .hoverCollapsed : .compactCollapsed,
                shadowOutsetsOverride: sizing.shadowOutsets
            )

            guard approximatelyEqual(leftGrowth, rightGrowth),
                  approximatelyEqual(rendered.visibleFrame.width, sizing.visibleSize.width),
                  approximatelyEqual(rendered.visibleFrame.height, sizing.visibleSize.height),
                  rendered.contentFrame.height + 0.001 >= rendered.visibleFrame.height + sizing.shadowOutsets.bottom else {
                throw IslandHoverBreathingProbeError.asymmetricOrClippedExpansion
            }
        }
    }

    private static func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

enum IslandHoverBreathingProbeError: Error, CustomStringConvertible {
    case invalidHoverSurface
    case retargetSnapped
    case leaveDidNotReverse
    case asymmetricOrClippedExpansion

    var description: String {
        switch self {
        case .invalidHoverSurface:
            return "Hover geometry, shadow, or interactive hotspot diverged from the compact-hover contract."
        case .retargetSnapped:
            return "Hover leave did not start from the current presentation metrics."
        case .leaveDidNotReverse:
            return "Hover leave did not reverse toward compact geometry."
        case .asymmetricOrClippedExpansion:
            return "Hover expansion is not centered or its pixel-aligned shell exceeds the render surface."
        }
    }
}
