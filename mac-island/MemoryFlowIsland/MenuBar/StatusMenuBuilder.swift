import AppKit

protocol StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        language: AppLanguage,
        phase5Scenarios: [IslandMockScenario],
        showHideAction: Selector,
        phase5ScenarioAction: Selector,
        preferencesAction: Selector,
        logoutAction: Selector,
        quitAction: Selector
    ) -> NSMenu
}

struct StatusMenuBuilder: StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        language: AppLanguage,
        phase5Scenarios: [IslandMockScenario],
        showHideAction: Selector,
        phase5ScenarioAction: Selector,
        preferencesAction: Selector,
        logoutAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let showHideTitle = AppCopy.text(isIslandVisible ? .hideIsland : .showIsland, language: language)
        let showHideItem = NSMenuItem(title: showHideTitle, action: showHideAction, keyEquivalent: "")
        showHideItem.target = target
        menu.addItem(showHideItem)

        if phase5Scenarios.isEmpty == false {
            let scenariosMenu = NSMenu(title: AppCopy.text(.phase5Scenarios, language: language))
            for scenario in phase5Scenarios {
                let scenarioItem = NSMenuItem(
                    title: scenario.menuTitle,
                    action: phase5ScenarioAction,
                    keyEquivalent: ""
                )
                scenarioItem.target = target
                scenarioItem.representedObject = scenario.id
                scenariosMenu.addItem(scenarioItem)
            }

            let scenariosRootItem = NSMenuItem(title: AppCopy.text(.phase5Scenarios, language: language), action: nil, keyEquivalent: "")
            scenariosRootItem.submenu = scenariosMenu
            menu.addItem(scenariosRootItem)
        }

        let preferencesItem = NSMenuItem(title: AppCopy.text(.settings, language: language), action: preferencesAction, keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)

        let logoutItem = NSMenuItem(title: AppCopy.text(.signOut, language: language), action: logoutAction, keyEquivalent: "")
        logoutItem.target = target
        menu.addItem(logoutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: AppCopy.text(.quit, language: language), action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
