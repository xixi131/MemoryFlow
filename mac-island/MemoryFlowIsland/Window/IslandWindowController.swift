import AppKit
import SwiftUI

protocol IslandPhase5ScenarioControlling: AnyObject {
    var availablePhase5Scenarios: [IslandMockScenario] { get }
    func selectPhase5Scenario(id: String)
}

protocol IslandPhase5InteractionDemoControlling: AnyObject {
    var availablePhase5InteractionDemoControls: [IslandPhase5InteractionDemoControl] { get }
    func triggerPhase5InteractionDemo(_ control: IslandPhase5InteractionDemoControl)
}

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver
    private let hoverMonitor: IslandHoverMonitor
    private let musicTakeoverController: MusicTakeoverController
    private let screenMetricsResolver: (NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?
    private let previewSizingDiagnosticsEnabled: Bool
    private let phase5PreviewModeEnabled: Bool
    private let phase5ScenarioMenuEnabled: Bool
    private let legacyPreviewInteractionRoutingRequested: Bool
    private let hostingView: IslandInteractionHostingView
    private var phase5PreviewStateContainer: IslandPhase5PreviewStateContainer
    private var activeLayoutInput: IslandPreviewLayoutInput
    private var previewState: IslandVisualState
    private var previewVisualScale: CGFloat = 1
    private var previewHorizontalScale: CGFloat = 1
    private var previewWidthConstraints: IslandWidthConstraints = .none
    private var trackpadCooldownWorkItem: DispatchWorkItem?
    private var pointerGestureAdapter = IslandPointerGestureAdapter()
    private var pointerFeedbackTranslationX: CGFloat = 0
    private var modeSwitchHoldAdapter = IslandModeSwitchHoldAdapter()
    private var modeSwitchHoldWorkItem: DispatchWorkItem?
    private var modeSwitchSequenceWorkItems: [DispatchWorkItem] = []
    private var isModeSwitchSequenceActive = false
    private var trackpadWheelAdapter = IslandTrackpadWheelAdapter()
    private var shouldAnimateGreetingShellCollapse = false
    private var musicTrackSwipeDirection: IslandMusicTrackSwipeDirection?
    private var todoToggleScenarioRequest: IslandTodoToggleScenarioRequest?
    private var todoToggleScenarioSequence = 0
    private var applicationTerminationObserver: NSObjectProtocol?
    private var lastSizingResult: IslandWindowSizingResult?

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
        phase5PreviewModeEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_PHASE5_PREVIEW"] != "0",
        phase5ScenarioMenuEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_PHASE5_SCENARIOS"] == "1",
        legacyPreviewInteractionRoutingRequested: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_LEGACY_PREVIEW_INTERACTIONS"] == "1",
        initialPhase5PreviewState: IslandDomainState = .loggedInReviewCompact,
        screenMetricsResolver: ((NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?)? = nil
    ) {
        let phase5PreviewStateContainer = IslandPhase5PreviewStateContainer(
            initialState: initialPhase5PreviewState
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
        self.phase5PreviewModeEnabled = phase5PreviewModeEnabled
        self.phase5ScenarioMenuEnabled = phase5ScenarioMenuEnabled
        self.legacyPreviewInteractionRoutingRequested = legacyPreviewInteractionRoutingRequested
        self.phase5PreviewStateContainer = phase5PreviewStateContainer
        self.activeLayoutInput = initialLayoutInput
        self.previewState = initialLayoutInput.visualState
        self.hostingView = IslandInteractionHostingView(
            rootView: IslandRootView(
                previewState: initialLayoutInput.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: initialLayoutInput.widthConstraints,
                previewContent: initialLayoutInput.previewContent,
                musicTrackSwipeDirection: nil,
                todoToggleScenarioRequest: nil,
                onAdvancePreviewState: nil,
                onGreetingLifecycleCompleted: nil,
                onMusicControlInteraction: nil,
                onTodoTaskInteraction: nil
            )
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
        updateRootView()
        configureContentView()
        applyInitialWindowState()
        beginDisplayObservation()
        beginApplicationTerminationObservation()
    }

    deinit {
        stopObservation()
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
        musicTakeoverController.start()
    }

    func hide() {
        hoverMonitor.stopMonitoring()
        pointerGestureAdapter.cancel()
        resetPointerFeedbackImmediately()
        cancelModeSwitchInteraction()
        trackpadWheelAdapter.reset()
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
        displayObserver.startObserving { [weak self] changeSignal in
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

    private func stopObservation() {
        displayObserver.stopObserving()
        hoverMonitor.stopMonitoring()
        musicTakeoverController.stop()
        trackpadCooldownWorkItem?.cancel()
        trackpadCooldownWorkItem = nil
        NotificationCenter.default.removeObserverIfNeeded(applicationTerminationObserver)
        applicationTerminationObserver = nil
    }

    private func handleDisplayChange(_ changeSignal: DisplayObserver.ChangeSignal) {
        switch changeSignal {
        case .screenParametersChanged, .workspaceDidWake:
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
        on screenMetrics: ScreenMetrics
    ) {
        let sizingResult = resolvedLayout.sizingResult
        previewVisualScale = sizingResult.diagnostics.visualScale
        previewHorizontalScale = sizingResult.diagnostics.horizontalScale
        previewWidthConstraints = IslandWidthConstraints(
            baseBodyWidth: sizingResult.diagnostics.requestedBaseBodyWidth,
            maximumVisibleWidth: sizingResult.diagnostics.requestedMaximumVisibleWidth,
            contentWidthRequirement: sizingResult.diagnostics.contentWidthRequirement
        )
        islandPanel.setRequestedShellLayout(
            visibleShellSize: NSSize(width: sizingResult.visibleSize.width, height: sizingResult.visibleSize.height),
            shadowOutsets: sizingResult.shadowOutsets
        )
        updateRootView()
        applySizingResult(sizingResult, on: screenMetrics)
        lastSizingResult = sizingResult
        logSizingDiagnosticsIfNeeded(sizingResult)
    }

    private func applySizingResult(
        _ sizingResult: IslandWindowSizingResult,
        on screenMetrics: ScreenMetrics
    ) {
        let unshiftedPanelFrame = islandPanel.applySizingResult(sizingResult)
        let panelFrame = unshiftedPanelFrame.offsetBy(dx: pointerFeedbackTranslationX, dy: 0)
        if shouldAnimateGreetingShellCollapse {
            shouldAnimateGreetingShellCollapse = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = IslandGreetingSequence.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                islandPanel.animator().setFrame(panelFrame, display: true)
            }
        } else {
            islandPanel.setFrame(panelFrame, display: true)
        }
        hostingView.interactiveBounds = sizingResult.hitTestFrame.offsetBy(
            dx: -panelFrame.minX,
            dy: -panelFrame.minY
        )
        lastAppliedDisplayIdentity = screenMetrics.displayIdentity
        lastAppliedFrame = sizingResult.visibleFrame
        lastAppliedScreenMetrics = screenMetrics
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

    private func hoverHotspotFrameForMonitoring() -> CGRect? {
        guard islandPanel.isVisible else { return nil }
        return islandPanel.hoverHotspotFrame
    }

    private func handleHoverStart() {
        activateInteractiveHoverMode()
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.hoverEnter)
        } else if previewState == .compactCollapsed {
            requestPreviewStateChange(to: .hoverCollapsed)
        }
        NSCursor.arrow.set()
    }

    private func handleHoverEnd() {
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
        hostingView.rootView = IslandRootView(
            previewState: previewState,
            visualScale: previewVisualScale,
            horizontalScale: previewHorizontalScale,
            widthConstraints: previewWidthConstraints,
            previewContent: activeLayoutInput.previewContent,
            musicTrackSwipeDirection: musicTrackSwipeDirection,
            todoToggleScenarioRequest: todoToggleScenarioRequest,
            onAdvancePreviewState: usesPhase5PreviewInteractionRouting ? nil : { [weak self] in
                self?.advancePreviewState()
            },
            onGreetingLifecycleCompleted: usesPhase5PreviewInteractionRouting ? { [weak self] in
                self?.shouldAnimateGreetingShellCollapse = true
                self?.dispatchPhase5Intent(.greetingLifecycleCompleted)
            } : nil,
            onMusicControlInteraction: { [weak self] in
                self?.hostingView.consumeNextPointerTap()
            },
            onTodoTaskInteraction: { [weak self] in
                self?.hostingView.consumeNextPointerTap()
            }
        )
    }

    private var usesPhase5PreviewInteractionRouting: Bool {
        phase5PreviewModeEnabled && legacyPreviewInteractionRoutingRequested == false
    }

    private func widthConstraints(
        for state: IslandVisualState,
        attachmentMetrics: TopAttachmentMetrics
    ) -> IslandWidthConstraints {
        let baseBodyWidth = IslandVisualTokens.compact.previewWidth *
            attachmentMetrics.horizontalVisualScale

        return IslandWidthConstraints(
            baseBodyWidth: baseBodyWidth,
            maximumVisibleWidth: attachmentMetrics.availableTopWidth,
            contentWidthRequirement: state.previewContentWidthRequirement
        )
    }

    private func resolvedWidthConstraints(
        for layoutInput: IslandPreviewLayoutInput,
        attachmentMetrics: TopAttachmentMetrics
    ) -> IslandWidthConstraints {
        if usesPhase5PreviewInteractionRouting {
            return IslandWidthConstraints(
                baseBodyWidth: layoutInput.widthConstraints.baseBodyWidth,
                maximumVisibleWidth: layoutInput.widthConstraints.maximumVisibleWidth
                    ?? attachmentMetrics.availableTopWidth,
                contentWidthRequirement: layoutInput.widthConstraints.contentWidthRequirement
            )
        }

        return widthConstraints(
            for: layoutInput.visualState,
            attachmentMetrics: attachmentMetrics
        )
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
        using providedScreenMetrics: ScreenMetrics? = nil
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
        activeLayoutInput = nextLayoutInput
        previewState = nextLayoutInput.visualState
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics
        )
    }

    private func handleTapInteraction() {
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.tap)
            return
        }

        requestPreviewStateChange(to: previewState.nextPreviewState)
    }

    private func handlePointerDown(_ input: IslandPointerInput) {
        guard usesPhase5PreviewInteractionRouting else { return }
        activateInteractiveHoverMode()
        _ = pointerGestureAdapter.pointerDown(
            pointerID: input.identifier,
            at: Double(input.location.x),
            isButtonOrigin: input.isButtonOrigin
        )
        beginModeSwitchHoldIfNeeded(at: input.location)
        synchronizePanelClickThroughState()
    }

    private func handlePointerDragged(_ input: IslandPointerInput) {
        guard usesPhase5PreviewInteractionRouting else { return }
        pointerGestureAdapter.pointerDragged(pointerID: input.identifier, to: Double(input.location.x))
        applyPointerFeedback(pointerGestureAdapter.interactiveTranslationX)
        if isModeSwitchLeadingIcon(input.location) == false {
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
            pointerGestureAdapter.cancel(pointerID: input.identifier)
            springPointerFeedbackBack()
            synchronizePanelClickThroughState()
            return
        }
        let intent = pointerGestureAdapter.pointerUp(pointerID: input.identifier, at: Double(input.location.x))
        springPointerFeedbackBack()
        if let intent {
            dispatchPhase5Intent(intent)
        } else {
            synchronizePanelClickThroughState()
        }
    }

    private func handlePointerCancelled(pointerID: Int?) {
        guard usesPhase5PreviewInteractionRouting else { return }
        let cancelled = pointerGestureAdapter.cancel(pointerID: pointerID)
        cancelPendingModeSwitchHold()
        if cancelled {
            springPointerFeedbackBack()
        }
        synchronizePanelClickThroughState()
    }

    private func applyPointerFeedback(_ translationX: Double) {
        let nextTranslation = CGFloat(translationX)
        guard pointerFeedbackTranslationX != nextTranslation else { return }
        let delta = nextTranslation - pointerFeedbackTranslationX
        pointerFeedbackTranslationX = nextTranslation
        islandPanel.setFrame(islandPanel.frame.offsetBy(dx: delta, dy: 0), display: true)
    }

    private func springPointerFeedbackBack() {
        guard pointerFeedbackTranslationX != 0 else { return }
        let targetFrame = islandPanel.frame.offsetBy(dx: -pointerFeedbackTranslationX, dy: 0)
        pointerFeedbackTranslationX = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.88, 0.32, 1.22)
            islandPanel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func resetPointerFeedbackImmediately() {
        guard pointerFeedbackTranslationX != 0 else { return }
        islandPanel.setFrame(
            islandPanel.frame.offsetBy(dx: -pointerFeedbackTranslationX, dy: 0),
            display: false
        )
        pointerFeedbackTranslationX = 0
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

        dispatchPhase5Intent(intent)
    }

    private func dispatchPhase5Intent(
        _ intent: IslandInteractionIntent,
        using providedScreenMetrics: ScreenMetrics? = nil,
        allowLockScheduling: Bool = true
    ) {
        guard usesPhase5PreviewInteractionRouting else { return }
        let update = phase5PreviewStateContainer.dispatch(intent: intent)
        if case let .horizontalMusicCommand(command) = intent,
           update.reducerResult.reason != .intentIgnored {
            phase5PreviewStateContainer.advanceMockMusicTrack(command)
            musicTrackSwipeDirection = IslandMusicTrackSwipeDirection(command)
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
        if update.reducerResult.state.presentationLockState.transitionID == "expandedCollapseRecovery" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
                self?.dispatchPhase5Intent(.transitionComplete("expandedCollapseRecovery"))
            }
        }
    }

    private func beginModeSwitchHoldIfNeeded(at point: CGPoint) {
        guard isModeSwitchSequenceActive == false else { return }
        modeSwitchHoldAdapter.pointerDown(
            onLeadingIcon: isModeSwitchLeadingIcon(point),
            at: ProcessInfo.processInfo.systemUptime
        )
        guard modeSwitchHoldAdapter.isHolding else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.modeSwitchHoldAdapter.triggerIfEligible(at: ProcessInfo.processInfo.systemUptime) else { return }
            self.pointerGestureAdapter.cancel()
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

    private func isModeSwitchLeadingIcon(_ point: CGPoint) -> Bool {
        guard phase5PreviewStateContainer.derivedState.visualState == .activityCollapsed else { return false }
        // The 24pt activity artwork is inset 18pt from the leading shell edge.
        return point.x >= 14 && point.x <= 58
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
        requestPreviewLayoutChange(
            to: update.currentLayoutInput,
            using: providedScreenMetrics
        )
        synchronizePanelClickThroughState()

        guard allowLockScheduling else { return }

        if update.currentState.isForceCompactLocked,
           update.previousState.isForceCompactLocked == false {
            dispatchPhase5Intent(
                .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                using: providedScreenMetrics,
                allowLockScheduling: false
            )
        }

        if update.currentState.isTrackpadGestureLocked,
           update.previousState.isTrackpadGestureLocked == false {
            scheduleTrackpadCooldownRelease()
        }
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
        let shouldKeepInteractiveRouting = derivedState.visualState.isExpanded ||
            phase5PreviewStateContainer.domainState.isHovered ||
            pointerGestureAdapter.isTracking
        islandPanel.setClickThroughEnabled(shouldKeepInteractiveRouting == false)
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
