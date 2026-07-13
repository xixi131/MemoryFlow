import Foundation

struct IslandPreviewLayoutInput: Equatable {
    let visualState: IslandVisualState
    let widthConstraints: IslandWidthConstraints
    let previewMarker: IslandPreviewContentMarker
    let previewContent: IslandPreviewContent

    init(
        visualState: IslandVisualState,
        widthConstraints: IslandWidthConstraints,
        previewMarker: IslandPreviewContentMarker = .hidden,
        previewContent: IslandPreviewContent = IslandPreviewContent.derive(
            from: .loggedInReviewCompact,
            derivedVisualState: .compactCollapsed,
            showMusicActivity: false,
            showReviewActivity: false,
            showTodoActivity: false,
            showReminder: false
        )
    ) {
        self.visualState = visualState
        self.widthConstraints = widthConstraints
        self.previewMarker = previewMarker
        self.previewContent = previewContent
    }
}

struct IslandPhase5PreviewReducerUpdate: Equatable {
    let previousState: IslandDomainState
    let currentState: IslandDomainState
    let previousDerivedState: IslandDerivedState
    let currentDerivedState: IslandDerivedState
    let reducerResult: IslandPresentationReducerResult

    var previousLayoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: previousDerivedState.visualState,
            widthConstraints: previousDerivedState.widthConstraints,
            previewMarker: previousDerivedState.previewMarker,
            previewContent: previousDerivedState.previewContent
        )
    }

    var currentLayoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: currentDerivedState.visualState,
            widthConstraints: currentDerivedState.widthConstraints,
            previewMarker: currentDerivedState.previewMarker,
            previewContent: currentDerivedState.previewContent
        )
    }
}

struct IslandPhase5PreviewStateContainer: Equatable {
    var domainState: IslandDomainState

    init(initialState: IslandDomainState = .loggedInReviewCompact) {
        self.domainState = initialState
    }

    var derivedState: IslandDerivedState {
        IslandDerivedState.derive(from: domainState)
    }

    var layoutInput: IslandPreviewLayoutInput {
        IslandPreviewLayoutInput(
            visualState: derivedState.visualState,
            widthConstraints: derivedState.widthConstraints,
            previewMarker: derivedState.previewMarker,
            previewContent: derivedState.previewContent
        )
    }

    mutating func dispatch(intent: IslandInteractionIntent) -> IslandPhase5PreviewReducerUpdate {
        let previousState = domainState
        let previousDerivedState = IslandDerivedState.derive(from: previousState)
        let reducerResult = IslandPresentationReducer.reduce(
            current: previousState,
            intent: intent
        )
        domainState = reducerResult.state

        return IslandPhase5PreviewReducerUpdate(
            previousState: previousState,
            currentState: reducerResult.state,
            previousDerivedState: previousDerivedState,
            currentDerivedState: reducerResult.derivedState,
            reducerResult: reducerResult
        )
    }

    mutating func replaceDomainState(_ nextState: IslandDomainState) -> IslandPhase5PreviewReducerUpdate {
        let previousState = domainState
        let previousDerivedState = IslandDerivedState.derive(from: previousState)
        domainState = nextState
        return IslandPhase5PreviewReducerUpdate(
            previousState: previousState,
            currentState: nextState,
            previousDerivedState: previousDerivedState,
            currentDerivedState: IslandDerivedState.derive(from: nextState),
            reducerResult: IslandPresentationReducerResult(
                state: nextState,
                reason: .mockScenarioSelected,
                metadata: .none
            )
        )
    }

    mutating func retarget(to layoutInput: IslandPreviewLayoutInput) -> IslandPhase5PreviewReducerUpdate {
        dispatch(intent: .retargetPresentation(.init(visualState: layoutInput.visualState)))
    }

    mutating func advanceMockMusicTrack(_ command: IslandHorizontalMusicCommand) {
        guard command != .playPause, var music = domainState.mockSources.music else { return }
        let tracks = [
            ("Mock Track", "MemoryFlow", "#22d3ee"),
            ("Focus Flow", "MemoryFlow", "#a3e635"),
            ("Recall Loop", "MemoryFlow", "#fb7185")
        ]
        let current = tracks.firstIndex { $0.0 == music.trackTitle } ?? 0
        let step = command == .nextTrack ? 1 : -1
        let next = tracks[(current + step + tracks.count) % tracks.count]
        music.trackTitle = next.0
        music.artistName = next.1
        music.themeColorHex = next.2
        music.elapsedSeconds = 0
        domainState.mockSources.music = music
    }
}

extension IslandPresentationRetargetTarget {
    init(visualState: IslandVisualState) {
        switch visualState {
        case .compactCollapsed:
            self.init(
                presentationState: .collapsed,
                forceCompactMode: true,
                isHovered: false
            )
        case .hoverCollapsed:
            self.init(
                presentationState: .collapsed,
                forceCompactMode: true,
                isHovered: true
            )
        case .activityCollapsed, .activityHoverCollapsed:
            self.init(
                presentationState: .activity,
                forceCompactMode: false,
                isHovered: visualState == .activityHoverCollapsed
            )
        case .expandedApp, .expandedMusic, .loginRequired, .updatePrompt:
            self.init(
                presentationState: .expanded,
                forceCompactMode: false,
                isHovered: false
            )
        }
    }
}
