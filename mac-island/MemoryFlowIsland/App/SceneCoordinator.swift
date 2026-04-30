import AppKit

protocol IslandWindowControlling {
    func show()
    func hide()
}

protocol MenuBarControlling {
    func install()
    func uninstall()
}

final class SceneCoordinator {
    private let windowController: IslandWindowControlling
    private let preferencesWindowController: PreferencesWindowControlling
    private let menuBarController: MenuBarControlling

    init() {
        let windowController = IslandWindowController()
        let preferencesWindowController = PreferencesWindowController()
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        self.menuBarController = StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController
        )
    }

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        menuBarController: MenuBarControlling? = nil
    ) {
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        self.menuBarController = menuBarController ?? StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController
        )
    }

    func start() {
        menuBarController.install()
        windowController.show()
    }

    func stop() {
        windowController.hide()
        menuBarController.uninstall()
    }
}
