import AppKit
import SwiftUI

struct IslandPreviewMotionControlRoute: Equatable {
    let sourceState: IslandVisualState
    let targetState: IslandVisualState
}

enum IslandPreviewMotionControl: String, CaseIterable, Identifiable {
    case compactToActivity
    case activityToExpanded
    case expandedToCompact
    case hoverEnter
    case hoverLeave

    var id: String {
        rawValue
    }

    var menuTitle: String {
        switch self {
        case .compactToActivity:
            return "Compact to Activity"
        case .activityToExpanded:
            return "Activity to Expanded"
        case .expandedToCompact:
            return "Expanded to Compact"
        case .hoverEnter:
            return "Hover Enter"
        case .hoverLeave:
            return "Hover Leave"
        }
    }

    func resolveRoute(
        currentPreviewState: IslandVisualState,
        currentTargetState: IslandVisualState
    ) -> IslandPreviewMotionControlRoute {
        switch self {
        case .compactToActivity:
            return IslandPreviewMotionControlRoute(
                sourceState: .compactCollapsed,
                targetState: .activityCollapsed
            )
        case .activityToExpanded:
            return IslandPreviewMotionControlRoute(
                sourceState: .activityCollapsed,
                targetState: preferredExpandedState(
                    currentPreviewState: currentPreviewState,
                    currentTargetState: currentTargetState
                )
            )
        case .expandedToCompact:
            return IslandPreviewMotionControlRoute(
                sourceState: preferredExpandedState(
                    currentPreviewState: currentPreviewState,
                    currentTargetState: currentTargetState
                ),
                targetState: .compactCollapsed
            )
        case .hoverEnter:
            return IslandPreviewMotionControlRoute(
                sourceState: .compactCollapsed,
                targetState: .hoverCollapsed
            )
        case .hoverLeave:
            return IslandPreviewMotionControlRoute(
                sourceState: .hoverCollapsed,
                targetState: .compactCollapsed
            )
        }
    }

    private func preferredExpandedState(
        currentPreviewState: IslandVisualState,
        currentTargetState: IslandVisualState
    ) -> IslandVisualState {
        if currentTargetState.isExpanded {
            return currentTargetState
        }
        if currentPreviewState.isExpanded {
            return currentPreviewState
        }
        return .expandedMusic
    }
}

protocol IslandPreviewMotionControlling: AnyObject {
    var availablePreviewMotionControls: [IslandPreviewMotionControl] { get }
    func triggerPreviewMotionControl(_ control: IslandPreviewMotionControl)
}

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
    private let screenMetricsResolver: (NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?
    private let previewSizingDiagnosticsEnabled: Bool
    private let previewMotionControlsEnabled: Bool
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
    private var previewMotionPlan: IslandMotionPlan?
    private var previewTransitionState: IslandPreviewTransitionState
    private var previewTransitionResetWorkItem: DispatchWorkItem?
    private var reducerTransitionCompletionWorkItems: [String: DispatchWorkItem] = [:]
    private var pointerGestureAdapter = IslandPointerGestureAdapter()
    private var trackpadWheelAdapter = IslandTrackpadWheelAdapter()
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
        previewSizingDiagnosticsEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_SIZING_DIAGNOSTICS"] == "1",
        previewMotionControlsEnabled: Bool = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_PREVIEW_CONTROLS"] == "1",
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
        self.previewSizingDiagnosticsEnabled = previewSizingDiagnosticsEnabled
        self.previewMotionControlsEnabled = previewMotionControlsEnabled
        self.phase5PreviewModeEnabled = phase5PreviewModeEnabled
        self.phase5ScenarioMenuEnabled = phase5ScenarioMenuEnabled
        self.legacyPreviewInteractionRoutingRequested = legacyPreviewInteractionRoutingRequested
        self.phase5PreviewStateContainer = phase5PreviewStateContainer
        self.activeLayoutInput = initialLayoutInput
        self.previewState = initialLayoutInput.visualState
        self.previewTransitionState = .idle(at: initialLayoutInput.visualState)
        self.hostingView = IslandInteractionHostingView(
            rootView: IslandRootView(
                previewState: initialLayoutInput.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: initialLayoutInput.widthConstraints,
                motionPlan: nil,
                onAdvancePreviewState: nil
            )
        )
        self.screenMetricsResolver = screenMetricsResolver ?? { window, preferredDisplayIdentity in
            displayObserver.preferredScreenMetrics(
                for: window,
                preferredDisplayIdentity: preferredDisplayIdentity
            )
        }
        super.init(window: panel)
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
    }

    func hide() {
        hoverMonitor.stopMonitoring()
        pointerGestureAdapter.cancel()
        trackpadWheelAdapter.reset()
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
        hostingView.onPointerDown = { [weak self] point in
            self?.handlePointerDown(at: point)
        }
        hostingView.onPointerDragged = { [weak self] point in
            self?.handlePointerDragged(at: point)
        }
        hostingView.onPointerUp = { [weak self] point in
            self?.handlePointerUp(at: point)
        }
        hostingView.onScrollWheel = { [weak self] event in
            self?.handleScrollWheel(event)
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
        previewTransitionResetWorkItem?.cancel()
        previewTransitionResetWorkItem = nil
        reducerTransitionCompletionWorkItems.values.forEach { $0.cancel() }
        reducerTransitionCompletionWorkItems.removeAll()
        NotificationCenter.default.removeObserverIfNeeded(applicationTerminationObserver)
        applicationTerminationObserver = nil
    }

    private func handleDisplayChange(_ changeSignal: DisplayObserver.ChangeSignal) {
        switch changeSignal {
        case .screenParametersChanged, .workspaceDidWake:
            repositionToTopCenter()
        }
    }

    private func repositionToTopCenter(animated: Bool = false) {
        guard let screenMetrics = screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else { return }
        let resolvedLayout = resolvePreviewLayout(
            for: activeLayoutInput,
            on: screenMetrics
        )
        previewMotionPlan = nil
        previewTransitionState = .idle(at: previewState)
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics,
            animated: animated,
            motionPlan: nil
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
        animated: Bool,
        motionPlan: IslandMotionPlan?
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
        applySizingResult(
            sizingResult,
            on: screenMetrics,
            animated: animated,
            motionPlan: motionPlan
        )
        lastSizingResult = sizingResult
        logSizingDiagnosticsIfNeeded(sizingResult)
    }

    private func applySizingResult(
        _ sizingResult: IslandWindowSizingResult,
        on screenMetrics: ScreenMetrics,
        animated: Bool = false,
        motionPlan: IslandMotionPlan? = nil
    ) {
        let panelFrame = islandPanel.panelFrame(forVisibleShellFrame: sizingResult.visibleFrame)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = motionPlan?.duration ?? 0.18
                context.timingFunction = CAMediaTimingFunction(name: timingFunctionName(for: motionPlan))
                islandPanel.animator().setFrame(panelFrame, display: true)
            }
        } else {
            islandPanel.setFrame(panelFrame, display: true)
        }
        lastAppliedDisplayIdentity = screenMetrics.displayIdentity
        lastAppliedFrame = sizingResult.visibleFrame
        lastAppliedScreenMetrics = screenMetrics
    }

    private func hoverHotspotFrameForMonitoring() -> CGRect? {
        guard islandPanel.isVisible else { return nil }
        return islandPanel.hoverHotspotFrame
    }

    private func handleHoverStart() {
        activateInteractiveHoverMode()
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.hoverEnter)
        } else if previewTransitionState.targetState == .compactCollapsed {
            requestPreviewStateChange(to: .hoverCollapsed)
        }
        NSCursor.arrow.set()
    }

    private func handleHoverEnd() {
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.hoverLeave)
        } else if previewTransitionState.targetState == .hoverCollapsed {
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
            motionPlan: previewMotionPlan,
            onAdvancePreviewState: usesPhase5PreviewInteractionRouting ? nil : { [weak self] in
                self?.advancePreviewState()
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

    private func triggerPreviewMotionRoute(_ route: IslandPreviewMotionControlRoute) {
        guard let screenMetrics = screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else {
            activeLayoutInput = IslandPreviewLayoutInput(
                visualState: route.targetState,
                widthConstraints: previewWidthConstraints
            )
            previewState = route.targetState
            previewTransitionState = .idle(at: route.targetState)
            repositionToTopCenter(animated: true)
            return
        }

        if previewState != route.sourceState ||
            previewTransitionState.targetState != route.sourceState ||
            previewTransitionState.isAnimating {
            stagePreviewControlSourceState(route.sourceState, on: screenMetrics)
        }

        requestPreviewStateChange(
            to: route.targetState,
            using: screenMetrics
        )
    }

    private func stagePreviewControlSourceState(
        _ sourceState: IslandVisualState,
        on screenMetrics: ScreenMetrics
    ) {
        previewTransitionResetWorkItem?.cancel()
        previewTransitionResetWorkItem = nil
        previewState = sourceState
        activeLayoutInput = IslandPreviewLayoutInput(
            visualState: sourceState,
            widthConstraints: widthConstraints(
                for: sourceState,
                attachmentMetrics: resolvedLayoutAttachmentMetrics(for: screenMetrics)
            )
        )
        previewTransitionState = .idle(at: sourceState)
        previewMotionPlan = nil
        let resolvedLayout = resolvePreviewLayout(
            for: activeLayoutInput,
            on: screenMetrics
        )
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics,
            animated: false,
            motionPlan: nil
        )
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
            previewTransitionState = .idle(at: nextLayoutInput.visualState)
            previewMotionPlan = nil
            updateRootView()
            repositionToTopCenter(animated: true)
            return
        }

        guard previewTransitionState.targetState != nextLayoutInput.visualState ||
                previewTransitionState.isAnimating ||
                activeLayoutInput != nextLayoutInput else {
            return
        }

        let isRetargeting = previewTransitionState.isAnimating
        let previousState = isRetargeting ? previewTransitionState.targetState : previewState
        let resolvedLayout = resolvePreviewLayout(
            for: nextLayoutInput,
            on: screenMetrics
        )
        let motionPlan = IslandMotionEngine.plan(
            previous: previousState,
            next: nextLayoutInput.visualState,
            context: IslandMotionContext(
                currentSizingResult: lastSizingResult,
                nextSizingResult: resolvedLayout.sizingResult,
                isPreviewInteraction: true,
                isRetargeting: isRetargeting
            )
        )

        previewTransitionResetWorkItem?.cancel()
        previewTransitionState = isRetargeting
            ? previewTransitionState.retargeting(to: nextLayoutInput.visualState)
            : .animating(from: previewState, to: nextLayoutInput.visualState)
        activeLayoutInput = nextLayoutInput
        previewState = nextLayoutInput.visualState
        previewMotionPlan = motionPlan
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics,
            animated: true,
            motionPlan: motionPlan
        )
        schedulePreviewTransitionCompletion(
            targetState: nextLayoutInput.visualState,
            duration: motionPlan.duration
        )
    }

    private func handleTapInteraction() {
        if usesPhase5PreviewInteractionRouting {
            dispatchPhase5Intent(.tap)
            return
        }

        requestPreviewStateChange(to: previewTransitionState.targetState.nextPreviewState)
    }

    private func handlePointerDown(at point: CGPoint) {
        guard usesPhase5PreviewInteractionRouting else { return }
        activateInteractiveHoverMode()
        pointerGestureAdapter.pointerDown(at: Double(point.x))
        synchronizePanelClickThroughState()
    }

    private func handlePointerDragged(at point: CGPoint) {
        guard usesPhase5PreviewInteractionRouting else { return }
        pointerGestureAdapter.pointerDragged(to: Double(point.x))
    }

    private func handlePointerUp(at point: CGPoint) {
        guard usesPhase5PreviewInteractionRouting else { return }
        if let intent = pointerGestureAdapter.pointerUp(at: Double(point.x)) {
            dispatchPhase5Intent(intent)
        } else {
            synchronizePanelClickThroughState()
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

        dispatchPhase5Intent(intent)
    }

    private func dispatchPhase5Intent(
        _ intent: IslandInteractionIntent,
        using providedScreenMetrics: ScreenMetrics? = nil,
        allowLockScheduling: Bool = true
    ) {
        guard usesPhase5PreviewInteractionRouting else { return }
        let update = phase5PreviewStateContainer.dispatch(intent: intent)
        applyPhase5PreviewUpdate(
            update,
            using: providedScreenMetrics,
            allowLockScheduling: allowLockScheduling
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

        if update.currentState.isForceCompactTransitioning,
           update.previousState.isForceCompactTransitioning == false {
            scheduleReducerTransitionCompletion(
                identifier: IslandTransitionLockIdentifier.forceCompactTransition,
                duration: previewMotionPlan?.duration ?? 0.18
            )
        }

        if update.currentState.isTrackpadGestureLocked,
           update.previousState.isTrackpadGestureLocked == false {
            scheduleReducerTransitionCompletion(
                identifier: IslandTransitionLockIdentifier.trackpadGestureCooldown,
                duration: IslandInteractionThresholds.trackpadGestureCooldownWindow
            )
        }
    }

    private func scheduleReducerTransitionCompletion(
        identifier: String,
        duration: TimeInterval
    ) {
        reducerTransitionCompletionWorkItems[identifier]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if identifier == IslandTransitionLockIdentifier.trackpadGestureCooldown {
                self.trackpadWheelAdapter.clearCooldown()
            }
            self.dispatchPhase5Intent(
                .transitionComplete(identifier),
                using: self.lastAppliedScreenMetrics,
                allowLockScheduling: false
            )
            self.reducerTransitionCompletionWorkItems[identifier] = nil
        }
        reducerTransitionCompletionWorkItems[identifier] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(duration, 0.01),
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

    private func timingFunctionName(for motionPlan: IslandMotionPlan?) -> CAMediaTimingFunctionName {
        guard let timingCurve = motionPlan?.shellFrame.keyframes.curve else {
            return .easeOut
        }

        switch timingCurve {
        case .easeInOut:
            return .easeInEaseOut
        case .easeOut:
            return .easeOut
        case .linear:
            return .linear
        }
    }

    private func logSizingDiagnosticsIfNeeded(_ sizingResult: IslandWindowSizingResult) {
        guard previewSizingDiagnosticsEnabled else { return }
        print("[IslandSizing] \(sizingResult.debugSummary)")
    }

    private func schedulePreviewTransitionCompletion(
        targetState: IslandVisualState,
        duration: TimeInterval
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.previewTransitionState = self.previewTransitionState.completed()
            self.previewMotionPlan = nil
            self.updateRootView()
        }
        previewTransitionResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(duration, 0.01),
            execute: workItem
        )
    }
}

extension IslandWindowController: IslandPreviewMotionControlling {
    var availablePreviewMotionControls: [IslandPreviewMotionControl] {
        guard previewMotionControlsEnabled else { return [] }
        return IslandPreviewMotionControl.allCases
    }

    func triggerPreviewMotionControl(_ control: IslandPreviewMotionControl) {
        let route = control.resolveRoute(
            currentPreviewState: previewState,
            currentTargetState: previewTransitionState.targetState
        )
        triggerPreviewMotionRoute(route)
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

        if control == .hoverEnter {
            activateInteractiveHoverMode()
        }

        dispatchPhase5Intent(control.intent)
    }
}

private extension NotificationCenter {
    func removeObserverIfNeeded(_ observer: NSObjectProtocol?) {
        guard let observer else { return }
        removeObserver(observer)
    }
}
