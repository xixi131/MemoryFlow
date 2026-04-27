import CoreGraphics

struct IslandContentWidthRequirement: Equatable {
    static let none = IslandContentWidthRequirement(
        leadingContentWidth: 0,
        trailingContentWidth: 0,
        horizontalPadding: 0
    )

    let leadingContentWidth: CGFloat
    let trailingContentWidth: CGFloat
    let horizontalPadding: CGFloat

    var requiredExtensionWidth: CGFloat {
        max(leadingContentWidth, 0) +
            max(trailingContentWidth, 0) +
            (max(horizontalPadding, 0) * 2)
    }
}

struct IslandWidthConstraints: Equatable {
    static let none = IslandWidthConstraints(
        baseBodyWidth: nil,
        maximumVisibleWidth: nil,
        contentWidthRequirement: .none
    )

    let baseBodyWidth: CGFloat?
    let maximumVisibleWidth: CGFloat?
    let contentWidthRequirement: IslandContentWidthRequirement
}

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

    init(
        state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat? = nil,
        widthConstraints: IslandWidthConstraints = .none
    ) {
        let resolvedVisualScale = max(visualScale, 0.01)
        let resolvedHorizontalScale = max(horizontalScale ?? resolvedVisualScale, 0.01)
        let shellTokens = IslandVisualTokens.shell(for: state.tokenSet)
        let resolvedHeight = shellTokens.height * resolvedVisualScale
        let resolvedEarBlendHeight = shellTokens.earBlendHeight * resolvedVisualScale
        let tokenWidth = shellTokens.previewWidth * resolvedHorizontalScale
        let baseBodyWidth = max(widthConstraints.baseBodyWidth ?? tokenWidth, 0)
        let contentDrivenWidth = baseBodyWidth + widthConstraints.contentWidthRequirement.requiredExtensionWidth
        let unconstrainedWidth = max(tokenWidth, contentDrivenWidth)
        let earReach = (resolvedEarBlendHeight * shellTokens.earTension) + IslandPathFactory.shellEarTipExtension
        let maximumBodyWidth = widthConstraints.maximumVisibleWidth.map {
            max($0 - (earReach * 2), 1)
        }

        width = maximumBodyWidth.map { min(unconstrainedWidth, $0) } ?? unconstrainedWidth
        height = resolvedHeight
        radius = shellTokens.radius * resolvedVisualScale
        smoothness = shellTokens.smoothness
        earTension = shellTokens.earTension
        earBlendHeight = resolvedEarBlendHeight
        scale = state == .hoverCollapsed ? IslandVisualTokens.hover.collapsedScale : 1
        showsStroke = state.isExpanded && shellTokens.showsStroke
        showsShadow = state.allowsShadow
    }

    static func resolve(
        for state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat? = nil,
        widthConstraints: IslandWidthConstraints = .none
    ) -> IslandShapeMetrics {
        IslandShapeMetrics(
            state: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints
        )
    }
}
