import AppKit

final class StatusBarController: NSObject, MenuBarControlling {
    private var statusItem: NSStatusItem?
    private let windowController: IslandWindowControlling
    private let preferencesWindowController: PreferencesWindowControlling
    private let menuBuilder: StatusMenuBuilding
    private let quitHandler: () -> Void
    private var isIslandVisible: Bool

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        menuBuilder: StatusMenuBuilding = StatusMenuBuilder(),
        isIslandVisible: Bool = true,
        quitHandler: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        self.menuBuilder = menuBuilder
        self.isIslandVisible = isIslandVisible
        self.quitHandler = quitHandler
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton(item.button)
        statusItem = item
        refreshMenu()
    }

    func uninstall() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc func toggleIslandMenuItemClicked(_ sender: Any?) {
        if isIslandVisible {
            windowController.hide()
        } else {
            windowController.show()
        }

        isIslandVisible.toggle()
        refreshMenu()
    }

    @objc func preferencesMenuItemClicked(_ sender: Any?) {
        preferencesWindowController.show()
    }

    @objc func quitMenuItemClicked(_ sender: Any?) {
        quitHandler()
    }

    private func configureButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        button.title = "MF"
        button.toolTip = "MemoryFlow Island"
    }

    private func refreshMenu() {
        guard let statusItem else { return }

        statusItem.menu = menuBuilder.buildMenu(
            target: self,
            isIslandVisible: isIslandVisible,
            showHideAction: #selector(toggleIslandMenuItemClicked(_:)),
            preferencesAction: #selector(preferencesMenuItemClicked(_:)),
            quitAction: #selector(quitMenuItemClicked(_:))
        )
    }
}
