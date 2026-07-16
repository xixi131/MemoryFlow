import AppKit

final class StatusBarController: NSObject, MenuBarControlling {
    private var statusItem: NSStatusItem?
    private let windowController: IslandWindowControlling
    private let phase5ScenarioController: IslandPhase5ScenarioControlling?
    private let preferencesWindowController: PreferencesWindowControlling
    private let languageSettings: AppLanguageSettings
    private let menuBuilder: StatusMenuBuilding
    private let quitHandler: () -> Void
    private let logoutHandler: () -> Void
    private let stateDidChange: (MenuBarPresentationState) -> Void
    private var isIslandVisible: Bool
    private var languageObserver: NSObjectProtocol?

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        languageSettings: AppLanguageSettings,
        menuBuilder: StatusMenuBuilding = StatusMenuBuilder(),
        isIslandVisible: Bool = true,
        logoutHandler: @escaping () -> Void = {},
        quitHandler: @escaping () -> Void = { NSApp.terminate(nil) },
        stateDidChange: @escaping (MenuBarPresentationState) -> Void = { _ in }
    ) {
        self.windowController = windowController
        self.phase5ScenarioController = windowController as? IslandPhase5ScenarioControlling
        self.preferencesWindowController = preferencesWindowController
        self.languageSettings = languageSettings
        self.menuBuilder = menuBuilder
        self.isIslandVisible = isIslandVisible
        self.quitHandler = quitHandler
        self.logoutHandler = logoutHandler
        self.stateDidChange = stateDidChange
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: AppLanguageSettings.didChangeNotification,
            object: languageSettings,
            queue: .main
        ) { [weak self] _ in
            self?.configureButton(self?.statusItem?.button)
            self?.refreshMenu()
            self?.publishState()
        }
    }

    func install() {
        if #available(macOS 26.0, *) {
            publishState()
            return
        }

        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton(item.button)
        statusItem = item
        refreshMenu()
        publishState()
    }

    func uninstall() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    @objc func toggleIslandMenuItemClicked(_ sender: Any?) {
        if isIslandVisible {
            windowController.hide()
        } else {
            windowController.show()
        }

        isIslandVisible.toggle()
        refreshMenu()
        publishState()
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

    @objc func quitMenuItemClicked(_ sender: Any?) {
        quitHandler()
    }

    @objc func logoutMenuItemClicked(_ sender: Any?) {
        logoutHandler()
    }

    private func configureButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        if let image = NSImage(named: "MemoryFlowStatusBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.title = "MF"
        }
        button.toolTip = AppCopy.text(.menuBarTooltip, language: languageSettings.language)
    }

    private func refreshMenu() {
        let phase5Scenarios = phase5ScenarioController?.availablePhase5Scenarios ?? []
        statusItem?.menu = menuBuilder.buildMenu(
            target: self,
            isIslandVisible: isIslandVisible,
            language: languageSettings.language,
            phase5Scenarios: phase5Scenarios,
            showHideAction: #selector(toggleIslandMenuItemClicked(_:)),
            phase5ScenarioAction: #selector(phase5ScenarioMenuItemClicked(_:)),
            preferencesAction: #selector(preferencesMenuItemClicked(_:)),
            logoutAction: #selector(logoutMenuItemClicked(_:)),
            quitAction: #selector(quitMenuItemClicked(_:))
        )
    }

    private func publishState() {
        stateDidChange(
            MenuBarPresentationState(
                language: languageSettings.language,
                isIslandVisible: isIslandVisible
            )
        )
    }
}
