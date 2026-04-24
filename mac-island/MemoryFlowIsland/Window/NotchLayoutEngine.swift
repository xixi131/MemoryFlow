import AppKit

struct NotchLayoutEngine {
    let phase2NotchTopMargin: CGFloat = 10
    let phase2FlatTopMargin: CGFloat = 10
    var displayTopEdgeClassifier: DisplayTopEdgeClassifier = DisplayTopEdgeClassifier()

    func displayTopEdge(for screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        displayTopEdgeClassifier.classify(screenMetrics)
    }

    func islandOrigin(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGPoint {
        switch displayTopEdge(for: screenMetrics) {
        case .notchBearing:
            return islandOrigin(
                topSafeRegion: topSafeRegion(for: screenMetrics),
                islandSize: islandSize,
                topMargin: phase2NotchTopMargin
            )
        case .flatTop:
            return islandOrigin(
                screenFrame: screenMetrics.visibleFrame,
                islandSize: islandSize,
                topMargin: phase2FlatTopMargin
            )
        }
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
        CGRect(origin: islandOrigin(screenMetrics: screenMetrics, islandSize: islandSize), size: islandSize)
    }

    func islandFrame(screenFrame: CGRect, islandSize: CGSize) -> CGRect {
        CGRect(origin: islandOrigin(screenFrame: screenFrame, islandSize: islandSize), size: islandSize)
    }
}
