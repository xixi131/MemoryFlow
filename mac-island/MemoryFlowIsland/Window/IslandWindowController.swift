import AppKit
import SwiftUI

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver
    private let hoverMonitor: IslandHoverMonitor
    private let screenMetricsResolver: (NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?
    private let hostingView: NSHostingView<IslandRootView>
    private var previewState: IslandVisualState = .compactCollapsed
    private var previewVisualScale: CGFloat = 1
    private var applicationTerminationObserver: NSObjectProtocol?

    private(set) var lastAppliedDisplayIdentity: ScreenMetrics.DisplayIdentity?
    private(set) var lastAppliedFrame: CGRect?
    private(set) var lastAppliedScreenMetrics: ScreenMetrics?

    init(
        panel: IslandPanel = IslandPanel(),
        notchLayoutEngine: NotchLayoutEngine = NotchLayoutEngine(),
        displayObserver: DisplayObserver = DisplayObserver(),
        hoverMonitor: IslandHoverMonitor = IslandHoverMonitor(),
        screenMetricsResolver: ((NSWindow?, ScreenMetrics.DisplayIdentity?) -> ScreenMetrics?)? = nil
    ) {
        self.islandPanel = panel
        self.notchLayoutEngine = notchLayoutEngine
        self.displayObserver = displayObserver
        self.hoverMonitor = hoverMonitor
        self.hostingView = NSHostingView(
            rootView: IslandRootView(
                previewState: previewState,
                visualScale: previewVisualScale,
                onAdvancePreviewState: nil
            )
        )
        self.hostingView.rootView = IslandRootView(
            previewState: previewState,
            visualScale: previewVisualScale,
            onAdvancePreviewState: { [weak self] in
                self?.advancePreviewState()
            }
        )
        self.screenMetricsResolver = screenMetricsResolver ?? { window, preferredDisplayIdentity in
            displayObserver.preferredScreenMetrics(
                for: window,
                preferredDisplayIdentity: preferredDisplayIdentity
            )
        }
        super.init(window: panel)
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
        let attachmentMetrics = notchLayoutEngine.topAttachmentMetrics(for: screenMetrics)
        previewVisualScale = attachmentMetrics.visualScale
        let previewSnapshot = IslandShapeEngine.snapshot(
            for: previewState,
            visualScale: previewVisualScale
        )
        islandPanel.setRequestedShellLayout(
            visibleShellSize: NSSize(
                width: previewSnapshot.visibleFrame.width,
                height: previewSnapshot.visibleFrame.height
            ),
            shadowOutsets: previewSnapshot.shadowOutsets
        )
        updateRootView()
        let placementResult = notchLayoutEngine.placementResult(
            screenMetrics: screenMetrics,
            islandSize: islandPanel.requestedShellSize
        )
        applyPlacement(placementResult, on: screenMetrics, animated: animated)
    }

    private func applyPlacement(_ placementResult: IslandPlacementResult, on screenMetrics: ScreenMetrics, animated: Bool = false) {
        let panelFrame = islandPanel.panelFrame(forVisibleShellFrame: placementResult.frame)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                islandPanel.animator().setFrame(panelFrame, display: true)
            }
        } else {
            islandPanel.setFrame(panelFrame, display: true)
        }
        lastAppliedDisplayIdentity = screenMetrics.displayIdentity
        lastAppliedFrame = placementResult.frame
        lastAppliedScreenMetrics = screenMetrics
    }

    private func hoverHotspotFrameForMonitoring() -> CGRect? {
        guard islandPanel.isVisible else { return nil }
        return islandPanel.hoverHotspotFrame
    }

    private func handleHoverStart() {
        activateInteractiveHoverMode()
        NSCursor.arrow.set()
    }

    private func handleHoverEnd() {
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
            onAdvancePreviewState: { [weak self] in
                self?.advancePreviewState()
            }
        )
    }

    private func advancePreviewState() {
        previewState = previewState.nextPreviewState
        repositionToTopCenter(animated: true)
    }
}

private extension NotificationCenter {
    func removeObserverIfNeeded(_ observer: NSObjectProtocol?) {
        guard let observer else { return }
        removeObserver(observer)
    }
}
