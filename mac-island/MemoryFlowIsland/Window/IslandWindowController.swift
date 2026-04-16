import AppKit

final class IslandWindowController: NSWindowController, IslandWindowControlling {
    private let islandPanel: IslandPanel

    init(panel: IslandPanel = IslandPanel()) {
        self.islandPanel = panel
        super.init(window: panel)
        applyInitialWindowState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func show() {
        guard let window else { return }
        window.center()
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func applyInitialWindowState() {
        islandPanel.isReleasedWhenClosed = false
        islandPanel.orderOut(nil)
    }
}
