import SwiftUI

struct IslandRootView: View {
    let previewState: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let previewContent: IslandPreviewContent
    var onAdvancePreviewState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?

    var body: some View {
        IslandVisualStatePreview(
            state: previewState,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints,
            previewContent: previewContent,
            onAdvanceState: onAdvancePreviewState,
            onGreetingLifecycleCompleted: onGreetingLifecycleCompleted
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
