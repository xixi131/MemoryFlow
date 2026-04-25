import SwiftUI

struct IslandRootView: View {
    let previewState: IslandVisualState
    let visualScale: CGFloat
    var onAdvancePreviewState: (() -> Void)?

    var body: some View {
        IslandVisualStatePreview(
            state: previewState,
            visualScale: visualScale,
            onAdvanceState: onAdvancePreviewState
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
