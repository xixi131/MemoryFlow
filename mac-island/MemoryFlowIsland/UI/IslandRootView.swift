import SwiftUI

struct IslandRootView: View {
    let previewState: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    var onAdvancePreviewState: (() -> Void)?

    var body: some View {
        IslandVisualStatePreview(
            state: previewState,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            onAdvanceState: onAdvancePreviewState
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
