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
    private let menuBarController: MenuBarControlling

    init(
        windowController: IslandWindowControlling = IslandWindowController(),
        menuBarController: MenuBarControlling? = nil
    ) {
        self.windowController = windowController
        self.menuBarController = menuBarController ?? StatusBarController(windowController: windowController)
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
