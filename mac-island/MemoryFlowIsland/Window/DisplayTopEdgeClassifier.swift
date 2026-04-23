import AppKit

enum DisplayTopEdge {
    case notchBearing
    case flatTop
}

struct DisplayTopEdgeClassifier {
    func classify(_ screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        if screenMetrics.safeAreaInsets.top > 0 {
            return .notchBearing
        }

        return .flatTop
    }
}
