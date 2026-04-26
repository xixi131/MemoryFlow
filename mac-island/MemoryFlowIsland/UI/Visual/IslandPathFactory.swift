import CoreGraphics

enum IslandPathFactory {
    private static let capWidth: CGFloat = 60
    private static let earWidth: CGFloat = 40
    private static let earTipExtension: CGFloat = 4
    private static let earBodyOverlap: CGFloat = 1
    private static let earCurveSteps = 28
    private static let squircleSteps = 30

    static var shellCapWidth: CGFloat { capWidth }
    static var shellEarWidth: CGFloat { earWidth }
    static var shellEarBodyOverlap: CGFloat { earBodyOverlap }
    static var shellEarTipExtension: CGFloat { earTipExtension }

    static func squircleBodyPath(width: CGFloat, height: CGFloat, radius: CGFloat, smoothness: CGFloat) -> CGPath {
        let resolvedWidth = max(width, 0)
        let resolvedHeight = max(height, 0)
        let resolvedRadius = min(radius, resolvedWidth / 2, resolvedHeight / 2)
        let resolvedSmoothness = max(smoothness, 0.01)

        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: resolvedWidth, y: 0))
        path.addLine(to: CGPoint(x: resolvedWidth, y: resolvedHeight - resolvedRadius))

        let bottomRightCenter = CGPoint(x: resolvedWidth - resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomRightCenter.x + superellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomRightCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        path.addLine(to: CGPoint(x: resolvedRadius, y: resolvedHeight))

        let bottomLeftCenter = CGPoint(x: resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) + (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomLeftCenter.x + signedSuperellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomLeftCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        path.addLine(to: .zero)
        path.closeSubpath()
        return path
    }

    static func openSquircleStrokePath(width: CGFloat, height: CGFloat, radius: CGFloat, smoothness: CGFloat) -> CGPath {
        let resolvedWidth = max(width, 0)
        let resolvedHeight = max(height, 0)
        let resolvedRadius = min(radius, resolvedWidth / 2, resolvedHeight / 2)
        let resolvedSmoothness = max(smoothness, 0.01)

        let path = CGMutablePath()
        // 展开态描边只作为底部边缘高光使用，不能画到左右侧边。
        // 如果从 y=0 开始画左右竖线，线会压在液态连接与主体的交界处，形成灰色缝。
        path.move(to: CGPoint(x: resolvedWidth, y: resolvedHeight - resolvedRadius))

        let bottomRightCenter = CGPoint(x: resolvedWidth - resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomRightCenter.x + superellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomRightCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        path.addLine(to: CGPoint(x: resolvedRadius, y: resolvedHeight))

        let bottomLeftCenter = CGPoint(x: resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) + (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomLeftCenter.x + signedSuperellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomLeftCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        return path
    }

    static func squircleBodyPath(metrics: IslandShapeMetrics) -> CGPath {
        squircleBodyPath(
            width: metrics.width,
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness
        )
    }

    static func openSquircleStrokePath(metrics: IslandShapeMetrics) -> CGPath? {
        guard metrics.showsStroke else {
            return nil
        }

        return openSquircleStrokePath(
            width: metrics.width,
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness
        )
    }

    static func leftCapPath(height: CGFloat, radius: CGFloat, smoothness: CGFloat) -> CGPath {
        let resolvedHeight = max(height, 0)
        let resolvedRadius = min(max(radius, 0), resolvedHeight / 2)
        let resolvedSmoothness = max(smoothness, 0.01)

        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: capWidth, y: 0))
        path.addLine(to: CGPoint(x: capWidth, y: resolvedHeight))
        path.addLine(to: CGPoint(x: resolvedRadius, y: resolvedHeight))

        let bottomLeftCenter = CGPoint(x: resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) + (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomLeftCenter.x + signedSuperellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomLeftCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        path.addLine(to: .zero)
        path.closeSubpath()
        return path
    }

    static func leftCapPath(metrics: IslandShapeMetrics) -> CGPath {
        leftCapPath(
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness
        )
    }

    static func rightCapPath(height: CGFloat, radius: CGFloat, smoothness: CGFloat) -> CGPath {
        let resolvedHeight = max(height, 0)
        let resolvedRadius = min(max(radius, 0), resolvedHeight / 2)
        let resolvedSmoothness = max(smoothness, 0.01)

        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: capWidth, y: 0))
        path.addLine(to: CGPoint(x: capWidth, y: resolvedHeight - resolvedRadius))

        let bottomRightCenter = CGPoint(x: capWidth - resolvedRadius, y: resolvedHeight - resolvedRadius)
        for index in 1...squircleSteps {
            let angle = (.pi / 2) * (CGFloat(index) / CGFloat(squircleSteps))
            path.addLine(
                to: CGPoint(
                    x: bottomRightCenter.x + superellipseComponent(for: cos(angle), smoothness: resolvedSmoothness) * resolvedRadius,
                    y: bottomRightCenter.y + superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness) * resolvedRadius
                )
            )
        }

        path.addLine(to: CGPoint(x: 0, y: resolvedHeight))
        path.closeSubpath()
        return path
    }

    static func rightCapPath(metrics: IslandShapeMetrics) -> CGPath {
        rightCapPath(
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness
        )
    }

    static func earPath(isLeft: Bool, tension: CGFloat, blendHeight: CGFloat, smoothness: CGFloat) -> CGPath {
        let resolvedTension = max(tension, 0)
        let resolvedBlendHeight = max(blendHeight, 0)
        let resolvedSmoothness = max(smoothness, 0.01)
        // 液态连接的最终外扩宽度 = 下探高度 * 横向张力 + 顶边延展。
        // 日常调大小请改 IslandVisualTokens.swift 里的 earTension / earBlendHeight / smoothness，不要直接改这里的公式。
        let curveReach = (resolvedBlendHeight * resolvedTension) + earTipExtension

        let edgeX = isLeft ? earWidth : 0
        let inwardOverlapX = isLeft
            ? edgeX + earBodyOverlap
            : edgeX - earBodyOverlap
        let direction: CGFloat = isLeft ? -1 : 1

        let path = CGMutablePath()
        path.move(to: CGPoint(x: edgeX, y: resolvedBlendHeight))

        for index in 1...earCurveSteps {
            let angle = (.pi / 2) * (CGFloat(index) / CGFloat(earCurveSteps))
            let xOffset = curveReach * (1 - superellipseComponent(for: cos(angle), smoothness: resolvedSmoothness))
            let yOffset = resolvedBlendHeight * (1 - superellipseComponent(for: sin(angle), smoothness: resolvedSmoothness))

            path.addLine(to: CGPoint(
                x: edgeX + (direction * xOffset),
                y: yOffset
            ))
        }

        path.addLine(to: CGPoint(x: inwardOverlapX, y: 0))
        path.addLine(to: CGPoint(x: inwardOverlapX, y: resolvedBlendHeight))
        path.closeSubpath()
        return path
    }

    static func leftEarPath(tension: CGFloat, blendHeight: CGFloat) -> CGPath {
        earPath(
            isLeft: true,
            tension: tension,
            blendHeight: blendHeight,
            smoothness: IslandVisualTokens.compact.smoothness
        )
    }

    static func leftEarPath(metrics: IslandShapeMetrics) -> CGPath {
        leftEarPath(
            tension: metrics.earTension,
            blendHeight: metrics.earBlendHeight,
            smoothness: metrics.smoothness
        )
    }

    static func leftEarPath(tension: CGFloat, blendHeight: CGFloat, smoothness: CGFloat) -> CGPath {
        earPath(isLeft: true, tension: tension, blendHeight: blendHeight, smoothness: smoothness)
    }

    static func rightEarPath(tension: CGFloat, blendHeight: CGFloat) -> CGPath {
        earPath(
            isLeft: false,
            tension: tension,
            blendHeight: blendHeight,
            smoothness: IslandVisualTokens.compact.smoothness
        )
    }

    static func rightEarPath(metrics: IslandShapeMetrics) -> CGPath {
        rightEarPath(
            tension: metrics.earTension,
            blendHeight: metrics.earBlendHeight,
            smoothness: metrics.smoothness
        )
    }

    static func rightEarPath(tension: CGFloat, blendHeight: CGFloat, smoothness: CGFloat) -> CGPath {
        earPath(isLeft: false, tension: tension, blendHeight: blendHeight, smoothness: smoothness)
    }

    private static func superellipseComponent(for value: CGFloat, smoothness: CGFloat) -> CGFloat {
        pow(abs(value), 2 / smoothness)
    }

    private static func signedSuperellipseComponent(for value: CGFloat, smoothness: CGFloat) -> CGFloat {
        if value == 0 {
            return 0
        }

        return value.sign == .minus
            ? -superellipseComponent(for: value, smoothness: smoothness)
            : superellipseComponent(for: value, smoothness: smoothness)
    }
}
