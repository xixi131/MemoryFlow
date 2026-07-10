import SwiftUI

struct IslandRootView: View {
    let previewState: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let previewContent: IslandPreviewContent
    let musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    var onAdvancePreviewState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicControlInteraction: (() -> Void)?

    var body: some View {
        IslandVisualStatePreview(
            state: previewState,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints,
            previewContent: previewContent,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            onAdvanceState: onAdvancePreviewState,
            onGreetingLifecycleCompleted: onGreetingLifecycleCompleted,
            onMusicControlInteraction: onMusicControlInteraction
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
