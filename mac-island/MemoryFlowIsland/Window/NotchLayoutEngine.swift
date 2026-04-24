import AppKit

struct IslandPlacementResult {
    let frame: CGRect
}

struct NotchLayoutEngine {
    let phase2NotchTopMargin: CGFloat = 10
    let phase2FlatTopMargin: CGFloat = 10
    var displayTopEdgeClassifier: DisplayTopEdgeClassifier = DisplayTopEdgeClassifier()

    func displayTopEdge(for screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        displayTopEdgeClassifier.classify(screenMetrics)
    }

    func placementResult(screenMetrics: ScreenMetrics, islandSize: CGSize) -> IslandPlacementResult {
        switch displayTopEdge(for: screenMetrics) {
        case .notchBearing:
            return notchPlacementResult(screenMetrics: screenMetrics, islandSize: islandSize)
        case .flatTop:
            return flatTopPlacementResult(screenMetrics: screenMetrics, islandSize: islandSize)
        }
    }

    func islandOrigin(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGPoint {
        placementResult(screenMetrics: screenMetrics, islandSize: islandSize).frame.origin
    }

    func islandOrigin(screenFrame: CGRect, islandSize: CGSize) -> CGPoint {
        islandOrigin(screenFrame: screenFrame, islandSize: islandSize, topMargin: phase2FlatTopMargin)
    }

    func islandOrigin(screenFrame: CGRect, islandSize: CGSize, topMargin: CGFloat) -> CGPoint {
        let x = screenFrame.midX - (islandSize.width / 2)
        let y = screenFrame.maxY - islandSize.height - topMargin
        return CGPoint(x: x, y: y)
    }

    func islandOrigin(topSafeRegion: CGRect, islandSize: CGSize, topMargin: CGFloat) -> CGPoint {
        let x = topSafeRegion.midX - (islandSize.width / 2)
        let y = topSafeRegion.minY - islandSize.height - topMargin
        return CGPoint(x: x, y: y)
    }

    func flatTopFallbackOrigin(visibleFrame: CGRect, islandSize: CGSize, topMargin: CGFloat) -> CGPoint {
        let proposedX = visibleFrame.midX - (islandSize.width / 2)
        let maxOriginX = max(visibleFrame.maxX - islandSize.width, visibleFrame.minX)
        let x = min(max(proposedX, visibleFrame.minX), maxOriginX)

        let proposedY = visibleFrame.maxY - islandSize.height - topMargin
        let maxOriginY = max(visibleFrame.maxY - islandSize.height, visibleFrame.minY)
        let y = min(max(proposedY, visibleFrame.minY), maxOriginY)

        return CGPoint(x: x, y: y)
    }

    func topSafeRegion(for screenMetrics: ScreenMetrics) -> CGRect {
        let insetLeft = max(screenMetrics.safeAreaInsets.left, 0)
        let insetRight = max(screenMetrics.safeAreaInsets.right, 0)
        let safeWidth = max(screenMetrics.frame.width - insetLeft - insetRight, 0)
        let safeHeight = max(screenMetrics.safeAreaInsets.top, 0)

        return CGRect(
            x: screenMetrics.frame.minX + insetLeft,
            y: screenMetrics.frame.maxY - safeHeight,
            width: safeWidth,
            height: safeHeight
        )
    }

    func islandFrame(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGRect {
        placementResult(screenMetrics: screenMetrics, islandSize: islandSize).frame
    }

    func islandFrame(screenFrame: CGRect, islandSize: CGSize) -> CGRect {
        CGRect(origin: islandOrigin(screenFrame: screenFrame, islandSize: islandSize), size: islandSize)
    }

    private func notchPlacementResult(screenMetrics: ScreenMetrics, islandSize: CGSize) -> IslandPlacementResult {
        let frame = CGRect(
            origin: islandOrigin(
                topSafeRegion: topSafeRegion(for: screenMetrics),
                islandSize: islandSize,
                topMargin: phase2NotchTopMargin
            ),
            size: islandSize
        )
        return IslandPlacementResult(frame: frame)
    }

    private func flatTopPlacementResult(screenMetrics: ScreenMetrics, islandSize: CGSize) -> IslandPlacementResult {
        let frame = CGRect(
            origin: flatTopFallbackOrigin(
                visibleFrame: screenMetrics.visibleFrame,
                islandSize: islandSize,
                topMargin: phase2FlatTopMargin
            ),
            size: islandSize
        )
        return IslandPlacementResult(frame: frame)
    }
}
