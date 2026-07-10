import AppKit
import SwiftUI

struct IslandVisualStatePreview: View {
    let state: IslandVisualState
    let visualScale: CGFloat
    let horizontalScale: CGFloat
    let widthConstraints: IslandWidthConstraints
    let previewContent: IslandPreviewContent
    var onAdvanceState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
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
            greetingPhase: greetingPhase,
            greetingExpired: greetingExpired,
            musicArtworkNamespace: musicArtworkNamespace
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
    let greetingPhase: IslandGreetingPhase
    let greetingExpired: Bool
    let musicArtworkNamespace: Namespace.ID

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
            musicArtwork(
                presentation: IslandVisualTokens.activityMusicArtwork,
                isExpanded: false
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(content.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(content.subtitle)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

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
                musicArtwork(
                    presentation: IslandVisualTokens.expandedMusicArtwork,
                    isExpanded: true
                )

                MusicTrackMetadata(title: content.title, artist: content.subtitle)

                Spacer(minLength: 12)

                MusicWaveformMark(
                    tint: tintColor,
                    isPlaying: content.music?.isPlaying ?? true,
                    count: 5,
                    displayScale: snapshot.metrics.scale
                )
                .frame(width: 34, height: 26)
            }

            progressRow

            musicTransportControls
        }
    }

    private var expandedAppContent: some View {
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
        HStack(spacing: 10) {
            Text(timeText(content.music?.elapsedSeconds))
                .frame(width: 34, alignment: .leading)

            GeometryReader { geometry in
                let progress = musicProgress

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(memoryFlowHex: "#222222"))
                    Capsule()
                        .fill(Color(memoryFlowHex: "#747376"))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)

            Text("-\(timeText(remainingSeconds))")
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.42))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private var musicTransportControls: some View {
        HStack(alignment: .center) {
            Image(systemName: "star")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white.opacity(0.46))

            Spacer(minLength: 0)

            Image(systemName: "backward.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Image(systemName: content.music?.isPlaying == false ? "play.fill" : "pause.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Image(systemName: "forward.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Image(systemName: "laptopcomputer")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
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

    private var musicProgress: CGFloat {
        guard let music = content.music,
              let duration = music.durationSeconds,
              duration > 0 else {
            return 0
        }

        return CGFloat(min(max(music.elapsedSeconds / duration, 0), 1))
    }

    private var remainingSeconds: TimeInterval? {
        guard let music = content.music,
              let duration = music.durationSeconds else {
            return nil
        }

        return max(0, duration - music.elapsedSeconds)
    }

    private func timeText(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "--:--" }
        let totalSeconds = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
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

    @State private var displayedTitle = ""
    @State private var displayedArtist = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            metadataText(displayedTitle, fontSize: 16, color: .white)
            metadataText(displayedArtist, fontSize: 13, color: .white.opacity(0.48))
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
