import AppKit
import QuartzCore
import SwiftUI

protocol IslandPhase5ScenarioControlling: AnyObject {
    var availablePhase5Scenarios: [IslandMockScenario] { get }
    func selectPhase5Scenario(id: String)
}

protocol IslandPhase5InteractionDemoControlling: AnyObject {
    var availablePhase5InteractionDemoControls: [IslandPhase5InteractionDemoControl] { get }
    func triggerPhase5InteractionDemo(_ control: IslandPhase5InteractionDemoControl)
}

private struct IslandMotionTransitionRequest {
    let previous: IslandDerivedState
    let next: IslandDerivedState
    let reason: IslandPresentationTransitionReason
    let completionIdentifier: String?
    let durationOverride: TimeInterval?
}

private struct IslandActiveMotion {
    let generation: Int
    let sourceSizing: IslandWindowSizingResult
    let targetSizing: IslandWindowSizingResult
    let sourceShapeMetrics: IslandShapeMetrics
    let targetShapeMetrics: IslandShapeMetrics
    let sourceShadow: IslandShadowAppearanceTokens
    let targetShadow: IslandShadowAppearanceTokens
    let sourcePresentation: IslandRenderPresentation
    let targetLayoutInput: IslandPreviewLayoutInput
    let targetVisualScale: CGFloat
    let targetHorizontalScale: CGFloat
    let plan: IslandMotionPlan
    let duration: TimeInterval
    let screenMetrics: ScreenMetrics
    let transitionID: String
    let completionIdentifier: String?
}

private extension IslandPresentationTransitionReason {
    var isAcceptedTrackpadPresentationTransition: Bool {
        switch self {
        case .trackpadSwipedUpToCompact,
             .trackpadSwipedUpToActivity,
             .trackpadSwipedDownToActivity,
             .trackpadSwipedDownToExpandedApp,
             .trackpadSwipedDownToExpandedMusic:
            return true
        default:
            return false
        }
    }
}

private extension IslandPreviewContent.Kind {
    var usesNotchAlignedCompactShell: Bool {
        switch self {
        case .reviewCompact, .todoCompact:
            return true
        case .signedOutCompact,
             .reviewActivity,
             .todoActivity,
             .musicActivity,
             .greetingCompact,
             .reminderActivity,
             .expandedReview,
             .expandedTodo,
             .expandedMusic,
             .gestureLock:
            return false
        }
    }
}

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    var onLoginRequested: (() -> Void)? {
        didSet { renderModel.onLoginRequested = onLoginRequested }
    }
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver
    private let hoverMonitor: IslandHoverMonitor
    private let musicTakeoverController: MusicTakeoverController
    private let screenMetricsResolver: (NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?
    private let previewSizingDiagnosticsEnabled: Bool
    private let interactionDiagnosticsEnabled: Bool
    private let phase5PreviewModeEnabled: Bool
    private let phase5ScenarioMenuEnabled: Bool
    private let legacyPreviewInteractionRoutingRequested: Bool
    private let realMusicProviderEnabled: Bool
    private let renderModel: IslandRenderModel
    private let hostingView: IslandInteractionHostingView
    private let animationDriver: IslandAnimationDriver
    private let animationDisplayLink = IslandAnimationDisplayLink()
    private let pointerFeedbackDisplayLink = IslandAnimationDisplayLink()
    private var phase5PreviewStateContainer: IslandPhase5PreviewStateContainer
    private var activeLayoutInput: IslandPreviewLayoutInput
    private var previewState: IslandVisualState
    private var previewVisualScale: CGFloat = 1
    private var previewHorizontalScale: CGFloat = 1
    private var previewWidthConstraints: IslandWidthConstraints = .none
    private var trackpadCooldownWorkItem: DispatchWorkItem?
    private var presentationLockRecoveryWorkItem: DispatchWorkItem?
    private var presentationLockRecoveryIdentifier: String?
    private var pointerGestureAdapter = IslandPointerGestureAdapter()
    private var pointerFeedbackBaseSizingResult: IslandWindowSizingResult?
    private var pointerFeedbackBaseShapeMetrics: IslandShapeMetrics?
    private var currentPointerStretchFeedback = IslandPointerStretchFeedback.zero
    private var pendingPointerStretchFeedback = IslandPointerStretchFeedback.zero
    private var isPointerFeedbackDisplayLinkRunning = false
    private var lastPointerFeedbackTimestamp: TimeInterval?
    private var modeSwitchHoldAdapter = IslandModeSwitchHoldAdapter()
    private var modeSwitchHoldWorkItem: DispatchWorkItem?
    private var modeSwitchSequenceWorkItems: [DispatchWorkItem] = []
    private var isModeSwitchSequenceActive = false
    private var trackpadWheelAdapter = IslandTrackpadWheelAdapter()
    private var keepsTrackpadHoverFocus = false
    private var musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    private var todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    private var todoToggleScenarioSequence = 0
    private var applicationTerminationObserver: NSObjectProtocol?
    private var accessibilityDisplayOptionsObserver: NSObjectProtocol?
    private var localPointerDownMonitor: Any?
    private var globalPointerDownMonitor: Any?
    private var expandedExitInteractivityWorkItem: DispatchWorkItem?
    private var keepsExpandedExitInteractive = false
    private var lastSizingResult: IslandWindowSizingResult?
    private var currentPresentationSizingResult: IslandWindowSizingResult?
    private var currentPresentationShapeMetrics: IslandShapeMetrics?
    private var currentPresentationShadow = IslandShadowAppearanceTokens(opacity: 0, radius: 0, offsetY: 0)
    private var activeMotion: IslandActiveMotion?
    private var motionSequence = 0
    private var pendingMotionCompletionIdentifier: String?
    private var pendingMotionDurationOverride: TimeInterval?

    private static let visibleContentPresentation = IslandContentPresentation(
        phase: .visible,
        opacity: 1,
        blurRadius: 0,
        scale: 1,
        offsetY: 0,
        allowsHitTesting: true
    )

    private(set) var lastAppliedDisplayIdentity: ScreenMetrics.DisplayIdentity?
    private(set) var lastAppliedFrame: CGRect?
    private(set) var lastAppliedScreenMetrics: ScreenMetrics?

    init(
        panel: IslandPanel = IslandPanel(),
        notchLayoutEngine: NotchLayoutEngine = NotchLayoutEngine(),
        displayObserver: DisplayObserver = DisplayObserver(),
        hoverMonitor: IslandHoverMonitor = IslandHoverMonitor(),
        musicTakeoverController: MusicTakeoverController = MusicTakeoverController(),
        previewSizingDiagnosticsEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_SIZING_DIAGNOSTICS"] == "1",
        interactionDiagnosticsEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_INTERACTION_DIAGNOSTICS"] == "1",
        phase5PreviewModeEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_PHASE5_PREVIEW"] != "0",
        phase5ScenarioMenuEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_PHASE5_SCENARIOS"] == "1",
        legacyPreviewInteractionRoutingRequested: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_LEGACY_PREVIEW_INTERACTIONS"] == "1",
        initialPhase5PreviewState: IslandDomainState = .loggedInReviewCompact,
        screenMetricsResolver: ((NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?)? = nil
    ) {
        var resolvedInitialState = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_INITIAL_SCENARIO"]
            .flatMap(IslandMockScenario.scenario(id:))?
            .initialState ?? initialPhase5PreviewState
        if ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_INITIAL_HOVER"] == "1" {
            resolvedInitialState.isHovered = true
        }
        let phase5PreviewStateContainer = IslandPhase5PreviewStateContainer(
            initialState: resolvedInitialState
        )
        let initialLayoutInput: IslandPreviewLayoutInput
        if phase5PreviewModeEnabled && legacyPreviewInteractionRoutingRequested == false {
            initialLayoutInput = phase5PreviewStateContainer.layoutInput
        } else {
            initialLayoutInput = IslandPreviewLayoutInput(
                visualState: .compactCollapsed,
                widthConstraints: .none
            )
        }

        self.islandPanel = panel
        self.notchLayoutEngine = notchLayoutEngine
        self.displayObserver = displayObserver
        self.hoverMonitor = hoverMonitor
        self.musicTakeoverController = musicTakeoverController
        self.previewSizingDiagnosticsEnabled = previewSizingDiagnosticsEnabled
        self.interactionDiagnosticsEnabled = interactionDiagnosticsEnabled
        self.phase5PreviewModeEnabled = phase5PreviewModeEnabled
        self.phase5ScenarioMenuEnabled = phase5ScenarioMenuEnabled
        self.legacyPreviewInteractionRoutingRequested = legacyPreviewInteractionRoutingRequested
        self.realMusicProviderEnabled = phase5PreviewModeEnabled == false ||
            ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_REAL_MUSIC"] == "1"
        self.phase5PreviewStateContainer = phase5PreviewStateContainer
        self.activeLayoutInput = initialLayoutInput
        self.previewState = initialLayoutInput.visualState
        let renderModel = IslandRenderModel(
            presentation: .initial(
                visualState: initialLayoutInput.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: initialLayoutInput.widthConstraints,
                previewContent: initialLayoutInput.previewContent,
                reduceMotion: false
            )
        )
        self.renderModel = renderModel
        self.animationDriver = IslandAnimationDriver(
            initialMetrics: IslandAnimationMetrics(
                visibleFrame: .zero,
                visualScale: 1
            )
        )
        self.hostingView = IslandInteractionHostingView(
            rootView: IslandRootView(model: renderModel)
        )
        self.screenMetricsResolver = screenMetricsResolver ?? { window, preferredDisplayIdentity in
            displayObserver.preferredScreenMetrics(
                for: window,
                preferredDisplayIdentity: preferredDisplayIdentity
            )
        }
        super.init(window: panel)
        configureMusicTakeover()
        configureInteractionHandlers()
        configureContentView()
        applyInitialWindowState()
        beginDisplayObservation()
        beginApplicationTerminationObservation()
        beginOutsideCollapseObservation()
        beginAccessibilityDisplayOptionsObservation()
    }

    deinit {
        stopObservation()
        if let accessibilityDisplayOptionsObserver {
            NotificationCenter.default.removeObserver(accessibilityDisplayOptionsObserver)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func show() {
        repositionToTopCenter()
        presentPanelIfNeeded()
        beginHoverMonitoring()
        synchronizePanelClickThroughState()
        if realMusicProviderEnabled {
            musicTakeoverController.start()
        }
    }

    func hide() {
        hoverMonitor.stopMonitoring()
        pointerGestureAdapter.cancel()
        resetPointerFeedbackImmediately()
        cancelModeSwitchInteraction()
        trackpadWheelAdapter.reset()
        keepsTrackpadHoverFocus = false
        cancelExpandedExitInteractivity()
        stopActiveMotion(settleAtTarget: false)
        musicTakeoverController.stop()
        window?.orderOut(nil)
    }

    func setShellSizePreset(_ shellSizePreset: IslandShellSizePreset) {
        islandPanel.setShellSizePreset(shellSizePreset)
        repositionToTopCenter()
    }

    var isPanelClickThroughEnabled: Bool {
        islandPanel.isClickThroughEnabled
    }

    func setPanelClickThroughEnabled(_ isEnabled: Bool) {
        islandPanel.setClickThroughEnabled(isEnabled)
    }

    private func configureContentView() {
        hostingView.frame = NSRect(origin: .zero, size: islandPanel.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = false
        islandPanel.contentView = hostingView
    }

    private func configureInteractionHandlers() {
        renderModel.onAdvancePreviewState = usesPhase5PreviewInteractionRouting
            ? nil
            : { [weak self] in self?.advancePreviewState() }
        renderModel.onGreetingLifecycleCompleted = { [weak self] in
            self?.dispatchPhase5Intent(.greetingLifecycleCompleted)
        }
        renderModel.onMusicControlInteraction = { [weak self] in
            self?.hostingView.consumeNextPointerTap()
        }
        renderModel.onTodoTaskInteraction = { [weak self] in
            self?.hostingView.consumeNextPointerTap()
        }
        hostingView.onPointerDown = { [weak self] input in
            self?.handlePointerDown(input)
        }
        hostingView.onPointerDragged = { [weak self] input in
            self?.handlePointerDragged(input)
        }
        hostingView.onPointerUp = { [weak self] input in
            self?.handlePointerUp(input)
        }
        hostingView.onPointerCancelled = { [weak self] pointerID in
            self?.handlePointerCancelled(pointerID: pointerID)
        }
        hostingView.onScrollWheel = { [weak self] event in
            self?.handleScrollWheel(event)
        }
    }

    private func configureMusicTakeover() {
        musicTakeoverController.onUpdate = { [weak self] update in
            guard let self else { return }
            self.handleMusicTakeoverUpdate(update)
        }
    }

    private func applyInitialWindowState() {
        islandPanel.isReleasedWhenClosed = false
        synchronizePanelClickThroughState()
        islandPanel.orderOut(nil)
    }

    private func beginDisplayObservation() {
        displayObserver.startObserving(window: islandPanel) { [weak self] changeSignal in
            self?.handleDisplayChange(changeSignal)
        }
    }

    private func presentPanelIfNeeded() {
        guard let window, window.isVisible == false else { return }
        window.orderFrontRegardless()
    }

    private func beginHoverMonitoring() {
        hoverMonitor.startMonitoring(
            hotspotFrameProvider: { [weak self] in
                self?.hoverHotspotFrameForMonitoring()
            },
            onHoverStart: { [weak self] in
                self?.handleHoverStart()
            },
            onHoverEnd: { [weak self] in
                self?.handleHoverEnd()
            }
        )

        if islandPanel.hoverHotspotFrame.contains(NSEvent.mouseLocation) {
            handleHoverStart()
        } else {
            synchronizePanelClickThroughState()
        }
    }

    private func beginApplicationTerminationObservation() {
        NotificationCenter.default.removeObserverIfNeeded(applicationTerminationObserver)
        applicationTerminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopObservation()
        }
    }

    private func beginOutsideCollapseObservation() {
        localPointerDownMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handleObservedPointerDown(event)
            return event
        }
        globalPointerDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleObservedPointerDown(event)
            }
        }
    }

    private func stopObservation() {
        displayObserver.stopObserving()
        hoverMonitor.stopMonitoring()
        musicTakeoverController.stop()
        trackpadCooldownWorkItem?.cancel()
        trackpadCooldownWorkItem = nil
        NotificationCenter.default.removeObserverIfNeeded(applicationTerminationObserver)
        applicationTerminationObserver = nil
        if let localPointerDownMonitor {
            NSEvent.removeMonitor(localPointerDownMonitor)
            self.localPointerDownMonitor = nil
        }
        if let globalPointerDownMonitor {
            NSEvent.removeMonitor(globalPointerDownMonitor)
            self.globalPointerDownMonitor = nil
        }
        cancelExpandedExitInteractivity()
        stopActiveMotion(settleAtTarget: false)
    }

    private func handleDisplayChange(_ changeSignal: DisplayObserver.ChangeSignal) {
        switch changeSignal {
        case .screenParametersChanged,
             .workspaceDidWake,
             .windowScreenChanged,
             .backingPropertiesChanged:
            repositionToTopCenter()
        }
    }

    private func repositionToTopCenter() {
        guard let screenMetrics = screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else { return }
        let resolvedLayout = resolvePreviewLayout(
            for: activeLayoutInput,
            on: screenMetrics
        )
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics
        )
    }

    private func resolvePreviewLayout(
        for layoutInput: IslandPreviewLayoutInput,
        on screenMetrics: ScreenMetrics
    ) -> (attachmentMetrics: TopAttachmentMetrics, widthConstraints: IslandWidthConstraints, sizingResult: IslandWindowSizingResult) {
        let attachmentMetrics = notchLayoutEngine.topAttachmentMetrics(for: screenMetrics)
        let requestedWidthConstraints = resolvedWidthConstraints(
            for: layoutInput,
            attachmentMetrics: attachmentMetrics
        )
        let sizingResult = IslandWindowSizingEngine.resolve(
            state: layoutInput.visualState,
            attachmentMetrics: attachmentMetrics,
            widthConstraints: requestedWidthConstraints
        )

        return (
            attachmentMetrics: attachmentMetrics,
            widthConstraints: requestedWidthConstraints,
            sizingResult: sizingResult
        )
    }

    private func applyResolvedPreviewLayout(
        _ resolvedLayout: (attachmentMetrics: TopAttachmentMetrics, widthConstraints: IslandWidthConstraints, sizingResult: IslandWindowSizingResult),
        on screenMetrics: ScreenMetrics,
        motionPlan: IslandMotionPlan? = nil
    ) {
        let sizingResult = resolvedLayout.sizingResult
        previewVisualScale = sizingResult.diagnostics.visualScale
        previewHorizontalScale = sizingResult.diagnostics.horizontalScale
        previewWidthConstraints = IslandWidthConstraints(
            baseBodyWidth: sizingResult.diagnostics.requestedBaseBodyWidth,
            maximumVisibleWidth: sizingResult.diagnostics.requestedMaximumVisibleWidth,
            contentWidthRequirement: sizingResult.diagnostics.contentWidthRequirement,
            fixedVisibleWidth: sizingResult.diagnostics.requestedFixedVisibleWidth
        )
        lastSizingResult = sizingResult
        if let motionPlan,
           motionPlan.duration > 0,
           let sourceSizing = currentPresentationSizingResult {
            startActiveMotion(
                from: sourceSizing,
                to: sizingResult,
                on: screenMetrics,
                plan: motionPlan,
                targetLayoutInput: activeLayoutInput
            )
        } else {
            stopActiveMotion(settleAtTarget: false)
            applySizingResult(sizingResult, on: screenMetrics)
            settleRenderPresentation(
                at: activeLayoutInput,
                sizingResult: sizingResult
            )
            scheduleHoverStateReconciliation()
        }
        logSizingDiagnosticsIfNeeded(sizingResult)
    }

    private func applySizingResult(
        _ sizingResult: IslandWindowSizingResult,
        on screenMetrics: ScreenMetrics
    ) {
        let unshiftedPanelFrame = islandPanel.applySizingResult(sizingResult)
        let panelFrame = unshiftedPanelFrame
        islandPanel.setFrame(panelFrame, display: true)
        hostingView.interactiveBounds = sizingResult.hitTestFrame.offsetBy(
            dx: -panelFrame.minX,
            dy: -panelFrame.minY
        )
        lastAppliedDisplayIdentity = screenMetrics.displayIdentity
        lastAppliedFrame = sizingResult.visibleFrame
        lastAppliedScreenMetrics = screenMetrics
        currentPresentationSizingResult = sizingResult
    }

    /// Applies one animation sample while keeping all monitor and hit-test geometry in sync.
    func applyAnimatedSizingSample(
        from source: IslandWindowSizingResult,
        to target: IslandWindowSizingResult,
        progress: CGFloat,
        on screenMetrics: ScreenMetrics
    ) {
        let sample = IslandWindowSizingEngine.resolveAnimatedSample(
            from: source,
            to: target,
            progress: progress,
            attachmentMetrics: resolvedLayoutAttachmentMetrics(for: screenMetrics)
        )
        applySizingResult(sample, on: screenMetrics)
        lastSizingResult = sample
        synchronizePanelClickThroughState()
    }

    private func startActiveMotion(
        from sourceSizing: IslandWindowSizingResult,
        to targetSizing: IslandWindowSizingResult,
        on screenMetrics: ScreenMetrics,
        plan: IslandMotionPlan,
        targetLayoutInput: IslandPreviewLayoutInput
    ) {
        let timestamp = CACurrentMediaTime()
        if animationDriver.isAnimating {
            animationDriver.advance(at: timestamp)
        } else {
            animationDriver.reset(
                to: IslandAnimationMetrics(
                    visibleFrame: sourceSizing.visibleFrame,
                    visualScale: sourceSizing.diagnostics.visualScale
                )
            )
        }
        animationDisplayLink.stop()

        let sourcePresentation = renderModel.presentation
        let unresolvedSourceShape = currentPresentationShapeMetrics ?? shapeSnapshot(
            for: sourcePresentation.visualState,
            visualScale: sourcePresentation.visualScale,
            horizontalScale: sourcePresentation.horizontalScale,
            widthConstraints: sourcePresentation.widthConstraints
        ).metrics
        let sourceShape = IslandShapeEngine.metrics(
            unresolvedSourceShape,
            fittedTo: sourceSizing.visibleSize
        )
        let unresolvedTargetShape = shapeSnapshot(
            for: targetLayoutInput.visualState,
            visualScale: targetSizing.diagnostics.visualScale,
            horizontalScale: targetSizing.diagnostics.horizontalScale,
            widthConstraints: IslandWidthConstraints(
                baseBodyWidth: targetSizing.diagnostics.requestedBaseBodyWidth,
                maximumVisibleWidth: targetSizing.diagnostics.requestedMaximumVisibleWidth,
                contentWidthRequirement: targetSizing.diagnostics.contentWidthRequirement,
                fixedVisibleWidth: targetSizing.diagnostics.requestedFixedVisibleWidth
            )
        ).metrics
        let targetShape = IslandShapeEngine.metrics(
            unresolvedTargetShape,
            fittedTo: targetSizing.visibleSize
        )
        let sourceShadow = currentPresentationShadow
        let targetShadow = IslandVisualTokens.shadow.appearance(
            for: targetLayoutInput.visualState,
            visualScale: targetSizing.diagnostics.visualScale
        )

        motionSequence += 1
        let transitionID = "island-motion-\(motionSequence)"
        let completionIdentifier = pendingMotionCompletionIdentifier
        pendingMotionCompletionIdentifier = nil
        let durationOverride = pendingMotionDurationOverride
        pendingMotionDurationOverride = nil
        let duration = completionIdentifier == "expandedCollapseRecovery"
            ? IslandMotionTokens.expandedActivityRecoveryCollapseDuration
            : durationOverride ?? plan.duration
        activeMotion = IslandActiveMotion(
            generation: motionSequence,
            sourceSizing: sourceSizing,
            targetSizing: targetSizing,
            sourceShapeMetrics: sourceShape,
            targetShapeMetrics: targetShape,
            sourceShadow: sourceShadow,
            targetShadow: targetShadow,
            sourcePresentation: sourcePresentation,
            targetLayoutInput: targetLayoutInput,
            targetVisualScale: targetSizing.diagnostics.visualScale,
            targetHorizontalScale: targetSizing.diagnostics.horizontalScale,
            plan: plan,
            duration: duration,
            screenMetrics: screenMetrics,
            transitionID: transitionID,
            completionIdentifier: completionIdentifier
        )

        animationDriver.animate(
            to: IslandAnimationMetrics(
                visibleFrame: targetSizing.visibleFrame,
                visualScale: targetSizing.diagnostics.visualScale
            ),
            transitionID: transitionID,
            duration: duration,
            curve: plan.shellFrame.keyframes.curve,
            spring: plan.reduceMotion || completionIdentifier == "expandedCollapseRecovery"
                ? nil
                : plan.shellFrame.spring,
            at: timestamp
        )

        advanceActiveMotion(at: timestamp)
        if animationDriver.isAnimating {
            animationDisplayLink.start { [weak self] in
                self?.advanceActiveMotion(at: CACurrentMediaTime())
            }
        }
    }

    private func advanceActiveMotion(at timestamp: TimeInterval) {
        guard let motion = activeMotion else {
            animationDisplayLink.stop()
            return
        }

        animationDriver.advance(at: timestamp)
        let sample = animationDriver.sample
        let normalizedProgress = min(max(sample.progress, 0), 1)
        let presentationProgress = motionProgress(
            normalized: normalizedProgress,
            sample: sample,
            motion: motion
        )
        let sizingResult = IslandWindowSizingEngine.resolveAnimatedSample(
            from: motion.sourceSizing,
            to: motion.targetSizing,
            progress: presentationProgress,
            attachmentMetrics: resolvedLayoutAttachmentMetrics(for: motion.screenMetrics),
            visibleSizeOverride: sample.current.visibleFrame.size
        )
        applySizingResult(sizingResult, on: motion.screenMetrics)

        let interpolatedShapeMetrics = motion.sourceShapeMetrics.interpolated(
            to: motion.targetShapeMetrics,
            progress: presentationProgress
        )
        let shapeMetrics = IslandShapeEngine.metrics(
            interpolatedShapeMetrics,
            fittedTo: sizingResult.visibleSize
        )
        let shadow = motion.sourceShadow.interpolated(
            to: motion.targetShadow,
            progress: presentationProgress
        )
        currentPresentationShapeMetrics = shapeMetrics
        currentPresentationShadow = shadow
        renderModel.presentation = renderPresentation(
            for: motion,
            normalizedProgress: normalizedProgress,
            shapeProgress: presentationProgress,
            shapeMetrics: shapeMetrics,
            shadow: shadow,
            shadowOutsets: sizingResult.shadowOutsets
        )
        synchronizePanelClickThroughState()

        guard sample.hasCompleted else { return }
        animationDisplayLink.stop()
        activeMotion = nil
        applySizingResult(motion.targetSizing, on: motion.screenMetrics)
        settleRenderPresentation(
            at: motion.targetLayoutInput,
            sizingResult: motion.targetSizing
        )
        animationDriver.reset(
            to: IslandAnimationMetrics(
                visibleFrame: motion.targetSizing.visibleFrame,
                visualScale: motion.targetSizing.diagnostics.visualScale
            )
        )
        if let completionIdentifier = motion.completionIdentifier {
            if completionIdentifier == "expandedCollapseRecovery" {
                completeMotionTransition(
                    completionIdentifier,
                    for: motion
                )
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.completeMotionTransition(
                        completionIdentifier,
                        for: motion
                    )
                }
            }
        }
        if activeMotion == nil {
            scheduleHoverStateReconciliation()
        }
    }

    private func completeMotionTransition(
        _ identifier: String,
        for motion: IslandActiveMotion
    ) {
        guard motionSequence == motion.generation,
              activeMotion == nil,
              phase5PreviewStateContainer.domainState.presentationLockState.transitionID == identifier else {
            return
        }
        dispatchPhase5Intent(
            .transitionComplete(identifier),
            using: motion.screenMetrics,
            allowLockScheduling: false
        )
    }

    private func stopActiveMotion(settleAtTarget: Bool) {
        animationDisplayLink.stop()
        guard let motion = activeMotion else { return }
        activeMotion = nil
        if settleAtTarget {
            applySizingResult(motion.targetSizing, on: motion.screenMetrics)
            settleRenderPresentation(at: motion.targetLayoutInput, sizingResult: motion.targetSizing)
        }
        let metrics = currentPresentationSizingResult.map {
            IslandAnimationMetrics(
                visibleFrame: $0.visibleFrame,
                visualScale: $0.diagnostics.visualScale
            )
        } ?? IslandAnimationMetrics(visibleFrame: .zero, visualScale: 1)
        animationDriver.reset(to: metrics)
    }

    private func settleRenderPresentation(
        at layoutInput: IslandPreviewLayoutInput,
        sizingResult: IslandWindowSizingResult
    ) {
        let widthConstraints = IslandWidthConstraints(
            baseBodyWidth: sizingResult.diagnostics.requestedBaseBodyWidth,
            maximumVisibleWidth: sizingResult.diagnostics.requestedMaximumVisibleWidth,
            contentWidthRequirement: sizingResult.diagnostics.contentWidthRequirement,
            fixedVisibleWidth: sizingResult.diagnostics.requestedFixedVisibleWidth
        )
        let unresolvedShape = shapeSnapshot(
            for: layoutInput.visualState,
            visualScale: sizingResult.diagnostics.visualScale,
            horizontalScale: sizingResult.diagnostics.horizontalScale,
            widthConstraints: widthConstraints
        ).metrics
        let shape = IslandShapeEngine.metrics(
            unresolvedShape,
            fittedTo: sizingResult.visibleSize
        )
        let shadow = IslandVisualTokens.shadow.appearance(
            for: layoutInput.visualState,
            visualScale: sizingResult.diagnostics.visualScale
        )
        currentPresentationShapeMetrics = shape
        currentPresentationShadow = shadow
        renderModel.presentation = IslandRenderPresentation(
            visualState: layoutInput.visualState,
            visualScale: sizingResult.diagnostics.visualScale,
            horizontalScale: sizingResult.diagnostics.horizontalScale,
            widthConstraints: widthConstraints,
            previewContent: layoutInput.previewContent,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            todoToggleScenarioRequest: todoToggleScenarioRequest,
            reduceMotion: reduceMotionEnabled,
            shapeMetrics: shape,
            shapeState: layoutInput.visualState,
            shadowAppearance: shadow,
            shadowOutsets: sizingResult.shadowOutsets,
            contentPresentation: Self.visibleContentPresentation
        )
    }

    private func shapeSnapshot(
        for state: IslandVisualState,
        visualScale: CGFloat,
        horizontalScale: CGFloat,
        widthConstraints: IslandWidthConstraints
    ) -> IslandShapeLayoutSnapshot {
        IslandCompactContentLayout.snapshot(
            for: state,
            visualScale: visualScale,
            horizontalScale: horizontalScale,
            widthConstraints: widthConstraints
        )
    }

    private func motionProgress(
        normalized: CGFloat,
        sample: IslandAnimationSample,
        motion: IslandActiveMotion
    ) -> CGFloat {
        let sourceSize = motion.sourceSizing.visibleSize
        let targetSize = motion.targetSizing.visibleSize
        let widthDelta = targetSize.width - sourceSize.width
        let heightDelta = targetSize.height - sourceSize.height
        let fraction: CGFloat
        if abs(widthDelta) >= abs(heightDelta), abs(widthDelta) > 0.001 {
            fraction = (sample.current.visibleFrame.width - sourceSize.width) / widthDelta
        } else if abs(heightDelta) > 0.001 {
            fraction = (sample.current.visibleFrame.height - sourceSize.height) / heightDelta
        } else {
            fraction = normalized
        }
        return min(max(fraction, 0), 1)
    }

    private func renderPresentation(
        for motion: IslandActiveMotion,
        normalizedProgress: CGFloat,
        shapeProgress: CGFloat,
        shapeMetrics: IslandShapeMetrics,
        shadow: IslandShadowAppearanceTokens,
        shadowOutsets: IslandShadowOutsets
    ) -> IslandRenderPresentation {
        let elapsed = TimeInterval(normalizedProgress) * motion.duration
        let exitDuration = motion.plan.content.exit.duration
        let targetWidthConstraints = IslandWidthConstraints(
            baseBodyWidth: motion.targetSizing.diagnostics.requestedBaseBodyWidth,
            maximumVisibleWidth: motion.targetSizing.diagnostics.requestedMaximumVisibleWidth,
            contentWidthRequirement: motion.targetSizing.diagnostics.contentWidthRequirement,
            fixedVisibleWidth: motion.targetSizing.diagnostics.requestedFixedVisibleWidth
        )
        let keepsContentVisible = motion.plan.transitionKind == .hoverEnter ||
            motion.plan.transitionKind == .hoverLeave ||
            motion.plan.transitionKind == .musicContentRetarget

        var visualState = motion.targetLayoutInput.visualState
        var previewContent = motion.targetLayoutInput.previewContent
        var widthConstraints = targetWidthConstraints
        var content = Self.visibleContentPresentation

        if keepsContentVisible == false {
            if elapsed < exitDuration {
                let progress = exitDuration > 0 ? CGFloat(elapsed / exitDuration) : 1
                visualState = motion.sourcePresentation.visualState
                previewContent = motion.sourcePresentation.previewContent
                widthConstraints = motion.sourcePresentation.widthConstraints
                content = interpolateContent(
                    from: motion.sourcePresentation.contentPresentation,
                    to: IslandContentPresentation(
                        phase: .exiting,
                        opacity: 0,
                        blurRadius: motion.plan.content.exit.blurRadius,
                        scale: 0.96,
                        offsetY: -4,
                        allowsHitTesting: false
                    ),
                    progress: progress,
                    phase: .exiting
                )
            } else {
                let enterStart = contentEnterStart(for: motion)
                if elapsed < enterStart {
                    content = .hidden
                } else {
                    let duration = max(motion.plan.content.enter.duration, 0.001)
                    let progress = CGFloat((elapsed - enterStart) / duration)
                    content = interpolateContent(
                        from: .hidden,
                        to: Self.visibleContentPresentation,
                        progress: progress,
                        phase: progress >= 1 ? .visible : .entering
                    )
                }
            }
        }

        return IslandRenderPresentation(
            visualState: visualState,
            visualScale: motion.targetVisualScale,
            horizontalScale: motion.targetHorizontalScale,
            widthConstraints: widthConstraints,
            previewContent: previewContent,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            todoToggleScenarioRequest: todoToggleScenarioRequest,
            reduceMotion: reduceMotionEnabled,
            shapeMetrics: shapeMetrics,
            shapeState: shapeProgress >= 0.5 ? motion.targetLayoutInput.visualState : motion.sourcePresentation.shapeState,
            shadowAppearance: shadow,
            shadowOutsets: shadowOutsets,
            contentPresentation: content
        )
    }

    private func contentEnterStart(for motion: IslandActiveMotion) -> TimeInterval {
        switch motion.plan.transitionKind {
        case .compactToActivity, .compactToExpanded, .reminderOpen, .musicTakeover:
            return motion.plan.content.enter.delay
        case .activityToCompact, .expandedToCompact, .reminderRecover:
            return IslandMotionTokens.activityCollapseCompactContentDelay
        case .activityToExpanded, .expandedToActivity:
            return max(
                motion.duration - motion.plan.content.enter.duration,
                motion.plan.content.exit.duration
            )
        case .modeSwitch:
            return motion.plan.content.enter.delay
        default:
            return motion.plan.content.exit.duration + motion.plan.content.enter.delay
        }
    }

    private func interpolateContent(
        from source: IslandContentPresentation,
        to target: IslandContentPresentation,
        progress: CGFloat,
        phase: IslandContentPhase
    ) -> IslandContentPresentation {
        let t = easeOut(min(max(progress, 0), 1))
        func lerp(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
            start + ((end - start) * t)
        }
        return IslandContentPresentation(
            phase: phase,
            opacity: Double(lerp(CGFloat(source.opacity), CGFloat(target.opacity))),
            blurRadius: lerp(source.blurRadius, target.blurRadius),
            scale: lerp(source.scale, target.scale),
            offsetY: lerp(source.offsetY, target.offsetY),
            allowsHitTesting: phase == .visible
        )
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        return t * t * (3 - (2 * t))
    }

    private func easeOut(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        return 1 - ((1 - t) * (1 - t))
    }

    private func hoverHotspotFrameForMonitoring() -> CGRect? {
        guard islandPanel.isVisible else { return nil }
        // Resizing the panel for elastic feedback re-anchors its live hit frame. Keep
        // hover evaluation on the immutable pointer-down bounds until capture ends so
        // an edge drag cannot oscillate between hover enter and leave.
        if pointerGestureAdapter.isTracking,
           let interactionBounds = pointerGestureAdapter.interactionBounds {
            return interactionBounds
        }
        return islandPanel.hoverHotspotFrame
    }

    private func handleObservedPointerDown(_ event: NSEvent) {
        // Local monitors see clicks delivered to the island before the hosting
        // view's pointer adapter. Treating those as outside clicks produces a
        // collapse followed by an immediate tap expansion from the same event.
        guard event.window !== islandPanel else { return }

        let screenLocation: NSPoint
        if let eventWindow = event.window {
            screenLocation = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            screenLocation = NSEvent.mouseLocation
        }
        if interactionDiagnosticsEnabled {
            print("[IslandInteraction] observedPointerDown location=\(screenLocation) interactiveFrame=\(islandPanel.currentInteractiveFrame) state=\(phase5PreviewStateContainer.derivedState.visualState)")
        }
        guard islandPanel.isVisible,
              phase5PreviewStateContainer.derivedState.visualState.isExpanded,
              islandPanel.currentInteractiveFrame.contains(screenLocation) == false else {
            return
        }
        collapseExpandedForOutsideInteraction()
    }

    private func collapseExpandedForOutsideInteraction() {
        guard usesPhase5PreviewInteractionRouting,
              phase5PreviewStateContainer.derivedState.visualState.isExpanded else {
            return
        }
        dispatchPhase5Intent(.outsideCollapse)
    }

    private func handleHoverStart() {
        guard pointerGestureAdapter.isTracking == false else { return }
        activateInteractiveHoverMode()
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.hoverEnter)
        } else if previewState == .compactCollapsed {
            requestPreviewStateChange(to: .hoverCollapsed)
        }
        NSCursor.arrow.set()
    }

    private func handleHoverEnd() {
        guard pointerGestureAdapter.isTracking == false else { return }
        keepsTrackpadHoverFocus = false
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.hoverLeave)
        } else if previewState == .hoverCollapsed {
            requestPreviewStateChange(to: .compactCollapsed)
        }
        synchronizePanelClickThroughState()
    }

    private func activateInteractiveHoverMode() {
        guard islandPanel.isVisible else { return }
        // Keep hover activation controller-owned so later gesture/state work can extend this path.
        islandPanel.activateInteractiveHoverMode()
    }

    private func recoverClickThroughAfterHoverExit() {
        guard islandPanel.isVisible, islandPanel.isClickThroughEnabled == false else { return }
        guard islandPanel.hoverHotspotFrame.contains(NSEvent.mouseLocation) == false else { return }
        // Keep hover-exit recovery controller-owned so later gesture/state work can share this gate.
        islandPanel.setClickThroughEnabled(true)
    }

    private func updateRootView() {
        var presentation = renderModel.presentation
        presentation.visualState = previewState
        presentation.visualScale = previewVisualScale
        presentation.horizontalScale = previewHorizontalScale
        presentation.widthConstraints = previewWidthConstraints
        presentation.previewContent = activeLayoutInput.previewContent
        presentation.musicTrackSwipeDirection = musicTrackSwipeDirection
        presentation.todoToggleScenarioRequest = todoToggleScenarioRequest
        presentation.reduceMotion = reduceMotionEnabled
        if activeMotion == nil {
            presentation.shapeMetrics = currentPresentationShapeMetrics
            presentation.shapeState = previewState
            presentation.shadowAppearance = currentPresentationShadow
            presentation.shadowOutsets = currentPresentationSizingResult?.shadowOutsets
            presentation.contentPresentation = Self.visibleContentPresentation
        }
        renderModel.presentation = presentation
    }

    private var reduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func beginAccessibilityDisplayOptionsObservation() {
        accessibilityDisplayOptionsObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            self?.updateRootView()
        }
    }

    private var usesPhase5PreviewInteractionRouting: Bool {
        phase5PreviewModeEnabled && legacyPreviewInteractionRoutingRequested == false
    }

    private func widthConstraints(
        for state: IslandVisualState,
        attachmentMetrics: TopAttachmentMetrics
    ) -> IslandWidthConstraints {
        let notchAlignedBodyWidth = attachmentMetrics.notchAlignedBodyWidth(for: state)
        let contentWidthRequirement = notchAlignedBodyWidth == nil
            ? state.previewContentWidthRequirement
            : .none
        let baseBodyWidth = notchAlignedBodyWidth ?? activityNotchClearBodyWidth(
            for: state,
            attachmentMetrics: attachmentMetrics,
            contentWidthRequirement: contentWidthRequirement,
            fallback: IslandVisualTokens.compact.previewWidth * attachmentMetrics.horizontalVisualScale
        )

        return IslandWidthConstraints(
            baseBodyWidth: baseBodyWidth,
            maximumVisibleWidth: attachmentMetrics.availableTopWidth,
            contentWidthRequirement: contentWidthRequirement
        )
    }

    private func resolvedWidthConstraints(
        for layoutInput: IslandPreviewLayoutInput,
        attachmentMetrics: TopAttachmentMetrics
    ) -> IslandWidthConstraints {
        if usesPhase5PreviewInteractionRouting {
            let notchAlignedBodyWidth = notchAlignedCompactBodyWidth(
                for: layoutInput,
                attachmentMetrics: attachmentMetrics
            )
            return IslandWidthConstraints(
                baseBodyWidth: notchAlignedBodyWidth ?? responsiveBaseBodyWidth(
                    for: layoutInput,
                    attachmentMetrics: attachmentMetrics
                ),
                maximumVisibleWidth: layoutInput.widthConstraints.maximumVisibleWidth
                    ?? attachmentMetrics.availableTopWidth,
                contentWidthRequirement: notchAlignedBodyWidth == nil
                    ? layoutInput.widthConstraints.contentWidthRequirement
                    : .none
            )
        }

        return widthConstraints(
            for: layoutInput.visualState,
            attachmentMetrics: attachmentMetrics
        )
    }

    private func notchAlignedCompactBodyWidth(
        for layoutInput: IslandPreviewLayoutInput,
        attachmentMetrics: TopAttachmentMetrics
    ) -> CGFloat? {
        guard layoutInput.previewContent.kind.usesNotchAlignedCompactShell else {
            return nil
        }

        return attachmentMetrics.notchAlignedBodyWidth(for: layoutInput.visualState)
    }

    private func responsiveBaseBodyWidth(
        for layoutInput: IslandPreviewLayoutInput,
        attachmentMetrics: TopAttachmentMetrics
    ) -> CGFloat? {
        let fallback = IslandVisualTokens.activity.previewWidth * attachmentMetrics.horizontalVisualScale
        return activityNotchClearBodyWidth(
            for: layoutInput.visualState,
            attachmentMetrics: attachmentMetrics,
            contentWidthRequirement: layoutInput.widthConstraints.contentWidthRequirement,
            fallback: layoutInput.widthConstraints.baseBodyWidth ?? fallback
        )
    }

    private func activityNotchClearBodyWidth(
        for state: IslandVisualState,
        attachmentMetrics: TopAttachmentMetrics,
        contentWidthRequirement: IslandContentWidthRequirement,
        fallback: CGFloat
    ) -> CGFloat {
        guard state == .activityCollapsed || state == .activityHoverCollapsed else {
            return fallback
        }

        return IslandActivityNotchClearanceLayout.resolve(
            attachmentMetrics: attachmentMetrics,
            contentWidthRequirement: contentWidthRequirement
        ).requiredBodyWidth
    }

    private func advancePreviewState() {
        handleTapInteraction()
    }

    private func requestPreviewStateChange(
        to nextState: IslandVisualState,
        using providedScreenMetrics: ScreenMetrics? = nil
    ) {
        let nextLayoutInput: IslandPreviewLayoutInput
        if let screenMetrics = providedScreenMetrics ?? screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) {
            let attachmentMetrics = resolvedLayoutAttachmentMetrics(for: screenMetrics)
            nextLayoutInput = IslandPreviewLayoutInput(
                visualState: nextState,
                widthConstraints: widthConstraints(
                    for: nextState,
                    attachmentMetrics: attachmentMetrics
                )
            )
        } else {
            nextLayoutInput = IslandPreviewLayoutInput(
                visualState: nextState,
                widthConstraints: previewWidthConstraints
            )
        }

        requestPreviewLayoutChange(
            to: nextLayoutInput,
            using: providedScreenMetrics
        )
    }

    private func requestPreviewLayoutChange(
        to nextLayoutInput: IslandPreviewLayoutInput,
        using providedScreenMetrics: ScreenMetrics? = nil,
        motionTransition: IslandMotionTransitionRequest? = nil
    ) {
        guard let screenMetrics = providedScreenMetrics ?? screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else {
            activeLayoutInput = nextLayoutInput
            previewState = nextLayoutInput.visualState
            previewWidthConstraints = nextLayoutInput.widthConstraints
            updateRootView()
            repositionToTopCenter()
            return
        }

        guard activeLayoutInput != nextLayoutInput else {
            return
        }

        let resolvedLayout = resolvePreviewLayout(
            for: nextLayoutInput,
            on: screenMetrics
        )
        pendingMotionCompletionIdentifier = motionTransition?.completionIdentifier
        pendingMotionDurationOverride = motionTransition?.durationOverride
        let motionPlan = motionTransition.map {
            IslandMotionEngine.plan(
                previous: $0.previous,
                next: $0.next,
                reason: $0.reason,
                presentation: IslandPresentationSnapshot(
                    visualState: renderModel.presentation.shapeState,
                    visibleFrame: currentPresentationSizingResult?.visibleFrame ?? lastAppliedFrame,
                    visualScale: currentPresentationSizingResult?.diagnostics.visualScale ?? previewVisualScale,
                    isAnimating: activeMotion != nil
                ),
                reduceMotion: reduceMotionEnabled,
                currentSizingResult: currentPresentationSizingResult ?? lastSizingResult,
                nextSizingResult: resolvedLayout.sizingResult
            )
        }
        activeLayoutInput = nextLayoutInput
        previewState = nextLayoutInput.visualState
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics,
            motionPlan: motionPlan
        )
    }

    private func handleTapInteraction() {
        if phase5PreviewStateContainer.domainState.authState == .loggedOut {
            onLoginRequested?()
            return
        }
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.tap)
            return
        }

        requestPreviewStateChange(to: previewState.nextPreviewState)
    }

    @MainActor
    func applyAuthenticatedUser(_ user: AuthenticatedUser) {
        var state = phase5PreviewStateContainer.domainState
        state.authState = .loggedIn
        state.primaryMode = .app
        state.presentationState = .collapsed
        state.forceCompactMode = true
        state.isHovered = false
        state.isGreetingActive = true
        state.greetingText = user.nickname?.isEmpty == false ? user.nickname : user.email
        applyPhase5PreviewUpdate(
            phase5PreviewStateContainer.replaceDomainState(state),
            using: nil,
            allowLockScheduling: true
        )
    }

    @MainActor
    func applyLoggedOutState() {
        applyPhase5PreviewUpdate(
            phase5PreviewStateContainer.replaceDomainState(.loggedOutCompact),
            using: nil,
            allowLockScheduling: true
        )
    }

    @MainActor
    func applyReviewSnapshot(_ snapshot: ReviewSnapshot) {
        var state = phase5PreviewStateContainer.domainState
        guard state.authState == .loggedIn else { return }
        state.reviewSnapshot = snapshot
        state.mockSources.review = nil
        applyPhase5PreviewUpdate(
            phase5PreviewStateContainer.replaceDomainState(state),
            using: nil,
            allowLockScheduling: true
        )
    }

    @MainActor
    func applyTodoSnapshot(_ snapshot: TodoSnapshot) {
        var state = phase5PreviewStateContainer.domainState
        guard state.authState == .loggedIn else { return }
        state.todoSnapshot = snapshot
        state.mockSources.todo = nil
        applyPhase5PreviewUpdate(
            phase5PreviewStateContainer.replaceDomainState(state),
            using: nil,
            allowLockScheduling: true
        )
    }

    private func handlePointerDown(_ input: IslandPointerInput) {
        guard usesPhase5PreviewInteractionRouting else { return }
        if pointerGestureAdapter.isTracking {
            _ = pointerGestureAdapter.cancel()
            cancelPendingModeSwitchHold()
            resetPointerFeedbackImmediately()
        }
        activateInteractiveHoverMode()
        let captured = pointerGestureAdapter.pointerDown(
            pointerID: input.identifier,
            at: input.screenLocation,
            interactionBounds: currentPresentationSizingResult?.visibleFrame ?? islandPanel.currentInteractiveFrame,
            isButtonOrigin: input.isButtonOrigin
        )
        if captured {
            pointerFeedbackBaseSizingResult = currentPresentationSizingResult
            pointerFeedbackBaseShapeMetrics = currentPresentationShapeMetrics
        }
        beginModeSwitchHoldIfNeeded(at: input.screenLocation)
        synchronizePanelClickThroughState()
    }

    private func handlePointerDragged(_ input: IslandPointerInput) {
        guard usesPhase5PreviewInteractionRouting else { return }
        pointerGestureAdapter.pointerDragged(pointerID: input.identifier, to: input.screenLocation)
        applyPointerFeedback(pointerGestureAdapter.stretchFeedback)
        if isModeSwitchLeadingIcon(input.screenLocation) == false {
            modeSwitchHoldAdapter.pointerLeftLeadingIcon()
            modeSwitchHoldWorkItem?.cancel()
            modeSwitchHoldWorkItem = nil
        }
    }

    private func handlePointerUp(_ input: IslandPointerInput) {
        guard usesPhase5PreviewInteractionRouting else { return }
        let modeSwitchTriggered = modeSwitchHoldAdapter.hasTriggered
        modeSwitchHoldAdapter.pointerReleased()
        modeSwitchHoldWorkItem?.cancel()
        modeSwitchHoldWorkItem = nil
        if modeSwitchTriggered {
            let interactionBounds = pointerGestureAdapter.interactionBounds
            pointerGestureAdapter.cancel(pointerID: input.identifier)
            animatePointerFeedbackReturn(
                releaseLocation: input.screenLocation,
                interactionBounds: interactionBounds
            )
            synchronizePanelClickThroughState()
            return
        }
        let interactionBounds = pointerGestureAdapter.interactionBounds
        let intent = pointerGestureAdapter.pointerUp(pointerID: input.identifier, at: input.screenLocation)
        stopPointerFeedbackSampling(flushPending: true)
        if let intent {
            clearPointerFeedbackTracking()
            dispatchPhase5Intent(intent)
        } else {
            animatePointerFeedbackReturn(
                releaseLocation: input.screenLocation,
                interactionBounds: interactionBounds
            )
            synchronizePanelClickThroughState()
        }
    }

    private func handlePointerCancelled(pointerID: Int?) {
        guard usesPhase5PreviewInteractionRouting else { return }
        let interactionBounds = pointerGestureAdapter.interactionBounds
        let cancelled = pointerGestureAdapter.cancel(pointerID: pointerID)
        cancelPendingModeSwitchHold()
        if cancelled {
            animatePointerFeedbackReturn(
                releaseLocation: NSEvent.mouseLocation,
                interactionBounds: interactionBounds
            )
        }
        synchronizePanelClickThroughState()
    }

    private func applyPointerFeedback(_ feedback: IslandPointerStretchFeedback) {
        pendingPointerStretchFeedback = feedback
        guard isPointerFeedbackDisplayLinkRunning == false else { return }
        isPointerFeedbackDisplayLinkRunning = true
        lastPointerFeedbackTimestamp = CACurrentMediaTime()
        pointerFeedbackDisplayLink.start { [weak self] in
            self?.advancePointerFeedback(at: CACurrentMediaTime())
        }
    }

    private func advancePointerFeedback(at timestamp: TimeInterval) {
        let elapsed = max(timestamp - (lastPointerFeedbackTimestamp ?? timestamp), 0)
        lastPointerFeedbackTimestamp = timestamp
        let smoothing = 1 - exp(-elapsed / 0.025)
        let nextFeedback = currentPointerStretchFeedback.interpolated(
            to: pendingPointerStretchFeedback,
            progress: smoothing
        )
        renderPointerFeedback(nextFeedback)
    }

    private func renderPointerFeedback(_ feedback: IslandPointerStretchFeedback) {
        guard feedback != currentPointerStretchFeedback else { return }
        guard let baseSizing = pointerFeedbackBaseSizingResult,
              let baseShape = pointerFeedbackBaseShapeMetrics,
              let screenMetrics = lastAppliedScreenMetrics else { return }
        currentPointerStretchFeedback = feedback

        let stretchedSize = CGSize(
            width: baseSizing.visibleSize.width + CGFloat(feedback.horizontalExtensionPerEdge * 2),
            height: baseSizing.visibleSize.height + CGFloat(feedback.downwardExtension)
        )
        let stretchedSizing = IslandWindowSizingEngine.resolveAnimatedSample(
            from: baseSizing,
            to: baseSizing,
            progress: 0,
            attachmentMetrics: resolvedLayoutAttachmentMetrics(for: screenMetrics),
            visibleSizeOverride: stretchedSize
        )
        applySizingResult(stretchedSizing, on: screenMetrics)

        let stretchedShape = IslandShapeEngine.metrics(
            baseShape,
            fittedTo: stretchedSizing.visibleSize
        )
        currentPresentationShapeMetrics = stretchedShape
        var presentation = renderModel.presentation
        presentation.shapeMetrics = stretchedShape
        presentation.shadowOutsets = stretchedSizing.shadowOutsets
        renderModel.presentation = presentation
    }

    private func stopPointerFeedbackSampling(flushPending: Bool) {
        pointerFeedbackDisplayLink.stop()
        isPointerFeedbackDisplayLinkRunning = false
        lastPointerFeedbackTimestamp = nil
        if flushPending {
            renderPointerFeedback(pendingPointerStretchFeedback)
        }
    }

    private func animatePointerFeedbackReturn(
        releaseLocation: CGPoint? = nil,
        interactionBounds: CGRect? = nil
    ) {
        stopPointerFeedbackSampling(flushPending: true)
        let derivedState = phase5PreviewStateContainer.derivedState
        let shouldExitHoverDirectly = (derivedState.visualState == .hoverCollapsed ||
            derivedState.visualState == .activityHoverCollapsed) &&
            phase5PreviewStateContainer.domainState.isHovered &&
            releaseLocation.map {
                IslandPointerGestureAdapter.shouldExitHoverOnRelease(
                    at: $0,
                    interactionBounds: interactionBounds
                )
            } == true
        if shouldExitHoverDirectly {
            clearPointerFeedbackTracking()
            dispatchPhase5Intent(.hoverLeave)
            return
        }

        guard let baseSizing = pointerFeedbackBaseSizingResult,
              let currentSizing = currentPresentationSizingResult,
              let screenMetrics = lastAppliedScreenMetrics else {
            clearPointerFeedbackTracking()
            return
        }
        clearPointerFeedbackTracking()

        let plan = IslandMotionEngine.plan(
            previous: derivedState,
            next: derivedState,
            reason: .noChange,
            presentation: IslandPresentationSnapshot(
                visualState: renderModel.presentation.shapeState,
                visibleFrame: currentSizing.visibleFrame,
                visualScale: currentSizing.diagnostics.visualScale,
                isAnimating: false
            ),
            reduceMotion: reduceMotionEnabled,
            currentSizingResult: currentSizing,
            nextSizingResult: baseSizing
        )
        startActiveMotion(
            from: currentSizing,
            to: baseSizing,
            on: screenMetrics,
            plan: plan,
            targetLayoutInput: activeLayoutInput
        )
    }

    private func clearPointerFeedbackTracking() {
        pointerFeedbackBaseSizingResult = nil
        pointerFeedbackBaseShapeMetrics = nil
        currentPointerStretchFeedback = .zero
        pendingPointerStretchFeedback = .zero
    }

    private func resetPointerFeedbackImmediately() {
        stopPointerFeedbackSampling(flushPending: false)
        let baseSizing = pointerFeedbackBaseSizingResult
        let baseShape = pointerFeedbackBaseShapeMetrics
        clearPointerFeedbackTracking()

        if let baseSizing,
           let screenMetrics = lastAppliedScreenMetrics {
            applySizingResult(baseSizing, on: screenMetrics)
        }
        if let baseSizing, let baseShape {
            currentPresentationShapeMetrics = baseShape
            var presentation = renderModel.presentation
            presentation.shapeMetrics = baseShape
            presentation.shadowOutsets = baseSizing.shadowOutsets
            renderModel.presentation = presentation
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard usesPhase5PreviewInteractionRouting else { return }
        guard let intent = trackpadWheelAdapter.registerEvent(
            deltaX: Double(event.scrollingDeltaX),
            deltaY: Double(event.scrollingDeltaY),
            timestamp: event.timestamp
        ) else {
            return
        }

        let update = dispatchPhase5Intent(intent)
        if case .trackpadSwipe(.up) = intent,
           update?.previousState.presentationState == .expanded,
           update?.reducerResult.reason.isAcceptedTrackpadPresentationTransition == true {
            keepsTrackpadHoverFocus = true
            activateInteractiveHoverMode()
            synchronizePanelClickThroughState()
        }
    }

    @discardableResult
    private func dispatchPhase5Intent(
        _ intent: IslandInteractionIntent,
        using providedScreenMetrics: ScreenMetrics? = nil,
        allowLockScheduling: Bool = true
    ) -> IslandPhase5PreviewReducerUpdate? {
        guard usesPhase5PreviewInteractionRouting else { return nil }
        if interactionDiagnosticsEnabled {
            print("[IslandInteraction] intent=\(String(describing: intent)) before=\(phase5PreviewStateContainer.derivedState.visualState)")
        }
        var update = phase5PreviewStateContainer.dispatch(intent: intent)
        if interactionDiagnosticsEnabled {
            print("[IslandInteraction] reason=\(update.reducerResult.reason.rawValue) after=\(update.currentDerivedState.visualState)")
        }
        if case let .horizontalMusicCommand(command) = intent,
           update.reducerResult.reason != .intentIgnored {
            phase5PreviewStateContainer.advanceMockMusicTrack(command)
            musicTrackSwipeDirection = IslandMusicTrackSwipeDirection(command)
            // The reducer validates the command first. Re-derive after the
            // mock track changes so title-width changes receive the same
            // top-anchored sizing interpolation as every other transition.
            update = IslandPhase5PreviewReducerUpdate(
                previousState: update.previousState,
                currentState: phase5PreviewStateContainer.domainState,
                previousDerivedState: update.previousDerivedState,
                currentDerivedState: phase5PreviewStateContainer.derivedState,
                reducerResult: update.reducerResult
            )
        }
        let didStateChange = update.previousState != update.currentState
        let didLayoutChange = update.previousLayoutInput != update.currentLayoutInput
        guard didStateChange || didLayoutChange else {
            synchronizePanelClickThroughState()
            return update
        }
        applyPhase5PreviewUpdate(
            update,
            using: providedScreenMetrics,
            allowLockScheduling: allowLockScheduling
        )
        if case .horizontalMusicCommand = intent,
           update.reducerResult.reason != .intentIgnored {
            requestPreviewLayoutChange(
                to: phase5PreviewStateContainer.layoutInput,
                using: providedScreenMetrics
            )
        }
        return update
    }

    private func beginModeSwitchHoldIfNeeded(at screenPoint: CGPoint) {
        guard isModeSwitchSequenceActive == false else { return }
        modeSwitchHoldAdapter.pointerDown(
            onLeadingIcon: isModeSwitchLeadingIcon(screenPoint),
            at: ProcessInfo.processInfo.systemUptime
        )
        guard modeSwitchHoldAdapter.isHolding else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.modeSwitchHoldAdapter.triggerIfEligible(at: ProcessInfo.processInfo.systemUptime) else { return }
            self.pointerGestureAdapter.cancel()
            self.stopPointerFeedbackSampling(flushPending: true)
            self.clearPointerFeedbackTracking()
            self.startModeSwitchSequence()
        }
        modeSwitchHoldWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + IslandInteractionThresholds.modeSwitchLongPressWindow,
            execute: workItem
        )
    }

    private func startModeSwitchSequence() {
        guard isModeSwitchSequenceActive == false else { return }
        let state = phase5PreviewStateContainer.domainState
        guard state.primaryMode == .app,
              state.authState == .loggedIn,
              state.presentationState == .activity,
              state.forceCompactMode == false else {
            modeSwitchHoldAdapter.cancel()
            return
        }

        isModeSwitchSequenceActive = true
        dispatchPhase5Intent(.retargetPresentation(.init(
            presentationState: .activity,
            forceCompactMode: true,
            isHovered: false
        )))
        scheduleModeSwitchStep(after: IslandInteractionThresholds.modeSwitchCompactPhaseWindow) { [weak self] in
            self?.dispatchPhase5Intent(.modeSwitchMutate)
        }
        scheduleModeSwitchStep(
            after: IslandInteractionThresholds.modeSwitchCompactPhaseWindow + IslandInteractionThresholds.modeSwitchReopenDelay
        ) { [weak self] in
            guard let self else { return }
            self.dispatchPhase5Intent(.retargetPresentation(.init(
                presentationState: .activity,
                forceCompactMode: false,
                isHovered: false
            )))
        }
        scheduleModeSwitchStep(
            after: IslandInteractionThresholds.modeSwitchCompactPhaseWindow +
                IslandInteractionThresholds.modeSwitchReopenDelay + IslandMotionTokens.activityOpenDuration
        ) { [weak self] in
            guard let self else { return }
            self.dispatchPhase5Intent(.transitionComplete(IslandTransitionLockIdentifier.modeSwitchLock))
            self.finishModeSwitchSequence()
        }
    }

    private func scheduleModeSwitchStep(after delay: TimeInterval, _ action: @escaping () -> Void) {
        let workItem = DispatchWorkItem(block: action)
        modeSwitchSequenceWorkItems.append(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func finishModeSwitchSequence() {
        modeSwitchSequenceWorkItems.removeAll()
        isModeSwitchSequenceActive = false
        modeSwitchHoldAdapter.cancel()
        synchronizePanelClickThroughState()
    }

    private func cancelModeSwitchInteraction() {
        modeSwitchHoldWorkItem?.cancel()
        modeSwitchHoldWorkItem = nil
        modeSwitchSequenceWorkItems.forEach { $0.cancel() }
        modeSwitchSequenceWorkItems.removeAll()
        isModeSwitchSequenceActive = false
        modeSwitchHoldAdapter.cancel()
    }

    private func cancelPendingModeSwitchHold() {
        guard isModeSwitchSequenceActive == false else { return }
        modeSwitchHoldWorkItem?.cancel()
        modeSwitchHoldWorkItem = nil
        modeSwitchHoldAdapter.cancel()
    }

    private func isModeSwitchLeadingIcon(_ screenPoint: CGPoint) -> Bool {
        guard phase5PreviewStateContainer.derivedState.isActivityVisualState else { return false }
        let visibleFrame = pointerGestureAdapter.interactionBounds ??
            currentPresentationSizingResult?.visibleFrame
        return IslandActivityLeadingIconHitRegion.contains(
            screenPoint,
            in: visibleFrame
        )
    }

    private func handleMusicTakeoverUpdate(_ update: MusicTakeoverUpdate) {
        guard usesPhase5PreviewInteractionRouting else { return }
        dispatchPhase5Intent(
            update.intent,
            using: lastAppliedScreenMetrics,
            allowLockScheduling: true
        )
    }

    private func applyPhase5PreviewUpdate(
        _ update: IslandPhase5PreviewReducerUpdate,
        using providedScreenMetrics: ScreenMetrics?,
        allowLockScheduling: Bool
    ) {
        updateExpandedExitInteractivity(
            from: update.previousDerivedState,
            to: update.currentDerivedState
        )
        let didPresentationChange = update.previousLayoutInput != update.currentLayoutInput
        let transitionID = update.currentState.presentationLockState.transitionID
        let introducedTransitionID = transitionID != nil &&
            update.previousState.presentationLockState.transitionID != transitionID
        let completionIdentifier: String?
        switch transitionID {
        case IslandTransitionLockIdentifier.forceCompactTransition,
             "expandedCollapseRecovery":
            // A hover or pointer retarget can replace the animation that originally
            // owned this lock. Carry the completion forward to the latest motion.
            completionIdentifier = transitionID
        default:
            completionIdentifier = nil
        }
        let isExpandedActivityRecoveryOpening =
            update.previousState.presentationLockState.transitionID == "expandedCollapseRecovery" &&
            update.currentState.presentationLockState.transitionID == nil &&
            update.currentDerivedState.isActivityVisualState
        let motionTransition = didPresentationChange
            ? IslandMotionTransitionRequest(
                previous: update.previousDerivedState,
                next: update.currentDerivedState,
                reason: update.reducerResult.reason,
                completionIdentifier: completionIdentifier,
                durationOverride: isExpandedActivityRecoveryOpening
                    ? IslandMotionTokens.expandedActivityRecoveryOpenDuration
                    : nil
            )
            : nil
        requestPreviewLayoutChange(
            to: update.currentLayoutInput,
            using: providedScreenMetrics,
            motionTransition: motionTransition
        )
        synchronizePanelClickThroughState()

        if presentationLockRecoveryIdentifier != nil,
           presentationLockRecoveryIdentifier != transitionID {
            cancelPresentationLockRecovery()
        }
        if let transitionID,
           introducedTransitionID,
           (transitionID == IslandTransitionLockIdentifier.forceCompactTransition ||
               transitionID == "expandedCollapseRecovery") {
            schedulePresentationLockRecovery(for: transitionID)
        }

        guard allowLockScheduling else { return }

        if update.currentState.isTrackpadGestureLocked,
           update.previousState.isTrackpadGestureLocked == false {
            scheduleTrackpadCooldownRelease()
        }
    }

    private func schedulePresentationLockRecovery(for identifier: String) {
        guard presentationLockRecoveryIdentifier != identifier else { return }
        cancelPresentationLockRecovery()
        presentationLockRecoveryIdentifier = identifier
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.presentationLockRecoveryIdentifier = nil
            self.presentationLockRecoveryWorkItem = nil
            guard self.phase5PreviewStateContainer.domainState.presentationLockState.transitionID == identifier else {
                return
            }
            self.dispatchPhase5Intent(
                .transitionComplete(identifier),
                using: self.lastAppliedScreenMetrics,
                allowLockScheduling: false
            )
        }
        presentationLockRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: workItem)
    }

    private func cancelPresentationLockRecovery() {
        presentationLockRecoveryWorkItem?.cancel()
        presentationLockRecoveryWorkItem = nil
        presentationLockRecoveryIdentifier = nil
    }

    private func scheduleTrackpadCooldownRelease() {
        trackpadCooldownWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.trackpadWheelAdapter.clearCooldown()
            self.dispatchPhase5Intent(
                .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown),
                using: self.lastAppliedScreenMetrics,
                allowLockScheduling: false
            )
            self.trackpadCooldownWorkItem = nil
        }
        trackpadCooldownWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + IslandInteractionThresholds.trackpadGestureCooldownWindow,
            execute: workItem
        )
    }

    private func synchronizePanelClickThroughState() {
        guard usesPhase5PreviewInteractionRouting else {
            recoverClickThroughAfterHoverExit()
            return
        }

        let derivedState = phase5PreviewStateContainer.derivedState
        let isPointerInsideInteractiveFrame = islandPanel.currentInteractiveFrame.contains(NSEvent.mouseLocation)
        let shouldKeepInteractiveRouting = derivedState.visualState.isExpanded ||
            keepsExpandedExitInteractive ||
            phase5PreviewStateContainer.domainState.isHovered ||
            pointerGestureAdapter.isTracking ||
            keepsTrackpadHoverFocus ||
            isPointerInsideInteractiveFrame
        islandPanel.setClickThroughEnabled(shouldKeepInteractiveRouting == false)
    }

    private func scheduleHoverStateReconciliation() {
        DispatchQueue.main.async { [weak self] in
            self?.reconcileHoverStateIfNeeded()
        }
    }

    private func reconcileHoverStateIfNeeded() {
        guard usesPhase5PreviewInteractionRouting,
              islandPanel.isVisible,
              activeMotion == nil else {
            return
        }

        let derivedState = phase5PreviewStateContainer.derivedState
        guard derivedState.visualState == .compactCollapsed ||
                derivedState.visualState == .hoverCollapsed ||
                derivedState.visualState == .activityCollapsed ||
                derivedState.visualState == .activityHoverCollapsed else {
            synchronizePanelClickThroughState()
            return
        }

        hoverMonitor.reconcileHoverState(
            expectedInside: phase5PreviewStateContainer.domainState.isHovered
        )
        synchronizePanelClickThroughState()
    }

    private func updateExpandedExitInteractivity(
        from previous: IslandDerivedState,
        to next: IslandDerivedState
    ) {
        expandedExitInteractivityWorkItem?.cancel()
        expandedExitInteractivityWorkItem = nil

        guard previous.visualState.isExpanded, next.visualState.isExpanded == false else {
            keepsExpandedExitInteractive = false
            return
        }

        keepsExpandedExitInteractive = true
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.keepsExpandedExitInteractive = false
            self.expandedExitInteractivityWorkItem = nil
            self.synchronizePanelClickThroughState()
        }
        expandedExitInteractivityWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + IslandVisualTokens.expandedContentExit.exitDuration,
            execute: workItem
        )
    }

    private func cancelExpandedExitInteractivity() {
        expandedExitInteractivityWorkItem?.cancel()
        expandedExitInteractivityWorkItem = nil
        keepsExpandedExitInteractive = false
    }

    private func resolvedLayoutAttachmentMetrics(for screenMetrics: ScreenMetrics) -> TopAttachmentMetrics {
        notchLayoutEngine.topAttachmentMetrics(for: screenMetrics)
    }

    private func logSizingDiagnosticsIfNeeded(_ sizingResult: IslandWindowSizingResult) {
        guard previewSizingDiagnosticsEnabled else { return }
        print("[IslandSizing] \(sizingResult.debugSummary)")
    }

}

extension IslandWindowController: IslandPhase5ScenarioControlling {
    var availablePhase5Scenarios: [IslandMockScenario] {
        guard usesPhase5PreviewInteractionRouting, phase5ScenarioMenuEnabled else {
            return []
        }

        return IslandMockScenario.phase5Catalog
    }

    func selectPhase5Scenario(id: String) {
        guard usesPhase5PreviewInteractionRouting else {
            return
        }

        cancelModeSwitchInteraction()
        dispatchPhase5Intent(.mockScenarioSelect(id))
    }
}

extension IslandWindowController: IslandPhase5InteractionDemoControlling {
    var availablePhase5InteractionDemoControls: [IslandPhase5InteractionDemoControl] {
        guard usesPhase5PreviewInteractionRouting else { return [] }
        return IslandPhase5InteractionDemoControl.allCases
    }

    func triggerPhase5InteractionDemo(_ control: IslandPhase5InteractionDemoControl) {
        guard usesPhase5PreviewInteractionRouting else {
            return
        }

        switch control {
        case .todoToggleSimulateSuccess:
            queueTodoToggleScenario(outcome: .success)
            return
        case .todoToggleSimulateRollback:
            queueTodoToggleScenario(outcome: .rollback)
            return
        default:
            break
        }

        if control == .hoverEnter {
            activateInteractiveHoverMode()
        }

        dispatchPhase5Intent(control.intent)
    }

    private func queueTodoToggleScenario(outcome: IslandTodoToggleScenarioOutcome) {
        todoToggleScenarioSequence += 1
        todoToggleScenarioRequest = IslandTodoToggleScenarioRequest(
            sequence: todoToggleScenarioSequence,
            outcome: outcome
        )
        updateRootView()
    }
}

private extension NotificationCenter {
    func removeObserverIfNeeded(_ observer: NSObjectProtocol?) {
        guard let observer else { return }
        removeObserver(observer)
    }
}
