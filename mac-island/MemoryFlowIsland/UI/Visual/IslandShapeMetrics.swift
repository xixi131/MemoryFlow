import CoreGraphics

struct IslandShapeMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let smoothness: CGFloat
    let earTension: CGFloat
    let earBlendHeight: CGFloat
    let scale: CGFloat
    let showsStroke: Bool
    let showsShadow: Bool

    init(state: IslandVisualState, visualScale: CGFloat, horizontalScale: CGFloat? = nil) {
        let resolvedVisualScale = max(visualScale, 0.01)
        let resolvedHorizontalScale = max(horizontalScale ?? resolvedVisualScale, 0.01)
        let shellTokens = IslandVisualTokens.shell(for: state.tokenSet)

        width = shellTokens.previewWidth * resolvedHorizontalScale
        height = shellTokens.height * resolvedVisualScale
        radius = shellTokens.radius * resolvedVisualScale
        smoothness = shellTokens.smoothness
        earTension = shellTokens.earTension
        earBlendHeight = shellTokens.earBlendHeight * resolvedVisualScale
        scale = state == .hoverCollapsed ? IslandVisualTokens.hover.collapsedScale : 1
        showsStroke = state.isExpanded && shellTokens.showsStroke
        showsShadow = state.allowsShadow
    }

    static func resolve(
        for state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat? = nil
    ) -> IslandShapeMetrics {
        IslandShapeMetrics(
            state: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale
        )
    }
}
