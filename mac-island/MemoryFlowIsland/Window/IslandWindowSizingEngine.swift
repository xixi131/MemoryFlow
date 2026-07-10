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

    /// Rebuilds a presentation sample around the immutable display top-center anchor.
    /// The motion layer owns progress; window layout owns the resulting interactive geometry.
    static func resolveAnimatedSample(
        from source: IslandWindowSizingResult,
        to target: IslandWindowSizingResult,
        progress: CGFloat,
        attachmentMetrics: TopAttachmentMetrics
    ) -> IslandWindowSizingResult {
        let fraction = min(max(progress, 0), 1)
        let visibleSize = interpolated(source.visibleSize, target.visibleSize, fraction)
        let shadowOutsets = interpolated(source.shadowOutsets, target.shadowOutsets, fraction)
        // Align the size, then derive origin from the immutable attachment point. Rounding
        // both origin and width independently moves odd-pixel samples off center by half a pixel.
        let alignedVisibleSize = CGSize(
            width: pixelAligned(visibleSize.width, scale: attachmentMetrics.pixelScale),
            height: pixelAligned(visibleSize.height, scale: attachmentMetrics.pixelScale)
        )
        let visibleFrame = CGRect(
            x: attachmentMetrics.centerX - (alignedVisibleSize.width / 2),
            y: attachmentMetrics.topBandFrame.maxY - alignedVisibleSize.height,
            width: alignedVisibleSize.width,
            height: alignedVisibleSize.height
        )
        let provisionalShadowFrame = pixelAligned(
            CGRect(
                x: visibleFrame.minX - shadowOutsets.horizontal,
                y: visibleFrame.minY - shadowOutsets.bottom,
                width: visibleFrame.width + (shadowOutsets.horizontal * 2),
                height: visibleFrame.height + shadowOutsets.bottom
            ),
            scale: attachmentMetrics.pixelScale
        )
        let contentFrame = anchoredFrame(
            source.contentFrame,
            target.contentFrame,
            sourceVisibleFrame: source.visibleFrame,
            targetVisibleFrame: target.visibleFrame,
            visibleFrame: visibleFrame,
            progress: fraction,
            scale: attachmentMetrics.pixelScale
        )
        let hitTestFrame = anchoredFrame(
            source.hitTestFrame,
            target.hitTestFrame,
            sourceVisibleFrame: source.visibleFrame,
            targetVisibleFrame: target.visibleFrame,
            visibleFrame: visibleFrame,
            progress: fraction,
            scale: attachmentMetrics.pixelScale
        )
        let requiredBounds = visibleFrame.union(contentFrame).union(hitTestFrame)
        let protectedOutsets = IslandShadowOutsets(
            horizontal: max(
                shadowOutsets.horizontal,
                visibleFrame.minX - requiredBounds.minX,
                requiredBounds.maxX - visibleFrame.maxX
            ),
            bottom: max(shadowOutsets.bottom, visibleFrame.minY - requiredBounds.minY)
        )
        let shadowFrame = pixelAligned(
            CGRect(
                x: visibleFrame.minX - protectedOutsets.horizontal,
                y: visibleFrame.minY - protectedOutsets.bottom,
                width: visibleFrame.width + (protectedOutsets.horizontal * 2),
                height: max(provisionalShadowFrame.maxY, requiredBounds.maxY) - (visibleFrame.minY - protectedOutsets.bottom)
            ),
            scale: attachmentMetrics.pixelScale
        )

        return IslandWindowSizingResult(
            visibleFrame: visibleFrame,
            shadowFrame: shadowFrame,
            contentFrame: contentFrame,
            hitTestFrame: hitTestFrame,
            diagnostics: IslandWindowSizingDiagnostics(
                state: fraction < 1 ? source.diagnostics.state : target.diagnostics.state,
                visualScale: interpolated(source.diagnostics.visualScale, target.diagnostics.visualScale, fraction),
                horizontalScale: interpolated(source.diagnostics.horizontalScale, target.diagnostics.horizontalScale, fraction),
                requestedBaseBodyWidth: target.diagnostics.requestedBaseBodyWidth,
                requestedMaximumVisibleWidth: target.diagnostics.requestedMaximumVisibleWidth,
                contentWidthRequirement: target.diagnostics.contentWidthRequirement,
                visibleSize: visibleFrame.size,
                shadowSize: shadowFrame.size,
                contentSize: contentFrame.size,
                hitTestFrame: hitTestFrame
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

    private static func anchoredFrame(
        _ source: CGRect,
        _ target: CGRect,
        sourceVisibleFrame: CGRect,
        targetVisibleFrame: CGRect,
        visibleFrame: CGRect,
        progress: CGFloat,
        scale: CGFloat
    ) -> CGRect {
        let sourceOffset = source.offsetBy(dx: -sourceVisibleFrame.minX, dy: -sourceVisibleFrame.minY)
        let targetOffset = target.offsetBy(dx: -targetVisibleFrame.minX, dy: -targetVisibleFrame.minY)
        let offset = interpolated(sourceOffset, targetOffset, progress)
        return pixelAligned(offset.offsetBy(dx: visibleFrame.minX, dy: visibleFrame.minY), scale: scale)
    }

    private static func interpolated(_ source: CGSize, _ target: CGSize, _ progress: CGFloat) -> CGSize {
        CGSize(width: interpolated(source.width, target.width, progress), height: interpolated(source.height, target.height, progress))
    }

    private static func interpolated(_ source: CGRect, _ target: CGRect, _ progress: CGFloat) -> CGRect {
        CGRect(
            x: interpolated(source.minX, target.minX, progress),
            y: interpolated(source.minY, target.minY, progress),
            width: interpolated(source.width, target.width, progress),
            height: interpolated(source.height, target.height, progress)
        )
    }

    private static func interpolated(_ source: IslandShadowOutsets, _ target: IslandShadowOutsets, _ progress: CGFloat) -> IslandShadowOutsets {
        IslandShadowOutsets(horizontal: interpolated(source.horizontal, target.horizontal, progress), bottom: interpolated(source.bottom, target.bottom, progress))
    }

    private static func interpolated(_ source: CGFloat, _ target: CGFloat, _ progress: CGFloat) -> CGFloat {
        source + ((target - source) * progress)
    }
}
