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
    private var isIslandVisible: Bool
    private var languageObserver: NSObjectProtocol?

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        languageSettings: AppLanguageSettings,
        menuBuilder: StatusMenuBuilding = StatusMenuBuilder(),
        isIslandVisible: Bool = true,
        logoutHandler: @escaping () -> Void = {},
        quitHandler: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.windowController = windowController
        self.phase5ScenarioController = windowController as? IslandPhase5ScenarioControlling
        self.preferencesWindowController = preferencesWindowController
        self.languageSettings = languageSettings
        self.menuBuilder = menuBuilder
        self.isIslandVisible = isIslandVisible
        self.quitHandler = quitHandler
        self.logoutHandler = logoutHandler
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: AppLanguageSettings.didChangeNotification,
            object: languageSettings,
            queue: .main
        ) { [weak self] _ in
            self?.configureButton(self?.statusItem?.button)
            self?.refreshMenu()
        }
    }

    func install() {
        guard statusItem == nil else { return }
        installStatusItem()
        reinforceStatusItemVisibility()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton(item.button)
        item.isVisible = true
        statusItem = item
        refreshMenu()
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
        if let source = NSImage(named: "MemoryFlowStatusBarIcon"),
           let image = source.copy() as? NSImage {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
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

    private func reinforceStatusItemVisibility() {
        for delay in [0.0, 0.5, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.statusItem?.isVisible = true
            }
        }
        // macOS 26 Tahoe can silently drop a status item behind its per-app menu bar
        // allow-list, parking the item off-screen even though `isVisible` stays true and
        // no API reports the block. Give the menu bar time to place (or park) the item,
        // then verify and, if needed, guide the user to re-enable it.
        if #available(macOS 26.0, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.recoverIfStatusItemBlocked(hasRecreated: false)
            }
        }
    }

    /// True when the status item reports itself visible but its backing window is parked
    /// off every screen — the signature of the Tahoe menu bar allow-list block.
    private var isStatusItemBlockedByMenuBar: Bool {
        guard let statusItem, statusItem.isVisible, let button = statusItem.button else { return false }
        // A live backing window is required: before placement the window can be absent,
        // which is not a block. A placed item reports the screen hosting the menu bar;
        // a blocked item is moved below the display, so its screen resolves to nil.
        guard let window = button.window else { return false }
        return window.screen == nil
    }

    @available(macOS 26.0, *)
    private func recoverIfStatusItemBlocked(hasRecreated: Bool) {
        guard isStatusItemBlockedByMenuBar else { return }

        if hasRecreated == false {
            // A single clean recreate clears transient placement failures (e.g. menu bar
            // overcrowding during login) without disturbing a legitimately placed item.
            reinstallStatusItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.recoverIfStatusItemBlocked(hasRecreated: true)
            }
            return
        }

        presentMenuBarBlockedNoticeIfNeeded()
    }

    private func reinstallStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        installStatusItem()
        statusItem?.isVisible = true
    }

    private func presentMenuBarBlockedNoticeIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "menuBarBlockedNoticeShownVersion"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        // Notify at most once per app version so an intentional user opt-out is respected.
        guard defaults.string(forKey: key) != version else { return }
        defaults.set(version, forKey: key)

        let language = languageSettings.language
        let alert = NSAlert()
        alert.messageText = AppCopy.text(.menuBarBlockedTitle, language: language)
        alert.informativeText = AppCopy.text(.menuBarBlockedMessage, language: language)
        alert.addButton(withTitle: AppCopy.text(.menuBarBlockedOpenSettings, language: language))
        alert.addButton(withTitle: AppCopy.text(.menuBarBlockedDismiss, language: language))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openMenuBarSettings()
        }
    }

    private func openMenuBarSettings() {
        // Deep-links to System Settings › Control Center, which hosts Tahoe's
        // "Allow in the Menu Bar" list.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
