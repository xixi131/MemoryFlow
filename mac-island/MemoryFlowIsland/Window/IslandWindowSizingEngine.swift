import CoreGraphics

struct IslandWindowSizingRequest: Equatable {
    let state: IslandVisualState
    let attachmentMetrics: TopAttachmentMetrics
    let widthConstraints: IslandWidthConstraints
}

enum IslandWindowSizingEngine {
    static func resolve(_ request: IslandWindowSizingRequest) -> IslandWindowSizingResult {
        let resolvedConstraints = resolvedWidthConstraints(for: request)
        let snapshot = IslandShapeEngine.snapshot(
            for: request.state,
            visualScale: request.attachmentMetrics.visualScale,
            horizontalScale: request.attachmentMetrics.horizontalVisualScale,
            widthConstraints: resolvedConstraints
        )

        return result(
            from: snapshot,
            request: request,
            resolvedWidthConstraints: resolvedConstraints
        )
    }

    static func resolve(
        state: IslandVisualState,
        attachmentMetrics: TopAttachmentMetrics,
        widthConstraints: IslandWidthConstraints
    ) -> IslandWindowSizingResult {
        resolve(
            IslandWindowSizingRequest(
                state: state,
                attachmentMetrics: attachmentMetrics,
                widthConstraints: widthConstraints
            )
        )
    }

    private static func resolvedWidthConstraints(for request: IslandWindowSizingRequest) -> IslandWidthConstraints {
        let initialSnapshot = IslandShapeEngine.snapshot(
            for: request.state,
            visualScale: request.attachmentMetrics.visualScale,
            horizontalScale: request.attachmentMetrics.horizontalVisualScale,
            widthConstraints: request.widthConstraints
        )

        let requestedMaximumVisibleWidth = request.widthConstraints.maximumVisibleWidth
            ?? request.attachmentMetrics.availableTopWidth
        let shadowAwareMaximumVisibleWidth = max(
            request.attachmentMetrics.availableTopWidth - (initialSnapshot.shadowOutsets.horizontal * 2),
            1
        )
        let effectiveMaximumVisibleWidth = min(
            requestedMaximumVisibleWidth,
            shadowAwareMaximumVisibleWidth
        )

        return IslandWidthConstraints(
            baseBodyWidth: request.widthConstraints.baseBodyWidth,
            maximumVisibleWidth: effectiveMaximumVisibleWidth,
            contentWidthRequirement: request.widthConstraints.contentWidthRequirement
        )
    }

    private static func result(
        from snapshot: IslandShapeLayoutSnapshot,
        request: IslandWindowSizingRequest,
        resolvedWidthConstraints: IslandWidthConstraints
    ) -> IslandWindowSizingResult {
        let attachmentMetrics = request.attachmentMetrics
        let shadowSize = snapshot.shadowFrame.size
        let displayMinX = attachmentMetrics.centerX - (attachmentMetrics.availableTopWidth / 2)
        let displayMaxX = displayMinX + attachmentMetrics.availableTopWidth
        let centeredShadowOriginX = attachmentMetrics.centerX - (shadowSize.width / 2)
        let shadowOriginX: CGFloat

        if shadowSize.width <= attachmentMetrics.availableTopWidth {
            shadowOriginX = clamped(
                centeredShadowOriginX,
                min: displayMinX,
                max: displayMaxX - shadowSize.width
            )
        } else {
            shadowOriginX = centeredShadowOriginX
        }

        let shadowOriginY = attachmentMetrics.topBandFrame.maxY - shadowSize.height
        let shadowFrame = pixelAligned(
            CGRect(origin: CGPoint(x: shadowOriginX, y: shadowOriginY), size: shadowSize),
            scale: attachmentMetrics.pixelScale
        )
        let visibleFrame = pixelAligned(
            snapshot.visibleFrame.offsetBy(dx: shadowFrame.minX, dy: shadowFrame.minY),
            scale: attachmentMetrics.pixelScale
        )
        let contentFrame = pixelAligned(
            snapshot.contentFrame.offsetBy(dx: shadowFrame.minX, dy: shadowFrame.minY),
            scale: attachmentMetrics.pixelScale
        )
        let hitTestFrame = pixelAligned(
            snapshot.hitTestFrame.offsetBy(dx: shadowFrame.minX, dy: shadowFrame.minY),
            scale: attachmentMetrics.pixelScale
        )

        return IslandWindowSizingResult(
            visibleFrame: visibleFrame,
            shadowFrame: shadowFrame,
            contentFrame: contentFrame,
            hitTestFrame: hitTestFrame,
            diagnostics: IslandWindowSizingDiagnostics(
                state: request.state,
                visualScale: attachmentMetrics.visualScale,
                horizontalScale: attachmentMetrics.horizontalVisualScale,
                requestedBaseBodyWidth: resolvedWidthConstraints.baseBodyWidth,
                requestedMaximumVisibleWidth: resolvedWidthConstraints.maximumVisibleWidth,
                contentWidthRequirement: resolvedWidthConstraints.contentWidthRequirement,
                visibleSize: visibleFrame.size,
                shadowSize: shadowFrame.size,
                contentSize: contentFrame.size,
                hitTestFrame: hitTestFrame
            )
        )
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let safeScale = max(scale, 1)
        return CGRect(
            x: pixelAligned(rect.origin.x, scale: safeScale),
            y: pixelAligned(rect.origin.y, scale: safeScale),
            width: pixelAligned(rect.size.width, scale: safeScale),
            height: pixelAligned(rect.size.height, scale: safeScale)
        )
    }

    private static func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }
}
