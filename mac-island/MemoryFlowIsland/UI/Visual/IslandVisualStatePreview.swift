import SwiftUI

struct IslandVisualStatePreview: View {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    var onAdvanceState: (() -> Void)?

    private var snapshot: IslandShapeLayoutSnapshot {
        IslandShapeEngine.snapshot(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale
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
                .animation(
                    .easeOut(duration: IslandVisualTokens.shadow.fadeDuration),
                    value: state
                )
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
    }

    private func shadowColor(for snapshot: IslandShapeLayoutSnapshot) -> Color {
        guard snapshot.metrics.showsShadow else {
            return .clear
        }

        return Color.black.opacity(snapshot.state.isExpanded ? 0.34 : 0.28)
    }

    private func shadowRadius(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        guard snapshot.metrics.showsShadow else {
            return 0
        }

        return snapshot.state.isExpanded
            ? 18 * visualScale
            : 12 * visualScale
    }

    private func shadowOffsetY(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        guard snapshot.metrics.showsShadow else {
            return 0
        }

        return snapshot.state.isExpanded
            ? 18 * visualScale
            : 10 * visualScale
    }
}
