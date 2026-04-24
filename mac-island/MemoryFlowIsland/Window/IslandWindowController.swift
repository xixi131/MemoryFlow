import AppKit
import SwiftUI

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver
    private let screenMetricsResolver: (NSWindow?) -> ScreenMetrics?

    private(set) var lastAppliedDisplayIdentity: ScreenMetrics.DisplayIdentity?
    private(set) var lastAppliedFrame: CGRect?

    init(
        panel: IslandPanel = IslandPanel(),
        notchLayoutEngine: NotchLayoutEngine = NotchLayoutEngine(),
        displayObserver: DisplayObserver = DisplayObserver(),
        screenMetricsResolver: ((NSWindow?) -> ScreenMetrics?)? = nil
    ) {
        self.islandPanel = panel
        self.notchLayoutEngine = notchLayoutEngine
        self.displayObserver = displayObserver
        self.screenMetricsResolver = screenMetricsResolver ?? { window in
            displayObserver.currentScreenMetrics(for: window)
        }
        super.init(window: panel)
        configureContentView()
        applyInitialWindowState()
        beginDisplayObservation()
    }

    deinit {
        displayObserver.stopObserving()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func show() {
        repositionToTopCenter()
        guard let window else { return }
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func configureContentView() {
        let hostingView = NSHostingView(rootView: IslandRootView())
        hostingView.frame = NSRect(origin: .zero, size: islandPanel.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        islandPanel.contentView = hostingView
    }

    private func applyInitialWindowState() {
        islandPanel.isReleasedWhenClosed = false
        islandPanel.orderOut(nil)
    }

    private func beginDisplayObservation() {
        displayObserver.startObserving { [weak self] in
            self?.repositionToTopCenter()
        }
    }

    private func repositionToTopCenter() {
        guard let screenMetrics = screenMetricsResolver(islandPanel) else { return }
        let placementResult = notchLayoutEngine.placementResult(
            screenMetrics: screenMetrics,
            islandSize: islandPanel.frame.size
        )
        applyPlacement(placementResult, on: screenMetrics)
    }

    private func applyPlacement(_ placementResult: IslandPlacementResult, on screenMetrics: ScreenMetrics) {
        islandPanel.setFrame(placementResult.frame, display: true)
        lastAppliedDisplayIdentity = screenMetrics.displayIdentity
        lastAppliedFrame = placementResult.frame
    }
}
