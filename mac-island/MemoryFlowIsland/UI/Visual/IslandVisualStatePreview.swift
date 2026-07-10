import AppKit
import SwiftUI

struct IslandVisualStatePreview: View {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let previewContent: IslandPreviewContent
    let musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    var onAdvanceState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicControlInteraction: (() -> Void)?
    @State private var activityContentIsVisible = false
    @State private var compactContentIsVisible = true
    @State private var wasActivityCollapsed = false
    @State private var expandedAppContentIsVisible = true
    @State private var expandedMusicContentIsVisible = true
    @State private var contentPresentation = IslandContentPresentation(phase: .visible, opacity: 1, blurRadius: 0, scale: 1, offsetY: 0, allowsHitTesting: true)
    @State private var contentTransitionGate = IslandContentTransitionGate()
    @State private var previousVisualState: IslandVisualState?
    @State private var previousPreviewContent: IslandPreviewContent?
    @State private var greetingPhase: IslandGreetingPhase = .cancelled
    @State private var greetingGate = IslandGreetingTransitionGate()
    @State private var greetingExpired = false
    @Namespace private var musicArtworkNamespace

    private var effectiveWidthConstraints: IslandWidthConstraints {
        guard greetingExpired else { return widthConstraints }
        return IslandWidthConstraints(
            baseBodyWidth: IslandVisualTokens.compact.previewWidth - 40,
            maximumVisibleWidth: widthConstraints.maximumVisibleWidth,
            contentWidthRequirement: .none
        )
    }

    private var snapshot: IslandShapeLayoutSnapshot {
        IslandCompactContentLayout.snapshot(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: effectiveWidthConstraints
        )
    }

    var body: some View {
        let snapshot = snapshot

        previewContainer(snapshot: snapshot)
            .background(Color.clear)
            .onAppear(perform: scheduleActivityContentEnter)
            .onAppear { wasActivityCollapsed = state == .activityCollapsed }
            .onAppear {
                previousVisualState = state
                previousPreviewContent = previewContent
                scheduleGreetingLifecycle(for: previewContent)
            }
            .onChange(of: state) { nextState in
                scheduleContentForStateChange(to: nextState)
                beginContentTransition(from: previousVisualState ?? nextState, to: nextState)
                previousVisualState = nextState
                previousPreviewContent = previewContent
            }
            .onChange(of: previewContent) { nextContent in
                scheduleGreetingLifecycle(for: nextContent)
                guard previousPreviewContent != nextContent else { return }
                beginContentTransition(from: state, to: state)
                previousPreviewContent = nextContent
            }
    }

    @ViewBuilder
    private func previewContainer(snapshot: IslandShapeLayoutSnapshot) -> some View {
        let content = ZStack(alignment: .topLeading) {
            composedShapeLayer(snapshot: snapshot)
                .shadow(
                    color: shadowColor(for: snapshot),
                    radius: shadowRadius(for: snapshot),
                    x: 0,
                    y: shadowOffsetY(for: snapshot)
                )
                // Window sizing is y-up; SwiftUI renders top-leading, so keep shell attached and leave shadow buffer below.
                .offset(y: -snapshot.shadowOutsets.bottom)

            previewContentLayer(snapshot: snapshot)
        }
        .frame(
            width: snapshot.contentFrame.width,
            height: snapshot.contentFrame.height,
            alignment: .topLeading
        )
        .contentShape(Rectangle())

        if let onAdvanceState {
            content.onTapGesture(perform: onAdvanceState)
        } else {
            content
        }
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

    @ViewBuilder
    private func previewContentLayer(snapshot: IslandShapeLayoutSnapshot) -> some View {
        IslandPreviewContentOverlay(
            content: previewContent,
            state: state,
            snapshot: snapshot,
            isActivityContentVisible: activityContentIsVisible,
            isCompactContentVisible: compactContentIsVisible,
            isExpandedAppContentVisible: expandedAppContentIsVisible,
            isExpandedMusicContentVisible: expandedMusicContentIsVisible,
            contentPhase: contentPresentation.phase,
            greetingPhase: greetingPhase,
            greetingExpired: greetingExpired,
            musicArtworkNamespace: musicArtworkNamespace,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            onMusicControlInteraction: onMusicControlInteraction
        )
            .frame(
                width: snapshot.contentFrame.width,
                height: snapshot.contentFrame.height,
                alignment: .topLeading
            )
            .opacity(contentPresentation.opacity)
            .blur(radius: contentPresentation.blurRadius)
            .scaleEffect(contentPresentation.scale)
            .offset(y: contentPresentation.offsetY)
            .allowsHitTesting(contentPresentation.allowsHitTesting)
            .accessibilityElement(children: .contain)
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

    private func shadowAppearance(for snapshot: IslandShapeLayoutSnapshot) -> IslandShadowAppearanceTokens {
        return IslandVisualTokens.shadow.appearance(
            for: snapshot.state,
            visualScale: visualScale
        )
    }

    private func scheduleActivityContentEnter() {
        activityContentIsVisible = false
        guard state == .activityCollapsed else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + IslandVisualTokens.activityContentEnter.delay) {
            guard state == .activityCollapsed else { return }
            withAnimation(.easeOut(duration: IslandVisualTokens.activityContentEnter.duration)) {
                activityContentIsVisible = true
            }
        }
    }

    private func scheduleContentForStateChange(to nextState: IslandVisualState) {
        let isCollapsing = wasActivityCollapsed && nextState == .compactCollapsed
        let isOpeningExpandedApp = wasActivityCollapsed && nextState == .expandedApp
        let isOpeningExpandedMusic = wasActivityCollapsed && nextState == .expandedMusic
        wasActivityCollapsed = nextState == .activityCollapsed
        scheduleActivityContentEnter()
        if isOpeningExpandedApp {
            expandedAppContentIsVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + IslandVisualTokens.expandedAppContentEnter.delay) {
                guard state == .expandedApp else { return }
                withAnimation(.easeOut(duration: IslandVisualTokens.expandedAppContentEnter.duration)) {
                    expandedAppContentIsVisible = true
                }
            }
        } else if nextState != .expandedApp {
            expandedAppContentIsVisible = true
        }
        if isOpeningExpandedMusic {
            expandedMusicContentIsVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + IslandVisualTokens.expandedMusicContentEnter.delay) {
                guard state == .expandedMusic else { return }
                withAnimation(.easeOut(duration: IslandVisualTokens.expandedMusicContentEnter.duration)) {
                    expandedMusicContentIsVisible = true
                }
            }
        } else if nextState != .expandedMusic {
            expandedMusicContentIsVisible = true
        }
        guard isCollapsing else {
            compactContentIsVisible = true
            return
        }

        compactContentIsVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + IslandVisualTokens.activityCollapseContent.compactContentDelay) {
            guard state == .compactCollapsed else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                compactContentIsVisible = true
            }
        }
    }

    private func beginContentTransition(from previous: IslandVisualState, to next: IslandVisualState) {
        let epoch = contentTransitionGate.begin()
        let choreography = IslandContentChoreographyPlan.resolve(from: previous, to: next)

        withAnimation(animation(for: choreography.exit)) {
            contentPresentation = choreography.presentation(for: .exiting)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + choreography.exit.duration) {
            guard contentTransitionGate.accepts(epoch) else { return }
            contentPresentation = choreography.presentation(for: .waitingForShell)

            let shellWait = max(choreography.shellDuration - choreography.exit.duration, 0) + choreography.enter.delay
            DispatchQueue.main.asyncAfter(deadline: .now() + shellWait) {
                guard contentTransitionGate.accepts(epoch) else { return }
                withAnimation(animation(for: choreography.enter)) {
                    contentPresentation = choreography.presentation(for: .entering)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + choreography.enter.duration) {
                    guard contentTransitionGate.accepts(epoch) else { return }
                    contentPresentation = choreography.presentation(for: .visible)
                }
            }
        }
    }

    private func animation(for token: IslandContentMotionToken) -> Animation {
        switch token.curve {
        case .easeInOut:
            return .easeInOut(duration: token.duration)
        case .easeOut:
            return .easeOut(duration: token.duration)
        case .linear:
            return .linear(duration: token.duration)
        }
    }

    private func scheduleGreetingLifecycle(for content: IslandPreviewContent) {
        let epoch = greetingGate.begin()
        guard content.kind == .greetingCompact else {
            greetingPhase = .cancelled
            greetingExpired = false
            return
        }

        greetingExpired = false
        greetingPhase = .hidden
        DispatchQueue.main.async {
            guard greetingGate.accepts(epoch) else { return }
            withAnimation(.easeOut(duration: IslandGreetingSequence.transitionDuration)) {
                greetingPhase = .entering
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + IslandGreetingSequence.lifecycleDuration) {
            guard greetingGate.accepts(epoch) else { return }
            withAnimation(.easeOut(duration: IslandGreetingSequence.transitionDuration)) {
                greetingPhase = .exiting
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + IslandGreetingSequence.transitionDuration) {
                guard greetingGate.accepts(epoch) else { return }
                greetingPhase = .expired
                greetingExpired = true
                onGreetingLifecycleCompleted?()
            }
        }
    }
}

enum IslandCompactContentLayout {
    static func snapshot(
        for state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat,
        widthConstraints: IslandWidthConstraints
    ) -> IslandShapeLayoutSnapshot {
        let metrics = IslandShapeMetrics.resolve(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints
        )

        guard state == .compactCollapsed,
              let compactBodyWidth = widthConstraints.baseBodyWidth,
              compactBodyWidth < metrics.width else {
            return IslandShapeEngine.snapshot(for: metrics, state: state)
        }

        // The shared shape metrics preserve a 200pt preview floor. Compact parity
        // content intentionally uses its derived 180pt signed-out or 160pt idle body.
        let compactMetrics = IslandShapeMetrics(
            width: compactBodyWidth,
            height: metrics.height,
            radius: metrics.radius,
            smoothness: metrics.smoothness,
            earTension: metrics.earTension,
            earBlendHeight: metrics.earBlendHeight,
            scale: metrics.scale,
            showsStroke: metrics.showsStroke,
            showsShadow: metrics.showsShadow
        )
        return IslandShapeEngine.snapshot(for: compactMetrics, state: state)
    }
}

private struct IslandPreviewContentOverlay: View {
    let content: IslandPreviewContent
    let state: IslandVisualState
    let snapshot: IslandShapeLayoutSnapshot
    let isActivityContentVisible: Bool
    let isCompactContentVisible: Bool
    let isExpandedAppContentVisible: Bool
    let isExpandedMusicContentVisible: Bool
    let contentPhase: IslandContentPhase
    let greetingPhase: IslandGreetingPhase
    let greetingExpired: Bool
    let musicArtworkNamespace: Namespace.ID
    let musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    var onMusicControlInteraction: (() -> Void)?
    @State private var musicClock = IslandMockMusicProgressClock()
    @State private var playbackOverride: Bool?
    @State private var isFavorite = false

    private var expandedSafePadding: CGFloat {
        IslandVisualTokens.compact.height
    }

    private var expandedHorizontalPadding: CGFloat {
        expandedSafePadding + 12
    }

    private var visibleContentFrame: CGRect {
        CGRect(
            x: snapshot.visibleFrame.minX,
            y: max(0, snapshot.visibleFrame.minY - snapshot.shadowOutsets.bottom),
            width: snapshot.visibleFrame.width,
            height: snapshot.visibleFrame.height
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if state == .activityCollapsed {
                compactActivityContent
                    .opacity(isActivityContentVisible ? 1 : 0)
                    .blur(radius: isActivityContentVisible ? 0 : IslandVisualTokens.activityContentEnter.initialBlurRadius)
                    .offset(y: isActivityContentVisible ? 0 : 4)
                    .allowsHitTesting(isActivityContentVisible)
                    .frame(
                        width: visibleContentFrame.width,
                        height: visibleContentFrame.height
                    )
                    .offset(x: visibleContentFrame.minX, y: visibleContentFrame.minY)
            } else if state == .compactCollapsed || state == .hoverCollapsed {
                compactContent
                    .id(content.kind)
                    .transition(.islandCompactContentCrossfade)
                    .animation(.easeOut(duration: 0.26), value: content.kind)
                    .opacity(isCompactContentVisible ? 1 : 0)
                    .allowsHitTesting(isCompactContentVisible)
                    .frame(
                        width: visibleContentFrame.width,
                        height: visibleContentFrame.height
                    )
                    .offset(x: visibleContentFrame.minX, y: visibleContentFrame.minY)
            } else if state.isExpanded {
                expandedContent
                    .frame(
                        width: visibleContentFrame.width,
                        height: visibleContentFrame.height
                    )
                    .offset(x: visibleContentFrame.minX, y: visibleContentFrame.minY)
            }
        }
        .frame(
            width: snapshot.contentFrame.width,
            height: snapshot.contentFrame.height,
            alignment: .topLeading
        )
        .clipped()
        .onAppear { resetMusicPresentation(for: content.music, clearsPlaybackOverride: true) }
        .onChange(of: content.music) { resetMusicPresentation(for: $0, clearsPlaybackOverride: true) }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch content.kind {
        case .signedOutCompact:
            mockLoginCompactContent
                .allowsHitTesting(true)
        case .greetingCompact where greetingExpired == false:
            greetingCompactContent
                .allowsHitTesting(false)
        default:
            loggedInIdleCompactContent
                .allowsHitTesting(false)
        }
    }

    private var mockLoginCompactContent: some View {
        Button(action: runMockLoginCommand) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.to.line.compact")
                    .font(.system(size: 13, weight: .bold))
                Text(content.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("island-mock-login-command")
        .accessibilityLabel("Mock login command")
    }

    private var loggedInIdleCompactContent: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tintColor.opacity(0.94))
            Text("MemoryFlow")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Logged in idle")
    }

    private var greetingCompactContent: some View {
        let presentation = IslandGreetingSequence.presentation(for: greetingPhase)
        return Text(content.title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .opacity(presentation.opacity)
            .offset(y: presentation.offsetY)
            .accessibilityLabel("Greeting")
    }

    private func runMockLoginCommand() {
        // Phase 6 deliberately keeps login local to the preview; no panel or auth flow opens.
    }

    private var compactActivityContent: some View {
        HStack(spacing: 8) {
            musicTrackIdentity(
                presentation: IslandVisualTokens.activityMusicArtwork,
                isExpanded: false,
                titleSize: 10,
                subtitleSize: 8,
                spacing: 1
            )

            Spacer(minLength: 4)

            if let music = content.music {
                MusicWaveformMark(
                    tint: tintColor,
                    isPlaying: music.isPlaying,
                    count: 4,
                    displayScale: snapshot.metrics.scale
                )
                .frame(width: 22, height: 22)
            } else {
                Text(content.badge)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if state == .expandedMusic {
            expandedMusicContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, expandedSafePadding)
                .padding(.horizontal, expandedHorizontalPadding)
                .opacity(isExpandedMusicContentVisible ? 1 : 0)
                .blur(radius: isExpandedMusicContentVisible ? 0 : IslandVisualTokens.expandedMusicContentEnter.initialBlurRadius)
                .allowsHitTesting(isExpandedMusicContentVisible)
        } else {
            expandedAppContent
                .padding(.horizontal, 34)
                .padding(.top, 42)
                .opacity(isExpandedAppContentVisible ? 1 : 0)
                .blur(radius: isExpandedAppContentVisible ? 0 : IslandVisualTokens.expandedAppContentEnter.initialBlurRadius)
                .allowsHitTesting(isExpandedAppContentVisible)
        }
    }

    private var expandedMusicContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                musicTrackIdentity(
                    presentation: IslandVisualTokens.expandedMusicArtwork,
                    isExpanded: true,
                    titleSize: 16,
                    subtitleSize: 13,
                    spacing: 5
                )

                Spacer(minLength: 12)

                MusicWaveformMark(
                    tint: tintColor,
                    isPlaying: effectiveMusicIsPlaying,
                    count: 5,
                    displayScale: snapshot.metrics.scale
                )
                .frame(width: 34, height: 26)
            }

            progressRow

            musicTransportControls
        }
    }

    @ViewBuilder
    private var expandedAppContent: some View {
        if content.kind == .expandedReview, let review = content.review {
            IslandExpandedReviewContent(
                review: review,
                tint: tintColor,
                contentPhase: contentPhase
            )
        } else if content.kind == .expandedTodo, let todo = content.todo {
            IslandExpandedTodoContent(
                todo: todo,
                tint: tintColor,
                contentPhase: contentPhase
            )
        } else {
            genericExpandedAppContent
        }
    }

    private var genericExpandedAppContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                artwork(size: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(content.eyebrow.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tintColor.opacity(0.88))
                        .lineLimit(1)

                    Text(content.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(content.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }

            appSummary
        }
    }

    private var progressRow: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let elapsed = musicClock.elapsed(at: timeline.date)
            let progress = musicProgress(for: elapsed)
            let remaining = remainingSeconds(for: elapsed)
            HStack(spacing: 10) {
                Text(timeText(elapsed))
                    .frame(width: 34, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(memoryFlowHex: "#222222"))
                        Capsule()
                            .fill(Color(memoryFlowHex: "#747376"))
                            .frame(width: geometry.size.width * progress)
                    }
                    .animation(.easeInOut(duration: 0.22), value: progress)
                }
                .frame(height: 6)

                Text("-\(timeText(remaining))")
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
    }

    private var musicTransportControls: some View {
        HStack(alignment: .center) {
            MusicTransportButton(
                symbol: isFavorite ? "star.fill" : "star",
                size: 20,
                tint: .white.opacity(0.46),
                label: "Favorite mock track"
            ) {
                isFavorite.toggle()
                registerMusicControlInteraction()
            }

            Spacer(minLength: 0)

            MusicTransportButton(
                symbol: "backward.fill",
                size: 24,
                tint: .white,
                label: "Previous mock track",
                action: registerMusicControlInteraction
            )

            Spacer(minLength: 0)

            MusicTransportButton(
                symbol: effectiveMusicIsPlaying ? "pause.fill" : "play.fill",
                size: 34,
                tint: .white,
                label: effectiveMusicIsPlaying ? "Pause mock track" : "Play mock track"
            ) {
                playbackOverride = !effectiveMusicIsPlaying
                resetMusicPresentation(for: content.music, clearsPlaybackOverride: false)
                registerMusicControlInteraction()
            }

            Spacer(minLength: 0)

            MusicTransportButton(
                symbol: "forward.fill",
                size: 24,
                tint: .white,
                label: "Next mock track",
                action: registerMusicControlInteraction
            )

            Spacer(minLength: 0)

            MusicTransportButton(
                symbol: "laptopcomputer",
                size: 20,
                tint: .white.opacity(0.42),
                label: "Mock playback device",
                action: registerMusicControlInteraction
            )
        }
        .padding(.horizontal, 6)
        .frame(height: 34)
    }

    private var appSummary: some View {
        HStack(spacing: 8) {
            Text(content.badge)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.12)))

            Text(content.eyebrow)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 0)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        ZStack {
            if let artworkData = content.music?.artworkData,
               let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(0.92),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(content.badge.prefix(1))
                    .font(.system(size: max(10, size * 0.32), weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }

    private func musicArtwork(
        presentation: IslandMusicArtworkPresentation,
        isExpanded: Bool
    ) -> some View {
        ZStack {
            if let artworkData = content.music?.artworkData,
               let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MusicArtworkMask(radius: presentation.radius, smoothness: presentation.smoothness)
                    .fill(
                        LinearGradient(
                            colors: [tintColor.opacity(0.92), Color.white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(content.badge.prefix(1))
                    .font(.system(size: max(10, presentation.width * 0.32), weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .frame(width: presentation.width, height: presentation.height)
        .clipShape(MusicArtworkMask(radius: presentation.radius, smoothness: presentation.smoothness))
        .matchedGeometryEffect(id: "music-artwork", in: musicArtworkNamespace, properties: .frame, anchor: .leading, isSource: !isExpanded)
        .animation(.easeInOut(duration: 0.46), value: presentation)
        .accessibilityLabel(content.music?.artworkData == nil ? "Music artwork placeholder" : "Music artwork")
    }

    private func musicTrackIdentity(
        presentation: IslandMusicArtworkPresentation,
        isExpanded: Bool,
        titleSize: CGFloat,
        subtitleSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: isExpanded ? 14 : 8) {
            musicArtwork(presentation: presentation, isExpanded: isExpanded)
            MusicTrackMetadata(
                title: content.title,
                artist: content.subtitle,
                titleSize: titleSize,
                subtitleSize: subtitleSize,
                spacing: spacing
            )
        }
        .islandMusicTrackSwipe(
            trackID: [content.title, content.subtitle].joined(separator: "|"),
            direction: musicTrackSwipeDirection
        )
    }

    private var tintColor: Color {
        if let themeColorHex = content.music?.themeColorHex {
            return Color(memoryFlowHex: themeColorHex)
        }

        switch content.tone {
        case .music:
            return Color(memoryFlowHex: "#22d3ee")
        case .todo:
            return Color(memoryFlowHex: "#a3e635")
        case .reminder:
            return Color(memoryFlowHex: "#fb7185")
        case .signedOut:
            return Color(memoryFlowHex: "#fbbf24")
        case .gestureLock:
            return Color(memoryFlowHex: "#c084fc")
        case .review, .expanded:
            return Color(memoryFlowHex: "#60a5fa")
        }
    }

    private var effectiveMusicIsPlaying: Bool {
        playbackOverride ?? content.music?.isPlaying ?? true
    }

    private func resetMusicPresentation(
        for music: IslandMockMusicActivity?,
        clearsPlaybackOverride: Bool
    ) {
        if clearsPlaybackOverride {
            playbackOverride = nil
        }
        musicClock.reset(for: music, isPlaying: effectiveMusicIsPlaying, at: .now)
    }

    private func registerMusicControlInteraction() {
        // Preview-only controls never dispatch a real media command.
        onMusicControlInteraction?()
    }

    private func musicProgress(for elapsed: TimeInterval?) -> CGFloat {
        guard let music = content.music,
              let duration = music.durationSeconds,
              duration > 0 else {
            return 0
        }
        return CGFloat(min(max((elapsed ?? music.elapsedSeconds) / duration, 0), 1))
    }

    private func remainingSeconds(for elapsed: TimeInterval?) -> TimeInterval? {
        guard let music = content.music,
              let duration = music.durationSeconds else {
            return nil
        }
        return max(0, duration - (elapsed ?? music.elapsedSeconds))
    }

    private func timeText(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "--:--" }
        let totalSeconds = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct MusicTransportButton: View {
    let symbol: String
    let size: CGFloat
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(MusicTransportButtonStyle())
        .accessibilityLabel(label)
    }
}

private struct MusicTransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.56 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct IslandCompactContentTransitionStyle: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blurRadius)
            .offset(y: offsetY)
    }
}

private struct MusicArtworkMask: Shape {
    var radius: CGFloat
    var smoothness: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, smoothness) }
        set {
            radius = newValue.first
            smoothness = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let corner = min(max(radius, 0), min(rect.width, rect.height) / 2)
        // A lower exponent draws a slightly rounder continuous corner while
        // retaining the token radius as the physical corner extent.
        let control = corner * (0.552_284_75 / max(smoothness, 0.01))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + corner),
            control1: CGPoint(x: rect.maxX - control, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + control)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addCurve(
            to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - control),
            control2: CGPoint(x: rect.maxX - control, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - corner),
            control1: CGPoint(x: rect.minX + control, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - control)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addCurve(
            to: CGPoint(x: rect.minX + corner, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + control),
            control2: CGPoint(x: rect.minX + control, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct MusicTrackMetadata: View {
    let title: String
    let artist: String
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let spacing: CGFloat

    @State private var displayedTitle = ""
    @State private var displayedArtist = ""

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            metadataText(displayedTitle, fontSize: titleSize, color: .white)
            metadataText(displayedArtist, fontSize: subtitleSize, color: .white.opacity(0.48))
        }
        .onAppear { updateMetadata(animated: false) }
        .onChange(of: title) { _ in updateMetadata(animated: true) }
        .onChange(of: artist) { _ in updateMetadata(animated: true) }
    }

    private func metadataText(_ text: String, fontSize: CGFloat, color: Color) -> some View {
        Text(text)
            .id(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
    }

    private func updateMetadata(animated: Bool) {
        let update = {
            displayedTitle = title
            displayedArtist = artist
        }
        if animated {
            withAnimation(.easeOut(duration: 0.22), update)
        } else {
            update()
        }
    }
}

private struct IslandExpandedReviewContent: View {
    let review: IslandMockReviewActivity
    let tint: Color
    let contentPhase: IslandContentPhase
    @State private var cardsAreVisible = false

    private var slots: [IslandExpandedReviewSubjectSlot] {
        IslandExpandedReviewContentLayout.subjectSlots(for: review)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REVIEW QUEUE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tint.opacity(0.9))
                    Text("Today's review")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                Text("\(max(review.pendingCount, 0)) pending")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(spacing: 8) {
                reviewCounter(value: max(review.pendingCount, 0), label: "Pending")
                reviewCounter(value: max(review.completedTodayCount, 0), label: "Completed today")
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    subjectCard(slot)
                        .opacity(cardsAreVisible ? 1 : 0)
                        .scaleEffect(cardsAreVisible ? 1 : IslandExpandedReviewContentLayout.initialCardScale)
                        .animation(
                            IslandExpandedReviewContentLayout.cardAnimation
                                .delay(IslandExpandedReviewContentLayout.cardDelay(for: index)),
                            value: cardsAreVisible
                        )
                }
            }

            if review.subjectTitles.count > IslandExpandedReviewContentLayout.maximumVisibleSubjects {
                Text("+\(review.subjectTitles.count - IslandExpandedReviewContentLayout.maximumVisibleSubjects) more subjects")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(cardsAreVisible ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.16).delay(IslandExpandedReviewContentLayout.footerDelay),
                        value: cardsAreVisible
                    )
            }
        }
        .onAppear(perform: updateCardEntrance)
        .onChange(of: contentPhase) { _ in updateCardEntrance() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded review queue")
    }

    private func reviewCounter(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.10)))
    }

    private func subjectCard(_ slot: IslandExpandedReviewSubjectSlot) -> some View {
        HStack(spacing: 7) {
            Image(systemName: slot.isPlaceholder ? "rectangle.dashed" : "book.closed.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(slot.isPlaceholder ? .white.opacity(0.28) : tint.opacity(0.92))
            Text(slot.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(slot.isPlaceholder ? .white.opacity(0.28) : .white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(slot.isPlaceholder ? .white.opacity(0.045) : .white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(slot.isPlaceholder ? 0.10 : 0.14), style: StrokeStyle(lineWidth: 1, dash: slot.isPlaceholder ? [3, 3] : []))
        )
        .accessibilityIdentifier("island-review-subject-\(slot.id)")
        .accessibilityLabel(slot.isPlaceholder ? "Empty review subject slot" : "Review subject \(slot.title)")
    }

    private func updateCardEntrance() {
        guard IslandExpandedReviewContentLayout.shouldRevealCards(in: contentPhase) else {
            cardsAreVisible = false
            return
        }

        cardsAreVisible = false
        DispatchQueue.main.async {
            guard IslandExpandedReviewContentLayout.shouldRevealCards(in: contentPhase) else { return }
            cardsAreVisible = true
        }
    }
}

struct IslandExpandedReviewSubjectSlot: Equatable, Identifiable {
    let id: String
    let title: String
    let isPlaceholder: Bool
}

enum IslandExpandedReviewContentLayout {
    static let maximumVisibleSubjects = 4
    static let childDelay: TimeInterval = 0.10
    static let childStagger: TimeInterval = 0.05
    static let initialCardScale: CGFloat = 0.9
    static let cardAnimation = Animation.interpolatingSpring(stiffness: 300, damping: 20)

    static var footerDelay: TimeInterval {
        childDelay + Double(maximumVisibleSubjects) * childStagger
    }

    static func subjectSlots(for review: IslandMockReviewActivity) -> [IslandExpandedReviewSubjectSlot] {
        let visibleSubjects = Array(review.subjectTitles.prefix(maximumVisibleSubjects))
        let realSlots = visibleSubjects.enumerated().map { index, title in
            IslandExpandedReviewSubjectSlot(id: "subject-\(index)", title: title, isPlaceholder: false)
        }
        let placeholders = (realSlots.count..<maximumVisibleSubjects).map { index in
            IslandExpandedReviewSubjectSlot(id: "placeholder-\(index)", title: "Open subject slot", isPlaceholder: true)
        }
        return realSlots + placeholders
    }

    static func cardDelay(for index: Int) -> TimeInterval {
        childDelay + Double(index) * childStagger
    }

    static func shouldRevealCards(in phase: IslandContentPhase) -> Bool {
        phase == .entering || phase == .visible
    }
}

struct IslandExpandedReviewContentProbeRow: Equatable {
    let scenario: String
    let realCardCount: Int
    let placeholderCount: Int
    let extraSubjectCount: Int
    let firstCardDelay: TimeInterval
    let lastCardDelay: TimeInterval
    let startsInsideContentPhase: Bool
}

enum IslandExpandedReviewContentProbe {
    static func rows() -> [IslandExpandedReviewContentProbeRow] {
        [
            ("zero", []),
            ("partial", ["Algorithms", "English"]),
            ("four", ["Algorithms", "English", "Cognitive Science", "History"]),
            ("more", ["Algorithms", "English", "Cognitive Science", "History", "Physics", "Literature"])
        ].map { scenario, subjects in
            let review = IslandMockReviewActivity(
                pendingCount: subjects.count,
                completedTodayCount: 3,
                nextSubjectTitle: subjects.first,
                subjectTitles: subjects
            )
            let slots = IslandExpandedReviewContentLayout.subjectSlots(for: review)
            return IslandExpandedReviewContentProbeRow(
                scenario: scenario,
                realCardCount: slots.filter { $0.isPlaceholder == false }.count,
                placeholderCount: slots.filter(\.isPlaceholder).count,
                extraSubjectCount: max(subjects.count - IslandExpandedReviewContentLayout.maximumVisibleSubjects, 0),
                firstCardDelay: IslandExpandedReviewContentLayout.cardDelay(for: 0),
                lastCardDelay: IslandExpandedReviewContentLayout.cardDelay(for: IslandExpandedReviewContentLayout.maximumVisibleSubjects - 1),
                startsInsideContentPhase: IslandExpandedReviewContentLayout.shouldRevealCards(in: .entering)
                    && IslandExpandedReviewContentLayout.shouldRevealCards(in: .visible)
                    && IslandExpandedReviewContentLayout.shouldRevealCards(in: .waitingForShell) == false
            )
        }
    }

    static func validate() throws {
        let rows = rows()
        guard rows.map(\.scenario) == ["zero", "partial", "four", "more"],
              rows.map(\.realCardCount) == [0, 2, 4, 4],
              rows.map(\.placeholderCount) == [4, 2, 0, 0],
              rows.map(\.extraSubjectCount) == [0, 0, 0, 2],
              rows.allSatisfy({ $0.firstCardDelay == 0.10 && $0.lastCardDelay == 0.25 }),
              rows.allSatisfy(\.startsInsideContentPhase),
              IslandExpandedReviewContentLayout.initialCardScale == 0.9 else {
            throw IslandExpandedReviewContentProbeError.invalidLayout(rows)
        }
    }
}

enum IslandExpandedReviewContentProbeError: Error {
    case invalidLayout([IslandExpandedReviewContentProbeRow])
}

private struct IslandExpandedTodoContent: View {
    let todo: IslandMockTodoActivity
    let tint: Color
    let contentPhase: IslandContentPhase
    @State private var summaryIsVisible = false
    @State private var rowsAreVisible = false

    private var taskSlots: [IslandExpandedTodoTaskSlot] {
        IslandExpandedTodoContentLayout.taskSlots(for: todo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODO FLOW")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tint.opacity(0.9))
                    Text("Today's plan")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                Text("\(max(todo.pendingCount, 0)) pending")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(spacing: 7) {
                todoCounter(value: max(todo.pendingCount, 0), label: "Pending")
                todoCounter(value: max(todo.dueTodayCount, 0), label: "Due today")
                todoCounter(value: max(todo.overdueCount, 0), label: "Overdue", isUrgent: todo.overdueCount > 0)
            }
            .opacity(summaryIsVisible ? 1 : 0)
            .offset(y: summaryIsVisible ? 0 : 4)
            .animation(IslandExpandedTodoContentLayout.summaryAnimation, value: summaryIsVisible)

            Group {
                if taskSlots.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: IslandExpandedTodoContentLayout.rowSpacing) {
                        ForEach(Array(taskSlots.enumerated()), id: \.element.id) { index, task in
                            taskRow(task)
                                .opacity(rowsAreVisible ? 1 : 0)
                                .offset(y: rowsAreVisible ? 0 : 5)
                                .animation(
                                    IslandExpandedTodoContentLayout.rowAnimation
                                        .delay(IslandExpandedTodoContentLayout.rowDelay(for: index)),
                                    value: rowsAreVisible
                                )
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: IslandExpandedTodoContentLayout.taskListHeight, alignment: .top)
            .animation(.easeOut(duration: 0.18), value: taskSlots)
        }
        .onAppear(perform: updateEntrance)
        .onChange(of: contentPhase) { _ in updateEntrance() }
        .onChange(of: todo) { _ in updateEntrance() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded todo list")
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint.opacity(0.84))
            Text("No tasks in this view")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
            Text("Your next task will appear here")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(rowsAreVisible ? 1 : 0)
        .offset(y: rowsAreVisible ? 0 : 5)
        .animation(IslandExpandedTodoContentLayout.rowAnimation, value: rowsAreVisible)
        .accessibilityIdentifier("island-todo-empty-state")
    }

    private func todoCounter(value: Int, label: String, isUrgent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(isUrgent ? Color.red.opacity(0.92) : .white)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.10)))
    }

    private func taskRow(_ task: IslandExpandedTodoTaskSlot) -> some View {
        HStack(spacing: 7) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(task.isCompleted ? tint.opacity(0.9) : .white.opacity(0.42))

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(task.isCompleted ? .white.opacity(0.42) : .white.opacity(0.9))
                    .strikethrough(task.isCompleted, color: .white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                Text(task.dueText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(task.isOverdue ? Color.red.opacity(0.92) : .white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(task.priority.title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(task.priority.color)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(task.priority.color.opacity(0.14)))
        }
        .padding(.horizontal, 9)
        .frame(height: IslandExpandedTodoContentLayout.rowHeight)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(task.isCompleted ? 0.045 : 0.09)))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(task.isOverdue ? Color.red.opacity(0.34) : .white.opacity(0.10), lineWidth: 1)
        )
        .accessibilityIdentifier("island-todo-task-\(task.id)")
        .accessibilityLabel("\(task.title), \(task.dueText), \(task.priority.title) priority\(task.isCompleted ? ", completed" : "")")
    }

    private func updateEntrance() {
        guard IslandExpandedTodoContentLayout.shouldRevealContent(in: contentPhase) else {
            summaryIsVisible = false
            rowsAreVisible = false
            return
        }

        summaryIsVisible = false
        rowsAreVisible = false
        DispatchQueue.main.async {
            guard IslandExpandedTodoContentLayout.shouldRevealContent(in: contentPhase) else { return }
            summaryIsVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + IslandExpandedTodoContentLayout.rowsDelay) {
                guard IslandExpandedTodoContentLayout.shouldRevealContent(in: contentPhase) else { return }
                rowsAreVisible = true
            }
        }
    }
}

struct IslandExpandedTodoTaskSlot: Equatable, Identifiable {
    enum Priority: Equatable {
        case high
        case medium
        case normal

        var title: String {
            switch self {
            case .high: return "HIGH"
            case .medium: return "MED"
            case .normal: return "NORMAL"
            }
        }

        var color: Color {
            switch self {
            case .high: return .red.opacity(0.94)
            case .medium: return .orange.opacity(0.92)
            case .normal: return .white.opacity(0.62)
            }
        }
    }

    let id: String
    let title: String
    let dueText: String
    let priority: Priority
    let isOverdue: Bool
    let isCompleted: Bool
}

enum IslandExpandedTodoContentLayout {
    static let maximumVisibleTasks = 6
    static let rowHeight: CGFloat = 22
    static let rowSpacing: CGFloat = 3
    static let taskListHeight: CGFloat = 147
    static let rowsDelay: TimeInterval = 0.08
    static let rowStagger: TimeInterval = 0.035
    static let summaryAnimation = Animation.easeOut(duration: 0.16)
    static let rowAnimation = Animation.easeOut(duration: 0.18)

    static func taskSlots(for todo: IslandMockTodoActivity) -> [IslandExpandedTodoTaskSlot] {
        Array(todo.tasks.prefix(maximumVisibleTasks)).map { task in
            IslandExpandedTodoTaskSlot(
                id: task.id,
                title: task.title,
                dueText: task.isCompleted ? "Completed" : (task.isOverdue ? "Overdue" : (task.isDueToday ? "Due today" : "Scheduled")),
                priority: task.isOverdue ? .high : (task.isDueToday ? .medium : .normal),
                isOverdue: task.isOverdue,
                isCompleted: task.isCompleted
            )
        }
    }

    static func rowDelay(for index: Int) -> TimeInterval {
        rowsDelay + Double(index) * rowStagger
    }

    static func shouldRevealContent(in phase: IslandContentPhase) -> Bool {
        phase == .entering || phase == .visible
    }
}

struct IslandExpandedTodoContentProbeRow: Equatable {
    let scenario: String
    let visibleTaskCount: Int
    let overdueTaskCount: Int
    let completedTaskCount: Int
    let supportsLongTitle: Bool
    let fixedTaskListHeight: CGFloat
    let startsInsideContentPhase: Bool
}

enum IslandExpandedTodoContentProbe {
    static func rows() -> [IslandExpandedTodoContentProbeRow] {
        let normal = [
            IslandMockTodoTask(id: "normal-1", title: "Review flashcards", isCompleted: false, isDueToday: true, isOverdue: false),
            IslandMockTodoTask(id: "normal-2", title: "Plan tomorrow", isCompleted: true, isDueToday: false, isOverdue: false)
        ]
        let overdue = [
            IslandMockTodoTask(id: "overdue-1", title: "Submit study reflection", isCompleted: false, isDueToday: false, isOverdue: true)
        ]
        let longTitle = [
            IslandMockTodoTask(id: "long-1", title: "Consolidate the spaced repetition notes from the cognitive science seminar", isCompleted: false, isDueToday: true, isOverdue: false)
        ]
        let six = (1...6).map {
            IslandMockTodoTask(id: "six-\($0)", title: "Task \($0)", isCompleted: $0 == 6, isDueToday: $0 <= 2, isOverdue: $0 == 3)
        }
        return [
            ("empty", []),
            ("normal", normal),
            ("overdue", overdue),
            ("long-title", longTitle),
            ("six", six)
        ].map { scenario, tasks in
            let todo = IslandMockTodoActivity(
                pendingCount: tasks.filter { $0.isCompleted == false }.count,
                dueTodayCount: tasks.filter(\.isDueToday).count,
                overdueCount: tasks.filter(\.isOverdue).count,
                nextTaskTitle: tasks.first?.title,
                tasks: tasks
            )
            let slots = IslandExpandedTodoContentLayout.taskSlots(for: todo)
            return IslandExpandedTodoContentProbeRow(
                scenario: scenario,
                visibleTaskCount: slots.count,
                overdueTaskCount: slots.filter(\.isOverdue).count,
                completedTaskCount: slots.filter(\.isCompleted).count,
                supportsLongTitle: slots.allSatisfy { $0.title.isEmpty == false },
                fixedTaskListHeight: IslandExpandedTodoContentLayout.taskListHeight,
                startsInsideContentPhase: IslandExpandedTodoContentLayout.shouldRevealContent(in: .entering)
                    && IslandExpandedTodoContentLayout.shouldRevealContent(in: .visible)
                    && IslandExpandedTodoContentLayout.shouldRevealContent(in: .waitingForShell) == false
            )
        }
    }

    static func validate() throws {
        let rows = rows()
        guard rows.map(\.scenario) == ["empty", "normal", "overdue", "long-title", "six"],
              rows.map(\.visibleTaskCount) == [0, 2, 1, 1, 6],
              rows.map(\.overdueTaskCount) == [0, 0, 1, 0, 1],
              rows.map(\.completedTaskCount) == [0, 1, 0, 0, 1],
              rows.allSatisfy(\.supportsLongTitle),
              rows.allSatisfy({ $0.fixedTaskListHeight == 147 }),
              rows.allSatisfy(\.startsInsideContentPhase),
              IslandExpandedTodoContentLayout.maximumVisibleTasks == 6 else {
            throw IslandExpandedTodoContentProbeError.invalidLayout(rows)
        }
    }
}

enum IslandExpandedTodoContentProbeError: Error {
    case invalidLayout([IslandExpandedTodoContentProbeRow])
}

private extension AnyTransition {
    static let islandCompactContentCrossfade = AnyTransition.asymmetric(
        insertion: .modifier(
            active: IslandCompactContentTransitionStyle(opacity: 0, blurRadius: 4, offsetY: 6),
            identity: IslandCompactContentTransitionStyle(opacity: 1, blurRadius: 0, offsetY: 0)
        ),
        removal: .modifier(
            active: IslandCompactContentTransitionStyle(opacity: 0, blurRadius: 4, offsetY: -4),
            identity: IslandCompactContentTransitionStyle(opacity: 1, blurRadius: 0, offsetY: 0)
        )
    )
}

private struct MusicWaveformMark: View {
    let tint: Color
    let isPlaying: Bool
    let count: Int
    let displayScale: CGFloat

    var body: some View {
        // TimelineView only re-evaluates this mark. The shell and panel keep their
        // existing presentation values while music animates.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(tint.opacity(isPlaying ? 0.95 : 0.42))
                        .frame(
                            width: 3 * displayScale,
                            height: IslandMusicWaveform.height(
                                at: timeline.date.timeIntervalSinceReferenceDate,
                                barIndex: index,
                                displayScale: displayScale,
                                isPlaying: isPlaying
                            )
                        )
                }
            }
            .animation(.easeOut(duration: IslandMusicWaveform.pausedSettleDuration), value: isPlaying)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Music playing" : "Music paused")
    }
}

private extension Color {
    init(memoryFlowHex hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255
        let blue = Double(rgbValue & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
