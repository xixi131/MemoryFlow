import AppKit
import SwiftUI

enum IslandDebugAppearance {
    // Temporary contrast mode for calibrating compact and activity layout.
    static let usesLightNonExpandedShell = false
}

struct IslandVisualStatePreview: View {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let expandedContentTopInset: CGFloat
    let previewContent: IslandPreviewContent
    let musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    let todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    let reduceMotion: Bool
    let presentationShapeMetrics: IslandShapeMetrics?
    let presentationShapeState: IslandVisualState
    let presentationShadowAppearance: IslandShadowAppearanceTokens?
    let presentationShadowOutsets: IslandShadowOutsets?
    let contentPresentation: IslandContentPresentation
    var onAdvanceState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicControlInteraction: (() -> Void)?
    var onTodoTaskInteraction: ((String) -> Void)?
    var onLoginRequested: (() -> Void)?
    @State private var greetingPhase: IslandGreetingPhase = .cancelled
    @State private var greetingGate = IslandGreetingTransitionGate()
    @State private var greetingExpired = false
    @Namespace private var musicArtworkNamespace

    private var effectiveWidthConstraints: IslandWidthConstraints {
        guard greetingExpired else { return widthConstraints }
        return IslandWidthConstraints(
            baseBodyWidth: IslandVisualTokens.compact.previewWidth - 40,
            maximumVisibleWidth: widthConstraints.maximumVisibleWidth,
            contentWidthRequirement: .none,
            fixedVisibleWidth: widthConstraints.fixedVisibleWidth
        )
    }

    private var snapshot: IslandShapeLayoutSnapshot {
        if let presentationShapeMetrics {
            return IslandShapeEngine.snapshot(
                for: presentationShapeMetrics,
                state: presentationShapeState,
                shadowOutsetsOverride: presentationShadowOutsets
            )
        }

        return IslandCompactContentLayout.snapshot(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: effectiveWidthConstraints
        )
    }

    private var shellSpringTarget: IslandShellSpringTarget {
        IslandShellSpringTarget.resolve(
            state: state,
            presentationShapeMetrics: presentationShapeMetrics
        )
    }

    var body: some View {
        let snapshot = snapshot

        previewContainer(snapshot: snapshot)
            .background(Color.clear)
            .onAppear {
                scheduleGreetingLifecycle(for: previewContent)
            }
            .onChange(of: previewContent) { nextContent in
                scheduleGreetingLifecycle(for: nextContent)
            }
    }

    @ViewBuilder
    private func previewContainer(snapshot: IslandShapeLayoutSnapshot) -> some View {
        let content = ZStack(alignment: .topLeading) {
            composedShapeLayer(snapshot: snapshot)
                .applyAppleSpring(value: shellSpringTarget)
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
        let usesLightShell = IslandDebugAppearance.usesLightNonExpandedShell && snapshot.state.isExpanded == false
        let shellColor: Color = usesLightShell
            ? .white
            : .black

        ZStack(alignment: .topLeading) {
            Path(snapshot.leftCapPath)
                .fill(shellColor)
            Path(snapshot.rightCapPath)
                .fill(shellColor)
            Path(snapshot.leftEarPath)
                .fill(shellColor)
            Path(snapshot.rightEarPath)
                .fill(shellColor)
            Path(snapshot.bodyPath)
                .fill(shellColor)

            if let strokePath = snapshot.strokePath {
                Path(strokePath)
                    .stroke(usesLightShell ? Color.black.opacity(0.10) : Color.white.opacity(0.12), lineWidth: 1)
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
            expandedContentTopInset: expandedContentTopInset,
            isActivityContentVisible: true,
            isCompactContentVisible: true,
            isExpandedAppContentVisible: true,
            isExpandedMusicContentVisible: true,
            contentPhase: contentPresentation.phase,
            greetingPhase: greetingPhase,
            greetingExpired: greetingExpired,
            musicArtworkNamespace: musicArtworkNamespace,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            reduceMotion: reduceMotion,
            onMusicControlInteraction: onMusicControlInteraction,
            todoToggleScenarioRequest: todoToggleScenarioRequest,
            onTodoTaskInteraction: onTodoTaskInteraction,
            onLoginRequested: onLoginRequested
        )
            .frame(
                width: snapshot.contentFrame.width,
                height: snapshot.contentFrame.height,
                alignment: .topLeading
            )
            .opacity(contentPresentation.opacity)
            .blur(radius: contentPresentation.blurRadius)
            .scaleEffect(reduceMotion ? 1 : contentPresentation.scale)
            .offset(y: reduceMotion ? 0 : contentPresentation.offsetY)
            .allowsHitTesting(contentPresentation.allowsHitTesting)
            .accessibilityElement(children: .contain)
    }

    private func shadowColor(for snapshot: IslandShapeLayoutSnapshot) -> Color {
        if let presentationShadowAppearance {
            return Color.black.opacity(presentationShadowAppearance.opacity)
        }

        guard snapshot.metrics.showsShadow else {
            return .clear
        }

        return Color.black.opacity(shadowAppearance(for: snapshot).opacity)
    }

    private func shadowRadius(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        if let presentationShadowAppearance {
            return presentationShadowAppearance.radius
        }

        guard snapshot.metrics.showsShadow else {
            return 0
        }

        return shadowAppearance(for: snapshot).radius
    }

    private func shadowOffsetY(for snapshot: IslandShapeLayoutSnapshot) -> CGFloat {
        if let presentationShadowAppearance {
            return presentationShadowAppearance.offsetY
        }

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

enum IslandShellSpringTarget: Equatable {
    case swiftUI(IslandVisualState)
    case displayLinkOwned

    static func resolve(
        state: IslandVisualState,
        presentationShapeMetrics: IslandShapeMetrics?
    ) -> IslandShellSpringTarget {
        // AppKit supplies already-interpolated path and frame samples. Keeping this key
        // stable prevents SwiftUI from applying a second easing pass to those samples.
        guard presentationShapeMetrics == nil else { return .displayLinkOwned }
        return .swiftUI(state)
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

        guard widthConstraints.fixedVisibleWidth == nil,
              state == .compactCollapsed,
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

private struct IslandSquircleShape: Shape {
    let radius: CGFloat
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = IslandPathFactory.squircleBodyPath(
            width: rect.width,
            height: rect.height,
            radius: radius,
            smoothness: smoothness
        )
        return Path(path)
    }
}

private struct IslandPreviewContentOverlay: View {
    let content: IslandPreviewContent
    let state: IslandVisualState
    let snapshot: IslandShapeLayoutSnapshot
    let expandedContentTopInset: CGFloat
    let isActivityContentVisible: Bool
    let isCompactContentVisible: Bool
    let isExpandedAppContentVisible: Bool
    let isExpandedMusicContentVisible: Bool
    let contentPhase: IslandContentPhase
    let greetingPhase: IslandGreetingPhase
    let greetingExpired: Bool
    let musicArtworkNamespace: Namespace.ID
    let musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    let reduceMotion: Bool
    var onMusicControlInteraction: (() -> Void)?
    let todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    var onTodoTaskInteraction: ((String) -> Void)?
    var onLoginRequested: (() -> Void)?
    @State private var musicClock = IslandMockMusicProgressClock()
    @State private var playbackOverride: Bool?
    @State private var isFavorite = false

    private var compactForegroundColor: Color {
        IslandDebugAppearance.usesLightNonExpandedShell && state.isExpanded == false
            ? .black
            : .white
    }

    private var compactAccentColor: Color {
        IslandDebugAppearance.usesLightNonExpandedShell && state.isExpanded == false
            ? .black
            : tintColor
    }

    private var expandedHorizontalInset: CGFloat {
        IslandVisualTokens.expandedContentLayout.horizontalInset
    }

    private var expandedBottomInset: CGFloat {
        IslandVisualTokens.expandedContentLayout.bottomInset
    }

    private var expandedInnerCornerRadius: CGFloat {
        IslandVisualTokens.expandedContentLayout.innerCornerRadius(
            outerCornerRadius: snapshot.metrics.radius
        )
    }

    private var visibleContentFrame: CGRect {
        CGRect(
            x: snapshot.visibleFrame.minX,
            y: max(0, snapshot.visibleFrame.minY - snapshot.shadowOutsets.bottom),
            width: snapshot.visibleFrame.width,
            height: snapshot.visibleFrame.height
        )
    }

    private var expandedBodyFrame: CGRect {
        let bodyBounds = snapshot.bodyPath.boundingBoxOfPath
        return CGRect(
            x: bodyBounds.minX,
            y: max(0, bodyBounds.minY - snapshot.shadowOutsets.bottom),
            width: bodyBounds.width,
            height: bodyBounds.height
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if state == .activityCollapsed || state == .activityHoverCollapsed {
                compactActivityContent
                    .opacity(isActivityContentVisible ? 1 : 0)
                    .blur(radius: reduceMotion || isActivityContentVisible ? 0 : IslandVisualTokens.activityContentEnter.initialBlurRadius)
                    .offset(y: reduceMotion || isActivityContentVisible ? 0 : 4)
                    .allowsHitTesting(isActivityContentVisible)
                    .frame(
                        width: visibleContentFrame.width,
                        height: visibleContentFrame.height
                    )
                    .offset(x: visibleContentFrame.minX, y: visibleContentFrame.minY)
            } else if state == .compactCollapsed || state == .hoverCollapsed {
                compactContent
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
                        width: expandedBodyFrame.width,
                        height: expandedBodyFrame.height
                    )
                    .offset(x: expandedBodyFrame.minX, y: expandedBodyFrame.minY)
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
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(content.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(compactForegroundColor.opacity(0.92))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("island-login-command")
        .accessibilityLabel("Login to MemoryFlow")
    }

    private var loggedInIdleCompactContent: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(compactAccentColor.opacity(0.94))
            Text("MemoryFlow")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(compactForegroundColor.opacity(0.78))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Logged in idle")
    }

    private var greetingCompactContent: some View {
        let presentation = IslandGreetingSequence.presentation(for: greetingPhase)
        return Text(content.title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(compactForegroundColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .opacity(presentation.opacity)
            .offset(y: reduceMotion ? 0 : presentation.offsetY)
            .accessibilityLabel("Greeting")
    }

    private func runMockLoginCommand() {
        onLoginRequested?()
    }

    private var compactActivityContent: some View {
        let frames = IslandActivityNotchClearContentFrames.resolve(
            visibleSize: visibleContentFrame.size,
            contentWidthRequirement: content.contentWidthRequirement
        )

        return ZStack(alignment: .topLeading) {
            activityModeIcon
                .position(frames.leadingVisualCenter)

            Group {
                if let music = content.music {
                    MusicWaveformMark(
                        tint: compactForegroundColor,
                        isPlaying: music.isPlaying,
                        count: 4,
                        displayScale: snapshot.metrics.scale,
                        reduceMotion: reduceMotion
                    )
                    .frame(
                        width: IslandActivityContentWidthProfile.waveformWidth,
                        height: IslandActivityContentWidthProfile.waveformWidth
                    )
                } else {
                    activityCount
                }
            }
            .position(frames.trailingVisualCenter)
        }
        .frame(
            width: visibleContentFrame.width,
            height: visibleContentFrame.height,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private var activityModeIcon: some View {
        if content.music != nil {
            musicArtwork(
                presentation: IslandVisualTokens.activityMusicArtwork,
                isExpanded: false
            )
        } else {
            Image(systemName: content.todo != nil ? "checklist" : "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(compactAccentColor.opacity(0.96))
                .frame(
                    width: IslandActivityContentWidthProfile.iconSize,
                    height: IslandActivityContentWidthProfile.iconSize
                )
        }
    }

    private var activityCount: some View {
        Text(activityCountText)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(compactForegroundColor.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var activityCountText: String {
        if let todo = content.todo {
            return String(max(todo.pendingCount, 0))
        }
        if let review = content.review {
            return String(max(review.pendingCount, 0))
        }
        return "0"
    }

    @ViewBuilder
    private var expandedContent: some View {
        if state == .expandedMusic {
            expandedContentContainer {
                expandedMusicContent
            }
                .opacity(isExpandedMusicContentVisible ? 1 : 0)
                .blur(radius: isExpandedMusicContentVisible ? 0 : IslandVisualTokens.expandedMusicContentEnter.initialBlurRadius)
                .allowsHitTesting(isExpandedMusicContentVisible)
        } else {
            expandedContentContainer {
                expandedAppContent
            }
                .opacity(isExpandedAppContentVisible ? 1 : 0)
                .blur(radius: isExpandedAppContentVisible ? 0 : IslandVisualTokens.expandedAppContentEnter.initialBlurRadius)
                .allowsHitTesting(isExpandedAppContentVisible)
        }
    }

    private func expandedContentContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(
            IslandSquircleShape(
                radius: expandedInnerCornerRadius,
                smoothness: snapshot.metrics.smoothness
            )
        )
        .padding(.top, max(expandedContentTopInset, 0))
        .padding(.leading, expandedHorizontalInset)
        .padding(.bottom, expandedBottomInset)
        .padding(.trailing, expandedHorizontalInset)
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
                    displayScale: snapshot.metrics.scale,
                    reduceMotion: reduceMotion
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
                contentPhase: contentPhase,
                scenarioRequest: todoToggleScenarioRequest,
                onTaskInteraction: onTodoTaskInteraction
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
        .modifier(MusicArtworkMotionModifier(
            namespace: musicArtworkNamespace,
            isExpanded: isExpanded,
            presentation: presentation,
            reduceMotion: reduceMotion
        ))
        .accessibilityLabel(content.music?.artworkData == nil ? "Music artwork placeholder" : "Music artwork")
    }

    private func musicTrackIdentity(
        presentation: IslandMusicArtworkPresentation,
        isExpanded: Bool,
        titleSize: CGFloat,
        subtitleSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: isExpanded ? 14 : IslandActivityContentWidthProfile.identitySpacing
        ) {
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
            direction: musicTrackSwipeDirection,
            reduceMotion: reduceMotion
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                reviewCounter(value: max(review.pendingCount, 0), label: "待复习")
                reviewCounter(value: max(review.completedTodayCount, 0), label: "今日完成")
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
                Text("另有 \(review.subjectTitles.count - IslandExpandedReviewContentLayout.maximumVisibleSubjects) 个科目")
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
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear(perform: updateCardEntrance)
        .onChange(of: contentPhase) { _ in updateCardEntrance() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded review queue")
    }

    private func reviewCounter(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            IslandExpandedReviewSubjectSlot(id: "placeholder-\(index)", title: "暂无科目", isPlaceholder: true)
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
    let scenarioRequest: IslandTodoToggleScenarioRequest?
    var onTaskInteraction: ((String) -> Void)?
    @State private var summaryIsVisible = false
    @State private var rowsAreVisible = false
    @State private var localToggleState: IslandLocalTodoToggleState?

    private var taskSlots: [IslandExpandedTodoTaskSlot] {
        IslandExpandedTodoContentLayout.taskSlots(for: effectiveTodo)
    }

    private var effectiveTodo: IslandMockTodoActivity {
        localToggleState?.todo ?? todo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待办清单")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tint.opacity(0.9))
                    Text("今日计划")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                Text("待完成 \(max(effectiveTodo.pendingCount, 0)) 项")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(spacing: 7) {
                todoCounter(value: max(effectiveTodo.pendingCount, 0), label: "待完成")
                todoCounter(value: max(effectiveTodo.dueTodayCount, 0), label: "今日到期")
                todoCounter(value: max(effectiveTodo.overdueCount, 0), label: "已逾期", isUrgent: effectiveTodo.overdueCount > 0)
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
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear(perform: updateEntrance)
        .onChange(of: contentPhase) { _ in updateEntrance() }
        .onChange(of: todo) { nextTodo in
            localToggleState = IslandLocalTodoToggleState(todo: nextTodo)
            updateEntrance()
        }
        .onChange(of: scenarioRequest) { request in
            guard let request else { return }
            resolveScenarioRequest(request)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded todo list")
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint.opacity(0.84))
            Text("暂无待办")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
            Text("新的待办会显示在这里")
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
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isUrgent ? Color.red.opacity(0.92) : .white)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.10)))
    }

    private func taskRow(_ task: IslandExpandedTodoTaskSlot) -> some View {
        HStack(spacing: 7) {
            Button {
                onTaskInteraction?(task.id)
                toggleTask(id: task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? tint.opacity(0.9) : .white.opacity(0.42))
                    .scaleEffect(task.isCompleted ? 1.08 : 1)
                    .animation(IslandExpandedTodoContentLayout.toggleAnimation, value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .disabled(isTaskLocked(task.id))
            .opacity(isTaskLocked(task.id) ? 0.48 : 1)
            .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")

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
        .opacity(task.isCompleted ? 0.64 : 1)
        .animation(IslandExpandedTodoContentLayout.toggleAnimation, value: task.isCompleted)
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

    private func isTaskLocked(_ id: String) -> Bool {
        localToggleState?.isLocked(taskID: id) ?? false
    }

    private func toggleTask(id: String) {
        if localToggleState == nil {
            localToggleState = IslandLocalTodoToggleState(todo: todo)
        }
        withAnimation(IslandExpandedTodoContentLayout.toggleAnimation) {
            _ = localToggleState?.toggle(taskID: id)
        }
    }

    private func resolveScenarioRequest(_ request: IslandTodoToggleScenarioRequest) {
        withAnimation(IslandExpandedTodoContentLayout.toggleAnimation) {
            // A rollback changes only the affected task, preserving the current presentation of every other row.
            _ = localToggleState?.resolveMostRecent(outcome: request.outcome)
        }
    }
}

struct IslandLocalTodoToggleState: Equatable {
    private struct PendingToggle: Equatable {
        let originalIsCompleted: Bool
    }

    private(set) var todo: IslandMockTodoActivity
    private var pendingToggles: [String: PendingToggle] = [:]
    private var toggleOrder: [String] = []

    init(todo: IslandMockTodoActivity) {
        self.todo = todo
    }

    func isLocked(taskID: String) -> Bool {
        pendingToggles[taskID] != nil
    }

    mutating func toggle(taskID: String) -> Bool {
        guard pendingToggles[taskID] == nil,
              let index = todo.tasks.firstIndex(where: { $0.id == taskID }) else {
            return false
        }

        let task = todo.tasks[index]
        pendingToggles[taskID] = PendingToggle(originalIsCompleted: task.isCompleted)
        toggleOrder.append(taskID)
        todo.tasks[index] = IslandMockTodoTask(
            id: task.id,
            title: task.title,
            isCompleted: task.isCompleted == false,
            isDueToday: task.isDueToday,
            isOverdue: task.isOverdue
        )
        recomputeCounters()
        return true
    }

    mutating func resolveMostRecent(outcome: IslandTodoToggleScenarioOutcome) -> Bool {
        guard let taskID = toggleOrder.last,
              let pending = pendingToggles[taskID],
              let index = todo.tasks.firstIndex(where: { $0.id == taskID }) else {
            return false
        }

        if outcome == .rollback {
            let task = todo.tasks[index]
            todo.tasks[index] = IslandMockTodoTask(
                id: task.id,
                title: task.title,
                isCompleted: pending.originalIsCompleted,
                isDueToday: task.isDueToday,
                isOverdue: task.isOverdue
            )
            recomputeCounters()
        }

        pendingToggles[taskID] = nil
        toggleOrder.removeAll { $0 == taskID }
        return true
    }

    private mutating func recomputeCounters() {
        todo.pendingCount = todo.tasks.filter { $0.isCompleted == false }.count
        todo.dueTodayCount = todo.tasks.filter(\.isDueToday).count
        todo.overdueCount = todo.tasks.filter(\.isOverdue).count
        todo.nextTaskTitle = todo.tasks.first(where: { $0.isCompleted == false })?.title
    }
}

enum IslandTodoToggleProbe {
    static func validate() throws {
        var state = IslandLocalTodoToggleState(todo: .scenarioSample)
        let originalPending = state.todo.pendingCount

        guard state.toggle(taskID: "todo-1"),
              state.todo.tasks.first(where: { $0.id == "todo-1" })?.isCompleted == true,
              state.todo.pendingCount == originalPending - 1,
              state.isLocked(taskID: "todo-1"),
              state.toggle(taskID: "todo-1") == false else {
            throw IslandTodoToggleProbeError.optimisticToggleFailed
        }

        guard state.resolveMostRecent(outcome: .success),
              state.isLocked(taskID: "todo-1") == false,
              state.todo.tasks.first(where: { $0.id == "todo-1" })?.isCompleted == true else {
            throw IslandTodoToggleProbeError.successResolutionFailed
        }

        guard state.toggle(taskID: "todo-2"),
              state.resolveMostRecent(outcome: .rollback),
              state.isLocked(taskID: "todo-2") == false,
              state.todo.tasks.first(where: { $0.id == "todo-2" })?.isCompleted == false,
              state.todo.tasks.first(where: { $0.id == "todo-1" })?.isCompleted == true,
              state.todo.pendingCount == originalPending - 1 else {
            throw IslandTodoToggleProbeError.rollbackResolutionFailed
        }
    }
}

enum IslandTodoToggleProbeError: Error {
    case optimisticToggleFailed
    case successResolutionFailed
    case rollbackResolutionFailed
}

struct IslandExpandedTodoTaskSlot: Equatable, Identifiable {
    enum Priority: Equatable {
        case high
        case medium
        case normal

        var title: String {
            switch self {
            case .high: return "高"
            case .medium: return "中"
            case .normal: return "普通"
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
    static let rowSpacing: CGFloat = 2
    static let taskListHeight: CGFloat = 142
    static let rowsDelay: TimeInterval = 0.08
    static let rowStagger: TimeInterval = 0.035
    static let summaryAnimation = Animation.easeOut(duration: 0.16)
    static let rowAnimation = Animation.easeOut(duration: 0.18)
    static let toggleAnimation = Animation.spring(response: 0.26, dampingFraction: 0.78)

    static func taskSlots(for todo: IslandMockTodoActivity) -> [IslandExpandedTodoTaskSlot] {
        Array(todo.tasks.prefix(maximumVisibleTasks)).map { task in
            IslandExpandedTodoTaskSlot(
                id: task.id,
                title: task.title,
                dueText: task.isCompleted ? "已完成" : (task.isOverdue ? "已逾期" : (task.isDueToday ? "今日到期" : "已安排")),
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
              rows.allSatisfy({ $0.fixedTaskListHeight == 142 }),
              rows.allSatisfy(\.startsInsideContentPhase),
              IslandExpandedTodoContentLayout.maximumVisibleTasks == 6 else {
            throw IslandExpandedTodoContentProbeError.invalidLayout(rows)
        }
    }
}

enum IslandExpandedTodoContentProbeError: Error {
    case invalidLayout([IslandExpandedTodoContentProbeRow])
}

private struct MusicWaveformMark: View {
    let tint: Color
    let isPlaying: Bool
    let count: Int
    let displayScale: CGFloat
    let reduceMotion: Bool

    var body: some View {
        // TimelineView only re-evaluates this mark. The shell and panel keep their
        // existing presentation values while music animates.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying || reduceMotion)) { timeline in
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
                                isPlaying: isPlaying && !reduceMotion
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

private struct MusicArtworkMotionModifier: ViewModifier {
    let namespace: Namespace.ID
    let isExpanded: Bool
    let presentation: IslandMusicArtworkPresentation
    let reduceMotion: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content.animation(.linear(duration: IslandMotionTokens.reduceMotionDuration), value: presentation)
        } else {
            content
                .matchedGeometryEffect(id: "music-artwork", in: namespace, properties: .frame, anchor: .leading, isSource: !isExpanded)
                .animation(.easeInOut(duration: 0.46), value: presentation)
        }
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
