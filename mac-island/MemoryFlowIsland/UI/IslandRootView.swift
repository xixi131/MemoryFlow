import SwiftUI

struct IslandRenderPresentation {
    var visualState: IslandVisualState
    var visualScale: CGFloat
    var horizontalScale: CGFloat
    var widthConstraints: IslandWidthConstraints
    var expandedContentTopInset: CGFloat
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
        expandedContentTopInset: CGFloat = IslandVisualTokens.compact.height,
        previewContent: IslandPreviewContent,
        reduceMotion: Bool
    ) -> IslandRenderPresentation {
        IslandRenderPresentation(
            visualState: visualState,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints,
            expandedContentTopInset: expandedContentTopInset,
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
    let waveformModel: MusicWaveformModel

    var onAdvancePreviewState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicCommand: ((MusicCommand) -> Void)?
    var onMusicSeek: ((TimeInterval) -> Void)?
    var onMusicSeekInteractionStarted: (() -> Void)?
    var onTodoTaskInteraction: ((String) -> Void)?
    var onLoginRequested: (() -> Void)?
    var onUpdateRequested: (() -> Void)?
    var onUpdateLaterRequested: (() -> Void)?

    init(
        presentation: IslandRenderPresentation,
        waveformModel: MusicWaveformModel = MusicWaveformModel()
    ) {
        self.presentation = presentation
        self.waveformModel = waveformModel
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
            expandedContentTopInset: presentation.expandedContentTopInset,
            previewContent: presentation.previewContent,
            musicTrackSwipeDirection: presentation.musicTrackSwipeDirection,
            todoToggleScenarioRequest: presentation.todoToggleScenarioRequest,
            reduceMotion: presentation.reduceMotion,
            presentationShapeMetrics: presentation.shapeMetrics,
            presentationShapeState: presentation.shapeState,
            presentationShadowAppearance: presentation.shadowAppearance,
            presentationShadowOutsets: presentation.shadowOutsets,
            contentPresentation: presentation.contentPresentation,
            waveformModel: model.waveformModel,
            onAdvanceState: model.onAdvancePreviewState,
            onGreetingLifecycleCompleted: model.onGreetingLifecycleCompleted,
            onMusicCommand: model.onMusicCommand,
            onMusicSeek: model.onMusicSeek,
            onMusicSeekInteractionStarted: model.onMusicSeekInteractionStarted,
            onTodoTaskInteraction: model.onTodoTaskInteraction,
            onLoginRequested: model.onLoginRequested,
            onUpdateRequested: model.onUpdateRequested,
            onUpdateLaterRequested: model.onUpdateLaterRequested
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
    }
}
