import AppKit

enum DisplayTopEdge {
    case notchBearing
    case flatTop
}

struct DisplayTopEdgeClassifier {
    func classify(_ screenMetrics: ScreenMetrics) -> DisplayTopEdge {
        if screenMetrics.notchFrame != nil {
            return .notchBearing
        }

        return .flatTop
    }
}
