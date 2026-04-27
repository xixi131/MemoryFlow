import SwiftUI

struct IslandVisualStatePreview: View {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let motionPlan: IslandMotionPlan?
    var onAdvanceState: (() -> Void)?

    private var snapshot: IslandShapeLayoutSnapshot {
        IslandShapeEngine.snapshot(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints
        )
    }

    var body: some View {
        let snapshot = snapshot

        ZStack(alignment: .topLeading) {
            composedShapeLayer(snapshot: snapshot)
                .shadow(
                    color: shadowColor(for: snapshot),
                    radius: shadowRadius(for: snapshot),
                    x: 0,
                    y: shadowOffsetY(for: snapshot)
                )
                // Window sizing is y-up; SwiftUI renders top-leading, so keep shell attached and leave shadow buffer below.
                .offset(y: -snapshot.shadowOutsets.bottom)
                .animation(shadowAnimation, value: state)

            previewContentVisibilityLayer(snapshot: snapshot)
        }
        .frame(
            width: snapshot.contentFrame.width,
            height: snapshot.contentFrame.height,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onAdvanceState?()
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private func composedShapeLayer(snapshot: IslandShapeLayoutSnapshot) -> some View {
        ZStack(alignment: .topLeading) {
            Path(snapshot.leftCapPath)
                .fill(Color.black)
            Path(snapshot.rightCapPath)
                .fill(Color.black)
            Path(snapshot.leftEarPath)
                .fill(Color.black)
            Path(snapshot.rightEarPath)
                .fill(Color.black)
            Path(snapshot.bodyPath)
                .fill(Color.black)

            if let strokePath = snapshot.strokePath {
                Path(strokePath)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .frame(
            width: snapshot.contentFrame.width,
            height: snapshot.contentFrame.height,
            alignment: .topLeading
        )
        .animation(shellAnimation, value: state)
    }

    @ViewBuilder
    private func previewContentVisibilityLayer(snapshot: IslandShapeLayoutSnapshot) -> some View {
        let visibility = contentVisibilityInput(for: snapshot)

        Color.clear
            .frame(
                width: snapshot.contentFrame.width,
                height: snapshot.contentFrame.height,
                alignment: .topLeading
            )
            .opacity(visibility.opacity)
            .blur(radius: visibility.blurRadius)
            .animation(contentAnimation(for: visibility), value: state)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func shadowColor(for snapshot: IslandShapeLayoutSnapshot) -> Color {
        guard snapshot.metrics.showsShadow else {
            return .clear
        }

        return Color.black.opacity(shadowAppearance(for: snapshot).opacity)
    }

    private func shadowRadius(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        guard snapshot.metrics.showsShadow else {
            return 0
        }

        return shadowAppearance(for: snapshot).radius
    }

    private func shadowOffsetY(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        guard snapshot.metrics.showsShadow else {
            return 0
        }

        return shadowAppearance(for: snapshot).offsetY
    }

    private var shellAnimation: Animation {
        guard let motionPlan else {
            return .easeOut(duration: IslandVisualTokens.shadow.fadeDuration)
        }

        let spring = motionPlan.shellFrame.spring
        return .interpolatingSpring(
            mass: Double(spring.mass),
            stiffness: Double(spring.stiffness),
            damping: Double(spring.damping),
            initialVelocity: 0
        )
    }

    private var shadowAnimation: Animation {
        guard let shadowMotion = motionPlan?.shadow else {
            return .easeOut(duration: IslandVisualTokens.shadow.fadeDuration)
        }

        return animation(
            curve: shadowMotion.animation.curve,
            duration: shadowMotion.animation.duration
        )
    }

    private func shadowAppearance(for snapshot: IslandShapeLayoutSnapshot) -> IslandShadowAppearanceTokens {
        if let shadowMotion = motionPlan?.shadow {
            return IslandShadowAppearanceTokens(
                opacity: shadowMotion.targetOpacity,
                radius: shadowMotion.targetRadius,
                offsetY: shadowMotion.targetOffsetY
            )
        }

        return IslandVisualTokens.shadow.appearance(
            for: snapshot.state,
            visualScale: visualScale
        )
    }

    private func contentVisibilityInput(for snapshot: IslandShapeLayoutSnapshot) -> IslandPreviewContentVisibilityInput {
        guard let motionPlan else {
            return snapshot.state == .compactCollapsed
                ? .hidden
                : IslandPreviewContentVisibilityInput(
                    opacity: 1,
                    blurRadius: 0,
                    delay: 0,
                    duration: 0.12,
                    curve: .easeOut
                )
        }

        return snapshot.state == .compactCollapsed
            ? motionPlan.contentVisibility.hidden
            : motionPlan.contentVisibility.visible
    }

    private func contentAnimation(for visibility: IslandPreviewContentVisibilityInput) -> Animation {
        animation(curve: visibility.curve, duration: visibility.duration).delay(visibility.delay)
    }

    private func animation(curve: IslandMotionTimingCurve, duration: TimeInterval) -> Animation {
        switch curve {
        case .easeInOut:
            return .easeInOut(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .linear:
            return .linear(duration: duration)
        }
    }
}
