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

    /// The minimum body width for two content groups placed on opposite sides
    /// of the notch.  Mirroring the wider group keeps the shell visually
    /// centered even when a title or badge grows on just one side.
    var requiredBodyWidth: CGFloat {
        (max(max(leadingContentWidth, 0), max(trailingContentWidth, 0)) * 2) +
            (max(horizontalPadding, 0) * 2)
    }

    /// Kept for the Phase 5 probes that report a non-zero content demand.
    /// This is a complete body requirement, not an amount to add to the
    /// fallback shell width.
    var requiredExtensionWidth: CGFloat {
        requiredBodyWidth
    }

    var measuredContentWidth: CGFloat {
        max(leadingContentWidth, 0) +
            max(trailingContentWidth, 0) +
            (max(horizontalPadding, 0) * 2)
    }

    func merging(_ other: IslandContentWidthRequirement) -> IslandContentWidthRequirement {
        IslandContentWidthRequirement(
            leadingContentWidth: max(leadingContentWidth, other.leadingContentWidth),
            trailingContentWidth: max(trailingContentWidth, other.trailingContentWidth),
            horizontalPadding: max(horizontalPadding, other.horizontalPadding)
        )
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
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat,
        smoothness: CGFloat,
        earTension: CGFloat,
        earBlendHeight: CGFloat,
        scale: CGFloat,
        showsStroke: Bool,
        showsShadow: Bool
    ) {
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.radius = max(radius, 0)
        self.smoothness = max(smoothness, 0.01)
        self.earTension = max(earTension, 0)
        self.earBlendHeight = max(earBlendHeight, 0)
        self.scale = max(scale, 0.01)
        self.showsStroke = showsStroke
        self.showsShadow = showsShadow
    }

    init(
        state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat? = nil,
        widthConstraints: IslandWidthConstraints = .none
    ) {
        let resolvedVisualScale = max(visualScale, 0.01)
        let resolvedHorizontalScale = max(horizontalScale ?? resolvedVisualScale, 0.01)
        let shellTokens = IslandVisualTokens.shell(for: state.tokenSet)
        let isHoverCollapsed = state == .hoverCollapsed
        let hoverWidthScale = isHoverCollapsed ? IslandVisualTokens.hover.collapsedWidthScale : 1
        let resolvedHeight = (isHoverCollapsed
            ? IslandVisualTokens.hover.collapsedHeight
            : shellTokens.height) * resolvedVisualScale
        let resolvedEarBlendHeight = shellTokens.earBlendHeight * resolvedVisualScale
        let tokenWidth = shellTokens.previewWidth * resolvedHorizontalScale
        let baseBodyWidth = max(widthConstraints.baseBodyWidth ?? tokenWidth, 0)
        let contentDrivenWidth = max(
            baseBodyWidth,
            widthConstraints.contentWidthRequirement.requiredBodyWidth
        )
        let unconstrainedWidth = max(tokenWidth, contentDrivenWidth) * hoverWidthScale
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
        scale = 1
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

    func interpolated(to target: IslandShapeMetrics, progress: CGFloat) -> IslandShapeMetrics {
        let t = min(max(progress, 0), 1)
        func lerp(_ start: CGFloat, _ end: CGFloat) -> CGFloat { start + ((end - start) * t) }

        return IslandShapeMetrics(
            width: lerp(width, target.width),
            height: lerp(height, target.height),
            radius: lerp(radius, target.radius),
            smoothness: lerp(smoothness, target.smoothness),
            earTension: lerp(earTension, target.earTension),
            earBlendHeight: lerp(earBlendHeight, target.earBlendHeight),
            scale: lerp(scale, target.scale),
            showsStroke: t >= 0.5 ? target.showsStroke : showsStroke,
            showsShadow: t >= 0.5 ? target.showsShadow : showsShadow
        )
    }
}
