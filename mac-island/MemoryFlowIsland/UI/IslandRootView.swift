import SwiftUI

struct IslandRenderPresentation {
    var visualState: IslandVisualState
    var visualScale: CGFloat
    var horizontalScale: CGFloat
    var widthConstraints: IslandWidthConstraints
    var previewContent: IslandPreviewContent
    var musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    var todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    var reduceMotion: Bool
    var shapeMetrics: IslandShapeMetrics?
    var shapeState: IslandVisualState
    var shadowAppearance: IslandShadowAppearanceTokens?
    var shadowOutsets: IslandShadowOutsets?
    var contentPresentation: IslandContentPresentation

    static func initial(
        visualState: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat,
        widthConstraints: IslandWidthConstraints,
        previewContent: IslandPreviewContent,
        reduceMotion: Bool
    ) -> IslandRenderPresentation {
        IslandRenderPresentation(
            visualState: visualState,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints,
            previewContent: previewContent,
            musicTrackSwipeDirection: nil,
            todoToggleScenarioRequest: nil,
            reduceMotion: reduceMotion,
            shapeMetrics: nil,
            shapeState: visualState,
            shadowAppearance: nil,
            shadowOutsets: nil,
            contentPresentation: IslandContentPresentation(
                phase: .visible,
                opacity: 1,
                blurRadius: 0,
                scale: 1,
                offsetY: 0,
                allowsHitTesting: true
            )
        )
    }
}

@MainActor
final class IslandRenderModel: ObservableObject {
    @Published var presentation: IslandRenderPresentation

    var onAdvancePreviewState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicControlInteraction: (() -> Void)?
    var onTodoTaskInteraction: ((String) -> Void)?
    var onLoginRequested: (() -> Void)?

    init(presentation: IslandRenderPresentation) {
        self.presentation = presentation
    }
}

struct IslandRootView: View {
    @ObservedObject var model: IslandRenderModel

    var body: some View {
        let presentation = model.presentation

        IslandVisualStatePreview(
            state: presentation.visualState,
            visualScale: presentation.visualScale,
            horizontalScale: presentation.horizontalScale,
            widthConstraints: presentation.widthConstraints,
            previewContent: presentation.previewContent,
            musicTrackSwipeDirection: presentation.musicTrackSwipeDirection,
            todoToggleScenarioRequest: presentation.todoToggleScenarioRequest,
            reduceMotion: presentation.reduceMotion,
            presentationShapeMetrics: presentation.shapeMetrics,
            presentationShapeState: presentation.shapeState,
            presentationShadowAppearance: presentation.shadowAppearance,
            presentationShadowOutsets: presentation.shadowOutsets,
            contentPresentation: presentation.contentPresentation,
            onAdvanceState: model.onAdvancePreviewState,
            onGreetingLifecycleCompleted: model.onGreetingLifecycleCompleted,
            onMusicControlInteraction: model.onMusicControlInteraction,
            onTodoTaskInteraction: model.onTodoTaskInteraction,
            onLoginRequested: model.onLoginRequested
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
