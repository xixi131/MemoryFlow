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

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver
    private let hoverMonitor: IslandHoverMonitor
    private let screenMetricsResolver: (NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?
    private let previewSizingDiagnosticsEnabled: Bool
    private let previewMotionControlsEnabled: Bool
    private let hostingView: NSHostingView<IslandRootView>
    private var previewState: IslandVisualState = .compactCollapsed
    private var previewVisualScale: CGFloat = 1
    private var previewHorizontalScale: CGFloat = 1
    private var previewWidthConstraints: IslandWidthConstraints = .none
    private var previewMotionPlan: IslandMotionPlan?
    private var previewTransitionState: IslandPreviewTransitionState = .idle(at: .compactCollapsed)
    private var previewTransitionResetWorkItem: DispatchWorkItem?
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
        screenMetricsResolver: ((NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?)? = nil
    ) {
        self.islandPanel = panel
        self.notchLayoutEngine = notchLayoutEngine
        self.displayObserver = displayObserver
        self.hoverMonitor = hoverMonitor
        self.previewSizingDiagnosticsEnabled = previewSizingDiagnosticsEnabled
        self.previewMotionControlsEnabled = previewMotionControlsEnabled
        self.hostingView = NSHostingView(
            rootView: IslandRootView(
                previewState: previewState,
                visualScale: previewVisualScale,
                horizontalScale: previewHorizontalScale,
                widthConstraints: previewWidthConstraints,
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
    }

    func hide() {
        hoverMonitor.stopMonitoring()
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

    private func applyInitialWindowState() {
        islandPanel.isReleasedWhenClosed = false
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
            for: previewState,
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
        for state: IslandVisualState,
        on screenMetrics: ScreenMetrics
    ) -> (attachmentMetrics: TopAttachmentMetrics, widthConstraints: IslandWidthConstraints, sizingResult: IslandWindowSizingResult) {
        let attachmentMetrics = notchLayoutEngine.topAttachmentMetrics(for: screenMetrics)
        let requestedWidthConstraints = widthConstraints(
            for: state,
            attachmentMetrics: attachmentMetrics
        )
        let sizingResult = IslandWindowSizingEngine.resolve(
            state: state,
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
        if previewTransitionState.targetState == .compactCollapsed {
            requestPreviewStateChange(to: .hoverCollapsed)
        }
        NSCursor.arrow.set()
    }

    private func handleHoverEnd() {
        if previewTransitionState.targetState == .hoverCollapsed {
            requestPreviewStateChange(to: .compactCollapsed)
        }
        recoverClickThroughAfterHoverExit()
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
            onAdvancePreviewState: { [weak self] in
                self?.advancePreviewState()
            }
        )
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

    private func advancePreviewState() {
        requestPreviewStateChange(to: previewTransitionState.targetState.nextPreviewState)
    }

    private func triggerPreviewMotionRoute(_ route: IslandPreviewMotionControlRoute) {
        guard let screenMetrics = screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else {
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
        previewTransitionState = .idle(at: sourceState)
        previewMotionPlan = nil
        let resolvedLayout = resolvePreviewLayout(
            for: sourceState,
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
        guard let screenMetrics = providedScreenMetrics ?? screenMetricsResolver(islandPanel, lastAppliedDisplayIdentity) else {
            previewState = nextState
            previewTransitionState = .idle(at: nextState)
            repositionToTopCenter(animated: true)
            return
        }

        guard previewTransitionState.targetState != nextState || previewTransitionState.isAnimating == false else {
            return
        }

        let isRetargeting = previewTransitionState.isAnimating
        let previousState = isRetargeting ? previewTransitionState.targetState : previewState
        let resolvedLayout = resolvePreviewLayout(
            for: nextState,
            on: screenMetrics
        )
        let motionPlan = IslandMotionEngine.plan(
            previous: previousState,
            next: nextState,
            context: IslandMotionContext(
                currentSizingResult: lastSizingResult,
                nextSizingResult: resolvedLayout.sizingResult,
                isPreviewInteraction: true,
                isRetargeting: isRetargeting
            )
        )

        previewTransitionResetWorkItem?.cancel()
        previewTransitionState = isRetargeting
            ? previewTransitionState.retargeting(to: nextState)
            : .animating(from: previewState, to: nextState)
        previewState = nextState
        previewMotionPlan = motionPlan
        applyResolvedPreviewLayout(
            resolvedLayout,
            on: screenMetrics,
            animated: true,
            motionPlan: motionPlan
        )
        schedulePreviewTransitionCompletion(
            targetState: nextState,
            duration: motionPlan.duration
        )
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

private extension NotificationCenter {
    func removeObserverIfNeeded(_ observer: NSObjectProtocol?) {
        guard let observer else { return }
        removeObserver(observer)
    }
}
