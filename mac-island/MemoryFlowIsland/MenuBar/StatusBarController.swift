import AppKit

final class StatusBarController: NSObject, MenuBarControlling {
    private var statusItem: NSStatusItem?
    private let windowController: IslandWindowControlling
    private let phase5ScenarioController: IslandPhase5ScenarioControlling?
    private let phase5InteractionDemoController: IslandPhase5InteractionDemoControlling?
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
        self.phase5ScenarioController = windowController as? IslandPhase5ScenarioControlling
        self.phase5InteractionDemoController = windowController as? IslandPhase5InteractionDemoControlling
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

    @objc func phase5ScenarioMenuItemClicked(_ sender: Any?) {
        guard
            let menuItem = sender as? NSMenuItem,
            let scenarioID = menuItem.representedObject as? String
        else {
            return
        }

        if isIslandVisible == false {
            windowController.show()
            isIslandVisible = true
        }

        phase5ScenarioController?.selectPhase5Scenario(id: scenarioID)
        refreshMenu()
    }

    @objc func phase5InteractionDemoMenuItemClicked(_ sender: Any?) {
        guard
            let menuItem = sender as? NSMenuItem,
            let rawValue = menuItem.representedObject as? String,
            let control = IslandPhase5InteractionDemoControl(rawValue: rawValue)
        else {
            return
        }

        if isIslandVisible == false {
            windowController.show()
            isIslandVisible = true
        }

        phase5InteractionDemoController?.triggerPhase5InteractionDemo(control)
        refreshMenu()
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

        let phase5Scenarios = phase5ScenarioController?.availablePhase5Scenarios ?? []
        let phase5InteractionDemoControls = phase5InteractionDemoController?.availablePhase5InteractionDemoControls ?? []
        statusItem.menu = menuBuilder.buildMenu(
            target: self,
            isIslandVisible: isIslandVisible,
            phase5Scenarios: phase5Scenarios,
            phase5InteractionDemoControls: phase5InteractionDemoControls,
            showHideAction: #selector(toggleIslandMenuItemClicked(_:)),
            phase5ScenarioAction: #selector(phase5ScenarioMenuItemClicked(_:)),
            phase5InteractionDemoAction: #selector(phase5InteractionDemoMenuItemClicked(_:)),
            preferencesAction: #selector(preferencesMenuItemClicked(_:)),
            quitAction: #selector(quitMenuItemClicked(_:))
        )
    }
}
