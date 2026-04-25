import CoreGraphics

enum IslandPathFactory {
    private static let squircleSteps = 30

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

    static func squircleBodyPath(metrics: IslandShapeMetrics) -> CGPath {
        squircleBodyPath(
            width: metrics.width,
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness
        )
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
