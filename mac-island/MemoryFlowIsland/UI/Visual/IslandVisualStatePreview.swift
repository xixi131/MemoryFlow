import AppKit
import SwiftUI

enum IslandDebugAppearance {
    // Temporary contrast mode for calibrating compact and activity layout.
    static let usesLightNonExpandedShell = false
}

private enum IslandTodoVisualStyle {
    static let accent = Color(red: 1, green: 149 / 255, blue: 0)
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
    @ObservedObject var waveformModel: MusicWaveformModel
    var onAdvanceState: (() -> Void)?
    var onGreetingLifecycleCompleted: (() -> Void)?
    var onMusicCommand: ((MusicCommand) -> Void)?
    var onMusicSeek: ((TimeInterval) -> Void)?
    var onMusicSeekInteractionStarted: (() -> Void)?
    var onTodoCompletionRequested: ((String) -> Void)?
    var onTodoDetailRequested: ((String) -> Void)?
    var onTodoDetailDismissed: (() -> Void)?
    var onLoginRequested: (() -> Void)?
    var onUpdateRequested: (() -> Void)?
    var onUpdateLaterRequested: (() -> Void)?
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
                DispatchQueue.main.async {
                    scheduleGreetingLifecycle(for: nextContent)
                }
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
            waveformModel: waveformModel,
            onMusicCommand: onMusicCommand,
            onMusicSeek: onMusicSeek,
            onMusicSeekInteractionStarted: onMusicSeekInteractionStarted,
            todoToggleScenarioRequest: todoToggleScenarioRequest,
            onTodoCompletionRequested: onTodoCompletionRequested,
            onTodoDetailRequested: onTodoDetailRequested,
            onTodoDetailDismissed: onTodoDetailDismissed,
            onLoginRequested: onLoginRequested,
            onUpdateRequested: onUpdateRequested,
            onUpdateLaterRequested: onUpdateLaterRequested
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
    @ObservedObject var waveformModel: MusicWaveformModel
    var onMusicCommand: ((MusicCommand) -> Void)?
    var onMusicSeek: ((TimeInterval) -> Void)?
    var onMusicSeekInteractionStarted: (() -> Void)?
    let todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    var onTodoCompletionRequested: ((String) -> Void)?
    var onTodoDetailRequested: ((String) -> Void)?
    var onTodoDetailDismissed: (() -> Void)?
    var onLoginRequested: (() -> Void)?
    var onUpdateRequested: (() -> Void)?
    var onUpdateLaterRequested: (() -> Void)?
    @State private var musicClock = IslandMockMusicProgressClock()
    @State private var playbackOverride: Bool?
    @State private var seekPreviewSeconds: TimeInterval?
    @State private var isFavorite = false
    @State private var decodedMusicArtwork: NSImage?
    @State private var isLoginButtonHovered = false
    @State private var isUpdateButtonHovered = false
    @State private var isUpdateLaterButtonHovered = false

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
        if content.kind == .expandedMusic {
            return 28
        }
        return IslandVisualTokens.expandedContentLayout.horizontalInset
    }

    private var expandedBottomInset: CGFloat {
        if content.kind == .expandedMusic {
            return 32
        }
        if content.kind == .loginRequired || content.kind == .updatePrompt {
            return 8
        }
        return IslandVisualTokens.expandedContentLayout.bottomInset
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
        .onAppear {
            resetMusicPresentation(for: content.music, clearsPlaybackOverride: true)
            decodeMusicArtwork(content.music?.artworkData)
        }
        .onChange(of: content.music) { previousMusic, nextMusic in
            if isPlaybackStateOnlyChange(from: previousMusic, to: nextMusic) {
                playbackOverride = nil
                musicClock.setPlaying(nextMusic?.isPlaying ?? false, at: .now)
            } else {
                resetMusicPresentation(for: nextMusic, clearsPlaybackOverride: true)
            }
            if let preview = seekPreviewSeconds,
               let elapsed = nextMusic?.elapsedSeconds,
               abs(elapsed - preview) <= 1.5 {
                seekPreviewSeconds = nil
            }
        }
        .onChange(of: content.music?.artworkData) { decodeMusicArtwork($0) }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch content.kind {
        case .signedOutCompact:
            Color.clear
                .accessibilityHidden(true)
        case .greetingCompact where greetingExpired == false:
            greetingCompactContent
                .allowsHitTesting(false)
        default:
            Color.clear
                .accessibilityHidden(true)
        }
    }

    private var greetingCompactContent: some View {
        let presentation = IslandGreetingSequence.presentation(for: greetingPhase)
        return Text(content.title)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(compactForegroundColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .opacity(presentation.opacity)
            .offset(y: reduceMotion ? 0 : presentation.offsetY)
            .accessibilityLabel("Greeting")
    }

    private func requestLogin() {
        onLoginRequested?()
    }

    private var compactActivityContent: some View {
        let frames = IslandActivityNotchClearContentFrames.resolve(
            visibleSize: visibleContentFrame.size,
            contentWidthRequirement: content.contentWidthRequirement
        )

        return ZStack(alignment: .topLeading) {
            Group {
                if content.kind == .updateDownloadActivity {
                    UpdateDownloadIndicator(reduceMotion: reduceMotion)
                } else {
                    activityModeIcon
                }
            }
                .position(frames.leadingVisualCenter)

            Group {
                if content.kind == .updateDownloadActivity {
                    Text(content.badge)
                        .font(.system(
                            size: IslandUpdateDownloadLayout.percentageFontSize,
                            weight: .bold,
                            design: .rounded
                        ))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: IslandUpdateDownloadLayout.percentageWidth, alignment: .trailing)
                        .accessibilityLabel("Update download \(content.badge)")
                } else if let music = content.music {
                    MusicWaveformMark(
                        colors: musicThemeColors,
                        isPlaying: music.isPlaying,
                        usesMockWaveform: music.sourceName == "Mock",
                        count: 4,
                        displayScale: snapshot.metrics.scale,
                        barThickness: 2,
                        amplitudeScale: 1,
                        reduceMotion: reduceMotion,
                        waveformModel: waveformModel
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
                .foregroundStyle(content.todo != nil ? IslandTodoVisualStyle.accent : compactAccentColor.opacity(0.96))
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
        @ViewBuilder contentBuilder: () -> Content
    ) -> some View {
        contentBuilder()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(
            IslandExpandedContentClipShape(
                topRadius: content.kind == .expandedReview || content.kind == .expandedTodo || content.kind == .expandedTodoDetail || content.kind == .expandedMusic
                    ? 0
                    : expandedInnerCornerRadius,
                bottomRadius: content.kind == .expandedReview || content.kind == .expandedTodo || content.kind == .expandedTodoDetail || content.kind == .expandedMusic
                    ? 0
                    : expandedInnerCornerRadius
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
                    colors: musicThemeColors,
                    isPlaying: effectiveMusicIsPlaying,
                    usesMockWaveform: content.music?.sourceName == "Mock",
                    count: 5,
                    displayScale: snapshot.metrics.scale,
                    barThickness: 2.3,
                    amplitudeScale: 1,
                    reduceMotion: reduceMotion,
                    waveformModel: waveformModel
                )
                .frame(width: 34, height: 21)
            }

            progressRow

            musicTransportControls
                .offset(y: -3)
        }
    }

    @ViewBuilder
    private var expandedAppContent: some View {
        if content.kind == .updatePrompt {
            updatePromptContent
        } else if content.kind == .loginRequired {
            promptCapsuleButton(
                title: "登陆",
                accessibilityLabel: "登陆",
                baseColorHex: IslandUpdatePromptLayout.updateColorHex,
                hoverColorHex: IslandUpdatePromptLayout.updateHoverColorHex,
                width: nil,
                isHovered: $isLoginButtonHovered,
                action: requestLogin
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
        } else if content.kind == .expandedReview, let review = content.review {
            IslandExpandedReviewContent(
                review: review,
                tint: tintColor,
                contentPhase: contentPhase
            )
        } else if content.kind == .expandedTodoDetail, let detail = content.todoDetail {
            IslandExpandedTodoDetailContent(detail: detail, onDismiss: onTodoDetailDismissed)
        } else if content.kind == .expandedTodo, let todo = content.todo {
            IslandExpandedTodoContent(
                todo: todo,
                tint: tintColor,
                contentPhase: contentPhase,
                scenarioRequest: todoToggleScenarioRequest,
                onCompletionRequested: onTodoCompletionRequested,
                onDetailRequested: onTodoDetailRequested
            )
        } else {
            genericExpandedAppContent
        }
    }

    private var updatePromptContent: some View {
        HStack(spacing: IslandUpdatePromptLayout.actionSpacing) {
            promptCapsuleButton(
                title: "稍后",
                accessibilityLabel: "稍后更新 MemoryFlow",
                baseColorHex: IslandUpdatePromptLayout.laterColorHex,
                hoverColorHex: IslandUpdatePromptLayout.laterHoverColorHex,
                width: IslandUpdatePromptLayout.actionWidth,
                height: IslandUpdatePromptLayout.actionHeight,
                fontSize: IslandUpdatePromptLayout.actionFontSize,
                horizontalPadding: IslandUpdatePromptLayout.actionHorizontalPadding,
                isHovered: $isUpdateLaterButtonHovered,
                action: { onUpdateLaterRequested?() }
            )
            promptCapsuleButton(
                title: "更新",
                accessibilityLabel: "更新 MemoryFlow",
                baseColorHex: IslandUpdatePromptLayout.updateColorHex,
                hoverColorHex: IslandUpdatePromptLayout.updateHoverColorHex,
                width: IslandUpdatePromptLayout.actionWidth,
                height: IslandUpdatePromptLayout.actionHeight,
                fontSize: IslandUpdatePromptLayout.actionFontSize,
                horizontalPadding: IslandUpdatePromptLayout.actionHorizontalPadding,
                isHovered: $isUpdateButtonHovered,
                action: { onUpdateRequested?() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func promptCapsuleButton(
        title: String,
        accessibilityLabel: String,
        baseColorHex: String,
        hoverColorHex: String,
        width: CGFloat?,
        height: CGFloat = 26,
        fontSize: CGFloat = 14,
        horizontalPadding: CGFloat = 14,
        isHovered: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, horizontalPadding)
                .frame(width: width, height: height)
                .background(
                    Capsule().fill(
                        Color(memoryFlowHex: isHovered.wrappedValue ? hoverColorHex : baseColorHex)
                    )
                )
                .contentShape(Capsule())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered.wrappedValue)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .onHover { nextValue in
            guard isHovered.wrappedValue != nextValue else { return }
            DispatchQueue.main.async {
                isHovered.wrappedValue = nextValue
            }
        }
        .accessibilityLabel(accessibilityLabel)
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
        TimelineView(.animation(
            minimumInterval: IslandMusicWaveform.minimumFrameInterval,
            paused: !effectiveMusicIsPlaying || reduceMotion
        )) { timeline in
            let elapsed = musicClock.elapsed(at: timeline.date)
            let displayedElapsed = seekPreviewSeconds ?? elapsed
            let progress = musicProgress(for: displayedElapsed)
            let remaining = remainingSeconds(for: displayedElapsed)
            HStack(spacing: 2) {
                Text(timeText(displayedElapsed))
                    .frame(width: 46, alignment: .leading)

                GeometryReader { _ in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(memoryFlowHex: "#222222"))
                        Rectangle()
                            .fill(Color(memoryFlowHex: "#747376"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: progress, y: 1, anchor: .leading)

                        MusicProgressScrubbingView(
                            onBegan: {
                                onMusicSeekInteractionStarted?()
                            },
                            onChanged: { normalizedProgress in
                                seekPreviewSeconds = seekTarget(progress: normalizedProgress)
                            },
                            onEnded: { normalizedProgress in
                                let target = seekTarget(progress: normalizedProgress)
                                seekPreviewSeconds = target
                                registerMusicSeek(target)
                            }
                        )
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 6)

                Text("-\(timeText(remaining))")
                    .frame(width: 54, alignment: .trailing)
            }
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.42))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
    }

    private var musicTransportControls: some View {
        HStack(alignment: .center, spacing: 28) {
            MusicTransportButton(
                symbol: isFavorite ? "star.fill" : "star",
                size: 19,
                tint: .white.opacity(0.46),
                label: "Favorite mock track"
            ) {
                isFavorite.toggle()
            }

            MusicTransportButton(
                symbol: "backward.fill",
                size: 20.4,
                tint: .white,
                label: "Previous track"
            ) {
                registerMusicCommand(.previous)
            }

            MusicTransportButton(
                symbol: effectiveMusicIsPlaying ? "pause.fill" : "play.fill",
                size: 28.9,
                tint: .white,
                label: effectiveMusicIsPlaying ? "Pause track" : "Play track"
            ) {
                let nextIsPlaying = !effectiveMusicIsPlaying
                musicClock.setPlaying(nextIsPlaying, at: .now)
                playbackOverride = nextIsPlaying
                registerMusicCommand(.playPause)
            }

            MusicTransportButton(
                symbol: "forward.fill",
                size: 20.4,
                tint: .white,
                label: "Next track"
            ) {
                registerMusicCommand(.next)
            }

            MusicTransportButton(
                symbol: "laptopcomputer",
                size: 19,
                tint: .white.opacity(0.42),
                label: content.music?.sourceName ?? "Playback device",
                action: {}
            )
        }
        .padding(.horizontal, 6)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .center)
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
            if let image = decodedMusicArtwork {
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
            if let image = decodedMusicArtwork {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MusicArtworkMask(
                    radius: presentation.radius,
                    smoothness: presentation.smoothness,
                    usesBulgedCorners: isExpanded
                )
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
        .clipShape(MusicArtworkMask(
            radius: presentation.radius,
            smoothness: presentation.smoothness,
            usesBulgedCorners: isExpanded
        ))
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
            alignment: isExpanded ? .bottom : .center,
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

    private func isPlaybackStateOnlyChange(
        from previous: IslandMockMusicActivity?,
        to next: IslandMockMusicActivity?
    ) -> Bool {
        guard let previous, let next else { return false }
        return previous.trackTitle == next.trackTitle &&
            previous.artistName == next.artistName &&
            previous.isPlaying != next.isPlaying
    }

    private func decodeMusicArtwork(_ artworkData: Data?) {
        guard let artworkData else {
            decodedMusicArtwork = nil
            return
        }
        decodedMusicArtwork = NSImage(data: artworkData)
    }

    private func registerMusicCommand(_ command: MusicCommand) {
        onMusicCommand?(command)
    }

    private func registerMusicSeek(_ position: TimeInterval) {
        onMusicSeek?(position)
    }

    private func seekTarget(progress: CGFloat) -> TimeInterval {
        guard let duration = content.music?.durationSeconds,
              duration > 0 else {
            return content.music?.elapsedSeconds ?? 0
        }
        return duration * TimeInterval(min(max(progress, 0), 1))
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

    private var musicThemeColors: [Color] {
        let hexColors = content.music?.themePalette.colorsHex ?? [MusicThemePalette.fallbackHex]
        return hexColors.map { Color(memoryFlowHex: $0) }
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
    let usesBulgedCorners: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, smoothness) }
        set {
            radius = newValue.first
            smoothness = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let corner = min(max(radius, 0), min(rect.width, rect.height) / 2)
        if usesBulgedCorners {
            return puffyPath(in: rect)
        }

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

    private func puffyPath(in rect: CGRect) -> Path {
        let steps = 72
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2
        let minimumSide = min(rect.width, rect.height)
        let normalizedRadius = min(max(radius / max(minimumSide, 0.001), 0.1), 0.34)
        let superellipseN = min(
            max(3.9 + normalizedRadius * 8.5 + (2.4 - smoothness) * 2.2, 3.8),
            7.2
        )
        let exponent = 2 / superellipseN

        var path = Path()
        for index in 0...steps {
            let angle = (-CGFloat.pi / 2) + (2 * CGFloat.pi * CGFloat(index) / CGFloat(steps))
            let cosine = cos(angle)
            let sine = sin(angle)
            let point = CGPoint(
                x: center.x + halfWidth * signedPower(cosine, exponent: exponent),
                y: center.y + halfHeight * signedPower(sine, exponent: exponent)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func signedPower(_ value: CGFloat, exponent: CGFloat) -> CGFloat {
        guard abs(value) > 0.000_001 else { return 0 }
        return (value < 0 ? -1 : 1) * pow(abs(value), exponent)
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

private struct IslandReviewScrollOffsetReader: NSViewRepresentable {
    @Binding var offset: CGFloat

    func makeNSView(context: Context) -> IslandReviewScrollOffsetProbeView {
        let view = IslandReviewScrollOffsetProbeView()
        view.onOffsetChange = { nextOffset in
            offset = nextOffset
        }
        return view
    }

    func updateNSView(_ nsView: IslandReviewScrollOffsetProbeView, context: Context) {
        nsView.onOffsetChange = { nextOffset in
            offset = nextOffset
        }
        nsView.attachIfNeeded()
    }
}

private final class IslandReviewScrollOffsetProbeView: NSView {
    var onOffsetChange: ((CGFloat) -> Void)?
    private weak var observedClipView: NSClipView?
    private var boundsObserver: NSObjectProtocol?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attachIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard let clipView = enclosingScrollView?.contentView else {
            DispatchQueue.main.async { [weak self] in self?.attachIfNeeded() }
            return
        }
        guard observedClipView !== clipView else {
            publishOffset(from: clipView)
            return
        }

        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        observedClipView = clipView
        clipView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self, weak clipView] _ in
            guard let self, let clipView else { return }
            self.publishOffset(from: clipView)
        }
        publishOffset(from: clipView)
    }

    deinit {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
    }

    private func publishOffset(from clipView: NSClipView) {
        onOffsetChange?(max(clipView.bounds.minY, 0))
    }
}

private struct IslandExpandedReviewContent: View {
    let review: IslandMockReviewActivity
    let tint: Color
    let contentPhase: IslandContentPhase
    @State private var cardsAreVisible = false
    @State private var scrollOffset: CGFloat = 0

    private var slots: [IslandExpandedReviewSubjectSlot] {
        IslandExpandedReviewContentLayout.subjectSlots(for: review)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        reviewCounterRow
                            .scaleEffect(1 - (collapseProgress * 0.18), anchor: .topLeading)
                            .opacity(Double(1 - (collapseProgress * 0.5)))
                            .background(
                                IslandReviewScrollOffsetReader(offset: $scrollOffset)
                            )

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
                    }
                    .padding(.bottom, 8)
                }

                if collapseProgress > 0.01 {
                    ZStack(alignment: .top) {
                        topGlassFade
                        compactHeader
                    }
                        .opacity(collapseProgress)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .zIndex(2)
                }

                bottomGlassFade
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(1)

            }
        }
        .onAppear(perform: updateCardEntrance)
        .onChange(of: contentPhase) { _ in updateCardEntrance() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded review queue")
    }

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / IslandExpandedReviewContentLayout.headerCollapseDistance, 0), 1)
    }

    private var reviewCounterRow: some View {
        HStack(spacing: 8) {
            reviewCounter(value: max(review.pendingCount, 0), label: "待复习")
            reviewCounter(value: max(review.completedTodayCount, 0), label: "今日完成")
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            compactCounter(value: max(review.pendingCount, 0), label: "待复习")
            compactCounter(value: max(review.completedTodayCount, 0), label: "今日完成")
        }
        .frame(height: IslandExpandedReviewContentLayout.compactHeaderHeight)
        .padding(.horizontal, 2)
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

    private func compactCounter(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
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

    private var topGlassFade: some View {
        glassFade(height: IslandExpandedReviewContentLayout.topFadeHeight)
    }

    private func glassFade(height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.18)
                .mask(
                    IslandMaterialFeatherMask(
                        verticalStops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.82), location: 0.14),
                            .init(color: .black.opacity(0.68), location: 0.42),
                            .init(color: .black.opacity(0.34), location: 0.68),
                            .init(color: .black.opacity(0.10), location: 0.88),
                            .init(color: .clear, location: 1)
                        ]
                    )
                )

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.98), location: 0),
                    .init(color: .black.opacity(0.94), location: 0.34),
                    .init(color: .black.opacity(0.78), location: 0.55),
                    .init(color: .black.opacity(0.46), location: 0.72),
                    .init(color: .black.opacity(0.17), location: 0.88),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    private var bottomGlassFade: some View {
        glassFade(height: IslandExpandedReviewContentLayout.bottomGlassFadeHeight)
            .rotationEffect(.degrees(180))
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

private struct IslandMaterialFeatherMask: View {
    let verticalStops: [Gradient.Stop]

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.72), location: 0.07),
                .init(color: .black, location: 0.16),
                .init(color: .black, location: 0.84),
                .init(color: .black.opacity(0.72), location: 0.93),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            LinearGradient(
                stops: verticalStops,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct IslandExpandedContentClipShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let top = min(max(topRadius, 0), min(rect.width, rect.height) / 2)
        let bottom = min(max(bottomRadius, 0), min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct IslandExpandedReviewSubjectSlot: Equatable, Identifiable {
    let id: String
    let title: String
    let isPlaceholder: Bool
}

enum IslandExpandedReviewContentLayout {
    static let minimumGridSlots = 8
    static let childDelay: TimeInterval = 0.10
    static let childStagger: TimeInterval = 0.05
    static let initialCardScale: CGFloat = 0.9
    static let cardAnimation = Animation.interpolatingSpring(stiffness: 300, damping: 20)
    static let headerCollapseDistance: CGFloat = 54
    static let compactHeaderHeight: CGFloat = 38
    static let topFadeHeight: CGFloat = 90
    static let bottomGlassFadeHeight: CGFloat = 20

    static func subjectSlots(for review: IslandMockReviewActivity) -> [IslandExpandedReviewSubjectSlot] {
        let realSlots = review.subjectTitles.enumerated().map { index, title in
            IslandExpandedReviewSubjectSlot(id: "subject-\(index)", title: title, isPlaceholder: false)
        }
        let placeholderCount = max(minimumGridSlots - realSlots.count, 0)
        let placeholders = (0..<placeholderCount).map { offset in
            IslandExpandedReviewSubjectSlot(
                id: "placeholder-\(realSlots.count + offset)",
                title: "暂无科目",
                isPlaceholder: true
            )
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
                extraSubjectCount: max(subjects.count - IslandExpandedReviewContentLayout.minimumGridSlots, 0),
                firstCardDelay: IslandExpandedReviewContentLayout.cardDelay(for: 0),
                lastCardDelay: IslandExpandedReviewContentLayout.cardDelay(for: max(slots.count - 1, 0)),
                startsInsideContentPhase: IslandExpandedReviewContentLayout.shouldRevealCards(in: .entering)
                    && IslandExpandedReviewContentLayout.shouldRevealCards(in: .visible)
                    && IslandExpandedReviewContentLayout.shouldRevealCards(in: .waitingForShell) == false
            )
        }
    }

    static func validate() throws {
        let rows = rows()
        guard rows.map(\.scenario) == ["zero", "partial", "four", "more"],
              rows.map(\.realCardCount) == [0, 2, 4, 6],
              rows.map(\.placeholderCount) == [8, 6, 4, 2],
              rows.map(\.extraSubjectCount) == [0, 0, 0, 0],
              rows.map(\.lastCardDelay) == [0.45, 0.45, 0.45, 0.45],
              rows.allSatisfy({ $0.firstCardDelay == 0.10 }),
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
    var onCompletionRequested: ((String) -> Void)?
    var onDetailRequested: ((String) -> Void)?
    @State private var summaryIsVisible = false
    @State private var rowsAreVisible = false
    @State private var localToggleState: IslandLocalTodoToggleState?
    @State private var scrollOffset: CGFloat = 0

    private var taskSlots: [IslandExpandedTodoTaskSlot] {
        IslandExpandedTodoContentLayout.taskSlots(for: effectiveTodo)
    }

    private var effectiveTodo: IslandMockTodoActivity {
        localToggleState?.todo ?? todo
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        todoCounterRow
                            .scaleEffect(1 - (collapseProgress * 0.18), anchor: .topLeading)
                            .opacity(Double(1 - (collapseProgress * 0.5)) * (summaryIsVisible ? 1 : 0))
                            .offset(y: summaryIsVisible ? 0 : 4)
                            .animation(IslandExpandedTodoContentLayout.summaryAnimation, value: summaryIsVisible)
                            .background(
                                IslandReviewScrollOffsetReader(offset: $scrollOffset)
                            )

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
                        .animation(.easeOut(duration: 0.18), value: taskSlots)
                    }
                    .padding(.bottom, 8)
                }

                if collapseProgress > 0.01 {
                    ZStack(alignment: .top) {
                        topGlassFade
                        compactHeader
                    }
                        .opacity(collapseProgress)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .zIndex(2)
                }

                bottomGlassFade
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(1)
            }
        }
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

    private var collapseProgress: CGFloat {
        min(max(scrollOffset / IslandExpandedTodoContentLayout.headerCollapseDistance, 0), 1)
    }

    private var todoCounterRow: some View {
        HStack(spacing: 8) {
            todoCounter(value: max(effectiveTodo.pendingCount, 0), label: "待完成", usesAccent: true)
            todoCounter(value: max(effectiveTodo.dueTodayCount, 0), label: "今日到期")
            todoCounter(
                value: max(effectiveTodo.overdueCount, 0),
                label: "已逾期",
                isUrgent: effectiveTodo.overdueCount > 0
            )
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            compactCounter(value: max(effectiveTodo.pendingCount, 0), label: "待完成", usesAccent: true)
            compactCounter(value: max(effectiveTodo.dueTodayCount, 0), label: "今日到期")
            compactCounter(
                value: max(effectiveTodo.overdueCount, 0),
                label: "已逾期",
                isUrgent: effectiveTodo.overdueCount > 0
            )
        }
        .frame(height: IslandExpandedTodoContentLayout.compactHeaderHeight)
        .padding(.horizontal, 2)
    }

    private func compactCounter(
        value: Int,
        label: String,
        isUrgent: Bool = false,
        usesAccent: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isUrgent ? Color.red.opacity(0.92) : .white)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(usesAccent ? IslandTodoVisualStyle.accent : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topGlassFade: some View {
        glassFade(height: IslandExpandedTodoContentLayout.topFadeHeight)
    }

    private func glassFade(height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.18)
                .mask(
                    IslandMaterialFeatherMask(
                        verticalStops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.82), location: 0.14),
                            .init(color: .black.opacity(0.68), location: 0.42),
                            .init(color: .black.opacity(0.34), location: 0.68),
                            .init(color: .black.opacity(0.10), location: 0.88),
                            .init(color: .clear, location: 1)
                        ]
                    )
                )

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.98), location: 0),
                    .init(color: .black.opacity(0.94), location: 0.34),
                    .init(color: .black.opacity(0.78), location: 0.55),
                    .init(color: .black.opacity(0.46), location: 0.72),
                    .init(color: .black.opacity(0.17), location: 0.88),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    private var bottomGlassFade: some View {
        glassFade(height: IslandExpandedTodoContentLayout.bottomGlassFadeHeight)
            .rotationEffect(.degrees(180))
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .opacity(rowsAreVisible ? 1 : 0)
        .offset(y: rowsAreVisible ? 0 : 5)
        .animation(IslandExpandedTodoContentLayout.rowAnimation, value: rowsAreVisible)
        .accessibilityIdentifier("island-todo-empty-state")
    }

    private func todoCounter(
        value: Int,
        label: String,
        isUrgent: Bool = false,
        usesAccent: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(isUrgent ? Color.red.opacity(0.92) : .white)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(usesAccent ? IslandTodoVisualStyle.accent : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskRow(_ task: IslandExpandedTodoTaskSlot) -> some View {
        HStack(spacing: 7) {
            Button {
                performRowAction(target: .checkbox, taskID: task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? tint.opacity(0.9) : .white.opacity(0.42))
                    .scaleEffect(task.isCompleted ? 1.08 : 1)
                    .animation(IslandExpandedTodoContentLayout.toggleAnimation, value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .disabled(isTaskLocked(task.id))
            .opacity(isTaskLocked(task.id) ? 0.48 : 1)
            .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")
            .accessibilityIdentifier("island-todo-checkbox-\(task.id)")

            Button {
                performRowAction(target: .body, taskID: task.id)
            } label: {
                HStack(spacing: 7) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(task.isCompleted ? .white.opacity(0.42) : .white.opacity(0.9))
                            .strikethrough(task.isCompleted, color: .white.opacity(0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                        Text(task.dueText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(task.isOverdue ? Color.red.opacity(0.92) : .white.opacity(0.48))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(task.priority.title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(task.priority.color)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("island-todo-detail-target-\(task.id)")
            .accessibilityLabel("Open details for \(task.title)")
        }
        .padding(.horizontal, 2)
        .frame(height: IslandExpandedTodoContentLayout.rowHeight)
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
            rowsAreVisible = true
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

    private func performRowAction(target: IslandTodoRowHitTarget, taskID: String) {
        switch IslandTodoRowHitRegion.action(for: target) {
        case .completion:
            onCompletionRequested?(taskID)
            toggleTask(id: taskID)
        case .detail:
            onDetailRequested?(taskID)
        }
    }

    private func resolveScenarioRequest(_ request: IslandTodoToggleScenarioRequest) {
        withAnimation(IslandExpandedTodoContentLayout.toggleAnimation) {
            // A rollback changes only the affected task, preserving the current presentation of every other row.
            _ = localToggleState?.resolveMostRecent(outcome: request.outcome)
        }
    }
}

private struct IslandExpandedTodoDetailContent: View {
    let detail: IslandTodoDetailPresentation
    var onDismiss: (() -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: { onDismiss?() }) {
                    Label("返回", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(IslandTodoVisualStyle.accent)
                .accessibilityIdentifier("island-todo-detail-back")

                Text(detail.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail.descriptionText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(detail.hasDescription ? .white.opacity(0.72) : .white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    metadataRow("优先级", detail.priorityText)
                    metadataRow("日期", detail.dateText)
                    metadataRow("时间", detail.timeText)
                    metadataRow("状态", detail.statusText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .accessibilityIdentifier("island-todo-detail")
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .foregroundStyle(.white.opacity(0.44))
                .frame(width: 44, alignment: .leading)
            Text(value)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
    }
}

enum IslandTodoRowHitTarget: Equatable {
    case checkbox
    case body
}

enum IslandTodoRowAction: Equatable {
    case completion
    case detail
}

enum IslandTodoRowHitRegion {
    static func action(for target: IslandTodoRowHitTarget) -> IslandTodoRowAction {
        switch target {
        case .checkbox: return .completion
        case .body: return .detail
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
            descriptionMd: task.descriptionMd,
            priority: task.priority,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
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
                descriptionMd: task.descriptionMd,
                priority: task.priority,
                dueDate: task.dueDate,
                dueTime: task.dueTime,
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
    let id: String
    let title: String
    let dueText: String
    let priority: IslandTodoPriority
    let isOverdue: Bool
    let isCompleted: Bool
}

private extension IslandTodoPriority {
    var color: Color {
        switch self {
        case .high: return .red.opacity(0.94)
        case .medium: return .orange.opacity(0.92)
        case .low: return .white.opacity(0.72)
        case .none: return .white.opacity(0.42)
        }
    }
}

enum IslandExpandedTodoContentLayout {
    static let maximumVisibleTasks = 6
    static let rowHeight: CGFloat = 38
    static let rowSpacing: CGFloat = 7
    static let usesRowBackground = false
    static let usesRowBorder = false
    static let headerCollapseDistance = IslandExpandedReviewContentLayout.headerCollapseDistance
    static let compactHeaderHeight = IslandExpandedReviewContentLayout.compactHeaderHeight
    static let topFadeHeight = IslandExpandedReviewContentLayout.topFadeHeight
    static let bottomGlassFadeHeight = IslandExpandedReviewContentLayout.bottomGlassFadeHeight
    static let rowsDelay = IslandExpandedReviewContentLayout.childDelay
    static let rowStagger = IslandExpandedReviewContentLayout.childStagger
    static let summaryAnimation = Animation.easeOut(duration: 0.16)
    static let rowAnimation = IslandExpandedReviewContentLayout.cardAnimation
    static let toggleAnimation = Animation.spring(response: 0.26, dampingFraction: 0.78)

    static func taskSlots(
        for todo: IslandMockTodoActivity,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [IslandExpandedTodoTaskSlot] {
        Array(todo.tasks.prefix(maximumVisibleTasks)).map { task in
            IslandExpandedTodoTaskSlot(
                id: task.id,
                title: task.title,
                dueText: dueText(for: task, now: now, calendar: calendar),
                priority: task.priority,
                isOverdue: task.isOverdue,
                isCompleted: task.isCompleted
            )
        }
    }

    static func dueText(
        for task: IslandMockTodoTask,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if task.isCompleted { return "已完成" }
        if task.isOverdue { return "已逾期" }
        guard let dueDate = localDate(task.dueDate, calendar: calendar) else { return "未设置日期" }

        let timeText = localTime(task.dueTime)
        if task.isDueToday || calendar.isDate(dueDate, inSameDayAs: now) {
            return timeText.map { "今日 \($0)" } ?? "今日到期"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            return timeText.map { "明日 \($0)" } ?? "明日到期"
        }

        let dateText = "\(calendar.component(.month, from: dueDate))月\(calendar.component(.day, from: dueDate))日"
        return timeText.map { "\(dateText) \($0)" } ?? dateText
    }

    private static func localDate(_ value: String?, calendar: Calendar) -> Date? {
        guard let value else { return nil }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func localTime(_ value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else { return nil }
        return String(format: "%02d:%02d", hour, minute)
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
    let rowHeight: CGFloat
    let usesRowBackground: Bool
    let usesRowBorder: Bool
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
                rowHeight: IslandExpandedTodoContentLayout.rowHeight,
                usesRowBackground: IslandExpandedTodoContentLayout.usesRowBackground,
                usesRowBorder: IslandExpandedTodoContentLayout.usesRowBorder,
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
              rows.allSatisfy({ $0.rowHeight == 38 }),
              rows.allSatisfy({ $0.usesRowBackground == false && $0.usesRowBorder == false }),
              rows.allSatisfy(\.startsInsideContentPhase),
              IslandExpandedTodoContentLayout.rowsDelay == IslandExpandedReviewContentLayout.childDelay,
              IslandExpandedTodoContentLayout.rowStagger == IslandExpandedReviewContentLayout.childStagger,
              IslandExpandedTodoContentLayout.maximumVisibleTasks == 6 else {
            throw IslandExpandedTodoContentProbeError.invalidLayout(rows)
        }
    }
}

enum IslandExpandedTodoContentProbeError: Error {
    case invalidLayout([IslandExpandedTodoContentProbeRow])
}

private struct MusicProgressScrubbingView: NSViewRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeNSView(context: Context) -> MusicProgressScrubbingNSView {
        let view = MusicProgressScrubbingNSView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: MusicProgressScrubbingNSView, context: Context) {
        nsView.onBegan = onBegan
        nsView.onChanged = onChanged
        nsView.onEnded = onEnded
    }
}

private final class MusicProgressScrubbingNSView: NSView {
    var onBegan: () -> Void = {}
    var onChanged: (CGFloat) -> Void = { _ in }
    var onEnded: (CGFloat) -> Void = { _ in }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        onBegan()
        onChanged(normalizedProgress(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onChanged(normalizedProgress(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        onEnded(normalizedProgress(for: event))
    }

    private func normalizedProgress(for event: NSEvent) -> CGFloat {
        guard bounds.width > 0 else { return 0 }
        let point = convert(event.locationInWindow, from: nil)
        return min(max(point.x / bounds.width, 0), 1)
    }
}

private struct UpdateDownloadIndicator: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: IslandUpdateDownloadLayout.rotationDuration)
                / IslandUpdateDownloadLayout.rotationDuration
            ZStack {
                Circle()
                    .stroke(indicatorColor.opacity(0.24), lineWidth: 2.4)
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        indicatorColor,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(reduceMotion ? -35 : phase * 360 - 90))
                if reduceMotion {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(
            width: IslandUpdateDownloadLayout.indicatorSize,
            height: IslandUpdateDownloadLayout.indicatorSize
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Downloading update")
    }

    private var indicatorColor: Color {
        Color(memoryFlowHex: IslandUpdateDownloadLayout.indicatorColorHex)
    }
}

private struct MusicWaveformMark: View {
    let colors: [Color]
    let isPlaying: Bool
    let usesMockWaveform: Bool
    let count: Int
    let displayScale: CGFloat
    let barThickness: CGFloat
    let amplitudeScale: CGFloat
    let reduceMotion: Bool
    @ObservedObject var waveformModel: MusicWaveformModel

    var body: some View {
        TimelineView(.animation(
            minimumInterval: IslandMusicWaveform.minimumFrameInterval,
            paused: !isPlaying || reduceMotion
        )) { timeline in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let barWidth = barThickness * displayScale
                let spacing: CGFloat = 2
                let totalWidth = (barWidth * CGFloat(count)) + (spacing * CGFloat(max(count - 1, 0)))
                let startX = max((size.width - totalWidth) / 2, 0)
                let opacity = isPlaying ? 0.95 : 0.42
                let colors = gradientColors.map { $0.opacity(opacity) }

                for index in 0..<count {
                    let restingHeight = IslandMusicWaveform.pattern[0] * displayScale
                    let rawHeight: CGFloat
                    if usesMockWaveform {
                        rawHeight = IslandMusicWaveform.height(
                            at: timeline.date.timeIntervalSinceReferenceDate,
                            barIndex: index,
                            displayScale: displayScale,
                            isPlaying: isPlaying && !reduceMotion
                        )
                    } else {
                        let sourceLevel = reduceMotion || !isPlaying
                            ? 0
                            : waveformModel.frame.level(forBar: index, barCount: count)
                        let level = IslandMusicWaveform.liveLevel(
                            sourceLevel,
                            barIndex: index,
                            barCount: count
                        )
                        rawHeight = restingHeight + ((size.height - restingHeight) * CGFloat(level))
                    }
                    let compressedHeight = restingHeight + (rawHeight - restingHeight) * amplitudeScale
                    let height = min(compressedHeight, size.height)
                    let rect = CGRect(
                        x: startX + CGFloat(index) * (barWidth + spacing),
                        y: (size.height - height) / 2,
                        width: barWidth,
                        height: height
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: colors),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                        )
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Music playing" : "Music paused")
    }

    private var gradientColors: [Color] {
        guard let first = colors.first else {
            return [Color(memoryFlowHex: MusicThemePalette.fallbackHex)]
        }
        return colors.count == 1 ? [first, first] : colors
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
