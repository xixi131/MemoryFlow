import CoreGraphics

struct IslandWindowSizingDiagnostics: Equatable {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let requestedBaseBodyWidth: CGFloat?
    let requestedMaximumVisibleWidth: CGFloat?
    let contentWidthRequirement: IslandContentWidthRequirement
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
}
