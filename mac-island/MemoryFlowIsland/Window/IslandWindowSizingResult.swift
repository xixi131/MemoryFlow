import CoreGraphics
import Foundation

struct IslandWindowSizingDiagnostics: Equatable {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let requestedBaseBodyWidth: CGFloat?
    let requestedMaximumVisibleWidth: CGFloat?
    let requestedFixedVisibleWidth: CGFloat?
    let contentWidthRequirement: IslandContentWidthRequirement
    let visibleSize: CGSize
    let shadowSize: CGSize
    let contentSize: CGSize
    let hitTestFrame: CGRect

    var logSummary: String {
        [
            "state=\(state.rawValue)",
            "visualScale=\(formatted(visualScale))",
            "horizontalScale=\(formatted(horizontalScale))",
            "fixedVisibleWidth=\(requestedFixedVisibleWidth.map(formatted) ?? "nil")",
            "visibleSize=\(formatted(visibleSize))",
            "shadowSize=\(formatted(shadowSize))",
            "contentSize=\(formatted(contentSize))",
            "hitFrame=\(formatted(hitTestFrame))"
        ].joined(separator: " ")
    }

    private func formatted(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private func formatted(_ size: CGSize) -> String {
        "{w:\(formatted(size.width)),h:\(formatted(size.height))}"
    }

    private func formatted(_ rect: CGRect) -> String {
        "{x:\(formatted(rect.minX)),y:\(formatted(rect.minY)),w:\(formatted(rect.width)),h:\(formatted(rect.height))}"
    }
}

struct IslandWindowSizingResult: Equatable {
    let visibleFrame: CGRect
    let shadowFrame: CGRect
    let contentFrame: CGRect
    let hitTestFrame: CGRect
    let diagnostics: IslandWindowSizingDiagnostics

    var visibleSize: CGSize {
        visibleFrame.size
    }

    var shadowSize: CGSize {
        shadowFrame.size
    }

    var contentSize: CGSize {
        contentFrame.size
    }

    var shadowOutsets: IslandShadowOutsets {
        IslandShadowOutsets(
            horizontal: max(visibleFrame.minX - shadowFrame.minX, 0),
            bottom: max(visibleFrame.minY - shadowFrame.minY, 0)
        )
    }

    var debugSummary: String {
        diagnostics.logSummary
    }
}
