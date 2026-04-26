import CoreGraphics

struct IslandShadowOutsets {
    static let zero = IslandShadowOutsets(horizontal: 0, bottom: 0)

    let horizontal: CGFloat
    let bottom: CGFloat
}

struct IslandShapeLayoutSnapshot {
    let state: IslandVisualState
    let metrics: IslandShapeMetrics
    let visibleFrame: CGRect
    let shadowOutsets: IslandShadowOutsets
    let contentFrame: CGRect
    let shadowFrame: CGRect
    let hitTestFrame: CGRect
    let bodyPath: CGPath
    let strokePath: CGPath?
    let leftCapPath: CGPath
    let rightCapPath: CGPath
    let leftEarPath: CGPath
    let rightEarPath: CGPath
}

enum IslandShapeEngine {
    static func snapshot(for state: IslandVisualState, visualScale: CGFloat) -> IslandShapeLayoutSnapshot {
        snapshot(for: state, visualScale: visualScale, horizontalScale: nil)
    }

    static func snapshot(
        for state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat?
    ) -> IslandShapeLayoutSnapshot {
        snapshot(
            for: IslandShapeMetrics.resolve(
                for: state,
                visualScale: visualScale,
                horizontalScale: horizontalScale
            ),
            state: state
        )
    }

    static func snapshot(for metrics: IslandShapeMetrics, state: IslandVisualState) -> IslandShapeLayoutSnapshot {
        let composedPaths = composeVisiblePaths(metrics: metrics)
        let shadowOutsets = shadowOutsets(for: state, metrics: metrics)
        let contentFrame = CGRect(
            origin: .zero,
            size: CGSize(
                width: composedPaths.visibleBounds.width + (shadowOutsets.horizontal * 2),
                height: composedPaths.visibleBounds.height + shadowOutsets.bottom
            )
        )
        let visibleFrame = CGRect(
            x: shadowOutsets.horizontal,
            y: 0,
            width: composedPaths.visibleBounds.width,
            height: composedPaths.visibleBounds.height
        )

        return IslandShapeLayoutSnapshot(
            state: state,
            metrics: metrics,
            visibleFrame: visibleFrame,
            shadowOutsets: shadowOutsets,
            contentFrame: contentFrame,
            shadowFrame: contentFrame,
            hitTestFrame: visibleFrame,
            bodyPath: translated(composedPaths.bodyPath, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)),
            strokePath: composedPaths.strokePath.map {
                translated($0, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY))
            },
            leftCapPath: translated(composedPaths.leftCapPath, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)),
            rightCapPath: translated(composedPaths.rightCapPath, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)),
            leftEarPath: translated(composedPaths.leftEarPath, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)),
            rightEarPath: translated(composedPaths.rightEarPath, by: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY))
        )
    }

    private static func composeVisiblePaths(metrics: IslandShapeMetrics) -> (
        visibleBounds: CGRect,
        bodyPath: CGPath,
        strokePath: CGPath?,
        leftCapPath: CGPath,
        rightCapPath: CGPath,
        leftEarPath: CGPath,
        rightEarPath: CGPath
    ) {
        let capWidth = IslandPathFactory.shellCapWidth
        let earWidth = IslandPathFactory.shellEarWidth

        var bodyPath = IslandPathFactory.squircleBodyPath(metrics: metrics)
        var strokePath = IslandPathFactory.openSquircleStrokePath(metrics: metrics)
        var leftCapPath = IslandPathFactory.leftCapPath(metrics: metrics)
        var rightCapPath = translated(
            IslandPathFactory.rightCapPath(metrics: metrics),
            by: CGPoint(x: metrics.width - capWidth, y: 0)
        )
        var leftEarPath = translated(
            IslandPathFactory.leftEarPath(metrics: metrics),
            by: CGPoint(x: -earWidth, y: 0)
        )
        var rightEarPath = translated(
            IslandPathFactory.rightEarPath(metrics: metrics),
            by: CGPoint(x: metrics.width, y: 0)
        )

        let visiblePaths = [bodyPath, leftCapPath, rightCapPath, leftEarPath, rightEarPath]

        if metrics.scale != 1 {
            let preScaleBounds = unionBounds(
                paths: visiblePaths + (strokePath.map { [$0] } ?? [])
            )
            let anchor = CGPoint(x: preScaleBounds.midX, y: preScaleBounds.minY)

            bodyPath = scaled(bodyPath, by: metrics.scale, anchor: anchor)
            strokePath = strokePath.map { scaled($0, by: metrics.scale, anchor: anchor) }
            leftCapPath = scaled(leftCapPath, by: metrics.scale, anchor: anchor)
            rightCapPath = scaled(rightCapPath, by: metrics.scale, anchor: anchor)
            leftEarPath = scaled(leftEarPath, by: metrics.scale, anchor: anchor)
            rightEarPath = scaled(rightEarPath, by: metrics.scale, anchor: anchor)
        }

        let visibleBounds = unionBounds(
            paths: [bodyPath, leftCapPath, rightCapPath, leftEarPath, rightEarPath] + (strokePath.map { [$0] } ?? [])
        )
        let normalizationOffset = CGPoint(x: -visibleBounds.minX, y: -visibleBounds.minY)

        return (
            visibleBounds: CGRect(origin: .zero, size: visibleBounds.size),
            bodyPath: translated(bodyPath, by: normalizationOffset),
            strokePath: strokePath.map { translated($0, by: normalizationOffset) },
            leftCapPath: translated(leftCapPath, by: normalizationOffset),
            rightCapPath: translated(rightCapPath, by: normalizationOffset),
            leftEarPath: translated(leftEarPath, by: normalizationOffset),
            rightEarPath: translated(rightEarPath, by: normalizationOffset)
        )
    }

    private static func shadowOutsets(for state: IslandVisualState, metrics: IslandShapeMetrics) -> IslandShadowOutsets {
        guard metrics.showsShadow else {
            return .zero
        }

        let tokenHeight = IslandVisualTokens.shell(for: state.tokenSet).height
        let visualScale = max(metrics.height / max(tokenHeight, 1), 0.78)

        switch state {
        case .hoverCollapsed:
            return IslandShadowOutsets(
                horizontal: 18 * visualScale,
                bottom: 24 * visualScale
            )
        case .expandedMusic, .expandedApp:
            return IslandShadowOutsets(
                horizontal: 26 * visualScale,
                bottom: 34 * visualScale
            )
        case .compactCollapsed, .activityCollapsed:
            return .zero
        }
    }

    private static func translated(_ path: CGPath, by offset: CGPoint) -> CGPath {
        let mutablePath = CGMutablePath()
        let transform = CGAffineTransform(translationX: offset.x, y: offset.y)
        mutablePath.addPath(path, transform: transform)
        return mutablePath
    }

    private static func scaled(_ path: CGPath, by scale: CGFloat, anchor: CGPoint) -> CGPath {
        let mutablePath = CGMutablePath()
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: anchor.x, y: anchor.y)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -anchor.x, y: -anchor.y)
        mutablePath.addPath(path, transform: transform)
        return mutablePath
    }

    private static func unionBounds(paths: [CGPath]) -> CGRect {
        paths.reduce(into: CGRect.null) { partialResult, path in
            partialResult = partialResult.union(path.boundingBoxOfPath)
        }
    }
}
