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
        menuBarController: MenuBarControlling = PlaceholderMenuBarController()
    ) {
        self.windowController = windowController
        self.menuBarController = menuBarController
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

private final class PlaceholderMenuBarController: MenuBarControlling {
    func install() {}
    func uninstall() {}
}
