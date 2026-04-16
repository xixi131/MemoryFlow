import AppKit
import SwiftUI

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel
    private let notchLayoutEngine: NotchLayoutEngine
    private let displayObserver: DisplayObserver

    init(
        panel: IslandPanel = IslandPanel(),
        notchLayoutEngine: NotchLayoutEngine = NotchLayoutEngine(),
        displayObserver: DisplayObserver = DisplayObserver()
    ) {
        self.islandPanel = panel
        self.notchLayoutEngine = notchLayoutEngine
        self.displayObserver = displayObserver
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
        guard let screenFrame = displayObserver.currentScreenFrame() else { return }
        let targetFrame = notchLayoutEngine.islandFrame(
            screenFrame: screenFrame,
            islandSize: islandPanel.frame.size
        )
        islandPanel.setFrame(targetFrame, display: true)
    }
}
