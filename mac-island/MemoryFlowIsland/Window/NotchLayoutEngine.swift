import AppKit

enum TopAttachmentKind: Equatable {
    case notch
    case menuBar
    case flatTopFallback
}

struct TopAttachmentMetrics: Equatable {
    static let compactBodyWidthTrim: CGFloat = 2

    let kind: TopAttachmentKind
    let topBandFrame: CGRect
    let notchFrame: CGRect?
    let menuBarHeight: CGFloat
    let safeTopInset: CGFloat
    let pixelScale: CGFloat
    let availableTopWidth: CGFloat
    let centerX: CGFloat

    var visualScale: CGFloat {
        let rawScale = topBandFrame.height / IslandVisualTokens.compact.height
        return min(max(rawScale, 0.78), 1.18)
    }

    var horizontalVisualScale: CGFloat {
        guard let notchFrame else {
            return visualScale
        }

        let compactTokens = IslandVisualTokens.compact
        let compactEarReach = (compactTokens.earBlendHeight * visualScale * compactTokens.earTension) +
            IslandPathFactory.shellEarTipExtension
        let targetBodyWidth = max(notchFrame.width - (compactEarReach * 2), 1)
        let rawScale = targetBodyWidth / max(compactTokens.previewWidth, 1)
        return min(max(rawScale, 0.68), 1.4)
    }

    /// Keeps expanded content one menu-bar height below the display top so the
    /// physical notch never covers the inner surface. Synthetic or legacy
    /// displays without a measurable menu bar fall back to their safe top band.
    var expandedContentTopInset: CGFloat {
        let fallbackTopInset = max(safeTopInset, topBandFrame.height)
        return menuBarHeight > 0 ? menuBarHeight : fallbackTopInset
    }

    func notchAlignedBodyWidth(for state: IslandVisualState) -> CGFloat? {
        guard let notchFrame else { return nil }

        switch state {
        case .compactCollapsed:
            return max(notchFrame.width - Self.compactBodyWidthTrim, 1)

        case .hoverCollapsed:
            return notchFrame.width

        case .activityCollapsed, .activityHoverCollapsed, .expandedMusic, .expandedApp:
            return nil
        }
    }
}

struct IslandPlacementResult {
    let frame: CGRect
    let attachmentMetrics: TopAttachmentMetrics
}

struct IslandActivityNotchClearanceLayout: Equatable {
    let centerSpanWidth: CGFloat
    let leadingContentSlotWidth: CGFloat
    let trailingContentSlotWidth: CGFloat
    let sharedHorizontalPadding: CGFloat
    let requiredVisibleWidth: CGFloat
    let requiredBodyWidth: CGFloat

    static func resolve(
        attachmentMetrics: TopAttachmentMetrics,
        contentWidthRequirement: IslandContentWidthRequirement
    ) -> IslandActivityNotchClearanceLayout {
        let compactTokens = IslandVisualTokens.shell(for: .compact)
        let compactEarReach =
            (compactTokens.earBlendHeight * attachmentMetrics.visualScale * compactTokens.earTension) +
            IslandPathFactory.shellEarTipExtension
        let fallbackCompactSpan =
            (compactTokens.previewWidth * attachmentMetrics.horizontalVisualScale) + (compactEarReach * 2)
        let centerSpanWidth = attachmentMetrics.notchFrame?.width ?? fallbackCompactSpan
        let leadingSlotWidth = max(contentWidthRequirement.leadingContentWidth, 0)
        let trailingSlotWidth = max(contentWidthRequirement.trailingContentWidth, 0)
        let sharedPadding = max(contentWidthRequirement.horizontalPadding, 0)

        // The physical notch remains centered, so both sides must be wide enough for
        // the larger activity group. This keeps either side usable without shifting
        // the top-center window anchor when content widths differ.
        let perEdgeContentReach = max(leadingSlotWidth, trailingSlotWidth) + sharedPadding
        let requiredVisibleWidth = min(
            centerSpanWidth + (perEdgeContentReach * 2),
            attachmentMetrics.availableTopWidth
        )
        let activityTokens = IslandVisualTokens.shell(for: .activity)
        let activityEarReach =
            (activityTokens.earBlendHeight * attachmentMetrics.visualScale * activityTokens.earTension) +
            IslandPathFactory.shellEarTipExtension

        return IslandActivityNotchClearanceLayout(
            centerSpanWidth: centerSpanWidth,
            leadingContentSlotWidth: leadingSlotWidth,
            trailingContentSlotWidth: trailingSlotWidth,
            sharedHorizontalPadding: sharedPadding,
            requiredVisibleWidth: requiredVisibleWidth,
            requiredBodyWidth: max(requiredVisibleWidth - (activityEarReach * 2), 1)
        )
    }
}

struct IslandActivityNotchClearContentFrames: Equatable {
    let leadingContentFrame: CGRect
    let centerClearFrame: CGRect
    let trailingContentFrame: CGRect

    var leadingVisualCenter: CGPoint {
        CGPoint(
            x: leadingContentFrame.midX + IslandActivityContentWidthProfile.shellCurveCenterCompensation,
            y: leadingContentFrame.midY
        )
    }

    var trailingVisualCenter: CGPoint {
        CGPoint(
            x: trailingContentFrame.midX - IslandActivityContentWidthProfile.shellCurveCenterCompensation,
            y: trailingContentFrame.midY
        )
    }

    static func resolve(
        visibleSize: CGSize,
        contentWidthRequirement: IslandContentWidthRequirement
    ) -> IslandActivityNotchClearContentFrames {
        let visibleWidth = max(visibleSize.width, 0)
        let visibleHeight = max(visibleSize.height, 0)
        let requestedSlotWidth = max(
            max(contentWidthRequirement.leadingContentWidth, 0),
            max(contentWidthRequirement.trailingContentWidth, 0)
        )
        let requestedPadding = max(contentWidthRequirement.horizontalPadding, 0)
        let edgeReach = min(requestedSlotWidth + requestedPadding, visibleWidth / 2)
        let centerWidth = max(visibleWidth - (edgeReach * 2), 0)

        return IslandActivityNotchClearContentFrames(
            leadingContentFrame: CGRect(
                x: 0,
                y: 0,
                width: edgeReach,
                height: visibleHeight
            ),
            centerClearFrame: CGRect(
                x: edgeReach,
                y: 0,
                width: centerWidth,
                height: visibleHeight
            ),
            trailingContentFrame: CGRect(
                x: edgeReach + centerWidth,
                y: 0,
                width: edgeReach,
                height: visibleHeight
            )
        )
    }
}

struct NotchLayoutEngine {
    private let designCollapsedSize = IslandShellSizePreset.compactPlaceholder.visibleShellSize
    private let minimumFlatTopScale: CGFloat = 0.68
    var displayTopEdgeClassifier: DisplayTopEdgeClassifier = DisplayTopEdgeClassifier()

    func displayTopEdge(for screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        displayTopEdgeClassifier.classify(screenMetrics)
    }

    func placementResult(screenMetrics: ScreenMetrics, islandSize: CGSize) -> IslandPlacementResult {
        let attachmentMetrics = topAttachmentMetrics(for: screenMetrics)
        let resolvedSize = resolvedIslandSize(
            requestedSize: islandSize,
            attachmentMetrics: attachmentMetrics
        )
        let origin = islandOrigin(
            screenMetrics: screenMetrics,
            islandSize: resolvedSize,
            attachmentMetrics: attachmentMetrics
        )
        let frame = pixelAligned(
            CGRect(origin: origin, size: resolvedSize),
            scale: attachmentMetrics.pixelScale
        )

        return IslandPlacementResult(
            frame: frame,
            attachmentMetrics: attachmentMetrics
        )
    }

    func islandFrame(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGRect {
        placementResult(screenMetrics: screenMetrics, islandSize: islandSize).frame
    }

    func islandFrame(screenFrame: CGRect, islandSize: CGSize) -> CGRect {
        let x = screenFrame.midX - (islandSize.width / 2)
        let y = screenFrame.maxY - islandSize.height
        return CGRect(origin: CGPoint(x: x, y: y), size: islandSize)
    }

    func topAttachmentMetrics(for screenMetrics: ScreenMetrics) -> TopAttachmentMetrics {
        if let notchFrame = screenMetrics.notchFrame {
            let topBandFrame = pixelAligned(
                notchFrame,
                scale: screenMetrics.backingScaleFactor
            )
            return TopAttachmentMetrics(
                kind: .notch,
                topBandFrame: topBandFrame,
                notchFrame: topBandFrame,
                menuBarHeight: menuBarHeight(for: screenMetrics),
                safeTopInset: max(screenMetrics.safeAreaInsets.top, 0),
                pixelScale: max(screenMetrics.backingScaleFactor, 1),
                availableTopWidth: screenMetrics.frame.width,
                centerX: topBandFrame.midX
            )
        }

        let menuBarHeight = menuBarHeight(for: screenMetrics)
        let topBandHeight = menuBarHeight > 0
            ? menuBarHeight
            : min(designCollapsedSize.height, max(screenMetrics.safeAreaInsets.top, 0))
        let resolvedTopBandHeight = topBandHeight > 0 ? topBandHeight : designCollapsedSize.height
        let topBandFrame = pixelAligned(
            CGRect(
                x: screenMetrics.frame.minX,
                y: screenMetrics.frame.maxY - resolvedTopBandHeight,
                width: screenMetrics.frame.width,
                height: resolvedTopBandHeight
            ),
            scale: screenMetrics.backingScaleFactor
        )

        return TopAttachmentMetrics(
            kind: menuBarHeight > 0 ? .menuBar : .flatTopFallback,
            topBandFrame: topBandFrame,
            notchFrame: nil,
            menuBarHeight: menuBarHeight,
            safeTopInset: max(screenMetrics.safeAreaInsets.top, 0),
            pixelScale: max(screenMetrics.backingScaleFactor, 1),
            availableTopWidth: topBandFrame.width,
            centerX: topBandFrame.midX
        )
    }

    private func resolvedIslandSize(
        requestedSize: CGSize,
        attachmentMetrics: TopAttachmentMetrics
    ) -> CGSize {
        switch attachmentMetrics.kind {
        case .notch:
            if isCompactPlaceholderRequest(requestedSize),
               let notchFrame = attachmentMetrics.notchFrame {
                return notchFrame.size
            }

            return CGSize(
                width: min(max(requestedSize.width, attachmentMetrics.topBandFrame.width), attachmentMetrics.availableTopWidth),
                height: max(requestedSize.height, attachmentMetrics.topBandFrame.height)
            )

        case .menuBar, .flatTopFallback:
            if isCompactPlaceholderRequest(requestedSize) {
                let topBandHeight = max(attachmentMetrics.topBandFrame.height, 1)
                let scale = max(topBandHeight / designCollapsedSize.height, minimumFlatTopScale)
                let height = topBandHeight
                let width = min(designCollapsedSize.width * scale, attachmentMetrics.availableTopWidth)
                return CGSize(width: width, height: height)
            }

            return CGSize(
                width: min(requestedSize.width, attachmentMetrics.availableTopWidth),
                height: requestedSize.height
            )
        }
    }

    private func islandOrigin(
        screenMetrics: ScreenMetrics,
        islandSize: CGSize,
        attachmentMetrics: TopAttachmentMetrics
    ) -> CGPoint {
        let proposedX = attachmentMetrics.centerX - (islandSize.width / 2)
        let minX = screenMetrics.frame.minX
        let maxX = max(screenMetrics.frame.maxX - islandSize.width, minX)
        let x = min(max(proposedX, minX), maxX)
        let y = screenMetrics.frame.maxY - islandSize.height
        return CGPoint(x: x, y: y)
    }

    private func menuBarHeight(for screenMetrics: ScreenMetrics) -> CGFloat {
        max(screenMetrics.frame.maxY - screenMetrics.visibleFrame.maxY, 0)
    }

    private func isCompactPlaceholderRequest(_ requestedSize: CGSize) -> Bool {
        abs(requestedSize.width - designCollapsedSize.width) < 0.5 &&
            abs(requestedSize.height - designCollapsedSize.height) < 0.5
    }

    private func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let safeScale = max(scale, 1)
        return CGRect(
            x: pixelAligned(rect.origin.x, scale: safeScale),
            y: pixelAligned(rect.origin.y, scale: safeScale),
            width: pixelAligned(rect.size.width, scale: safeScale),
            height: pixelAligned(rect.size.height, scale: safeScale)
        )
    }

    private func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }
}
