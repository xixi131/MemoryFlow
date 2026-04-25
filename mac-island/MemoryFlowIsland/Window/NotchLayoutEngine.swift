import AppKit

enum TopAttachmentKind: Equatable {
    case notch
    case menuBar
    case flatTopFallback
}

struct TopAttachmentMetrics: Equatable {
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
}

struct IslandPlacementResult {
    let frame: CGRect
    let attachmentMetrics: TopAttachmentMetrics
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
                availableTopWidth: topBandFrame.width,
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
