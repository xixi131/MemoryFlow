import AppKit

struct NotchLayoutEngine {
    var topMargin: CGFloat = 10
    var displayTopEdgeClassifier: DisplayTopEdgeClassifier = DisplayTopEdgeClassifier()

    func displayTopEdge(for screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        displayTopEdgeClassifier.classify(screenMetrics)
    }

    func islandOrigin(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGPoint {
        switch displayTopEdge(for: screenMetrics) {
        case .notchBearing:
            return islandOrigin(screenFrame: screenMetrics.visibleFrame, islandSize: islandSize)
        case .flatTop:
            return islandOrigin(screenFrame: screenMetrics.visibleFrame, islandSize: islandSize)
        }
    }

    func islandOrigin(screenFrame: CGRect, islandSize: CGSize) -> CGPoint {
        let x = screenFrame.midX - (islandSize.width / 2)
        let y = screenFrame.maxY - islandSize.height - topMargin
        return CGPoint(x: x, y: y)
    }

    func islandFrame(screenMetrics: ScreenMetrics, islandSize: CGSize) -> CGRect {
        CGRect(origin: islandOrigin(screenMetrics: screenMetrics, islandSize: islandSize), size: islandSize)
    }

    func islandFrame(screenFrame: CGRect, islandSize: CGSize) -> CGRect {
        CGRect(origin: islandOrigin(screenFrame: screenFrame, islandSize: islandSize), size: islandSize)
    }
}
