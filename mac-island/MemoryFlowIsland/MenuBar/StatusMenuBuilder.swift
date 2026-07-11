import AppKit

protocol StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        phase5Scenarios: [IslandMockScenario],
        phase5InteractionDemoControls: [IslandPhase5InteractionDemoControl],
        showHideAction: Selector,
        phase5ScenarioAction: Selector,
        phase5InteractionDemoAction: Selector,
        preferencesAction: Selector,
        logoutAction: Selector,
        quitAction: Selector
    ) -> NSMenu
}

struct StatusMenuBuilder: StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        phase5Scenarios: [IslandMockScenario],
        phase5InteractionDemoControls: [IslandPhase5InteractionDemoControl],
        showHideAction: Selector,
        phase5ScenarioAction: Selector,
        phase5InteractionDemoAction: Selector,
        preferencesAction: Selector,
        logoutAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let showHideTitle = isIslandVisible ? "Hide Island" : "Show Island"
        let showHideItem = NSMenuItem(title: showHideTitle, action: showHideAction, keyEquivalent: "")
        showHideItem.target = target
        menu.addItem(showHideItem)

        if phase5Scenarios.isEmpty == false {
            let scenariosMenu = NSMenu(title: "Phase 5 Scenarios")
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

            let scenariosRootItem = NSMenuItem(title: "Phase 5 Scenarios", action: nil, keyEquivalent: "")
            scenariosRootItem.submenu = scenariosMenu
            menu.addItem(scenariosRootItem)
        }

        if phase5InteractionDemoControls.isEmpty == false {
            let interactionsMenu = NSMenu(title: "Phase 5 Interactions")
            for control in phase5InteractionDemoControls {
                let interactionItem = NSMenuItem(
                    title: control.menuTitle,
                    action: phase5InteractionDemoAction,
                    keyEquivalent: ""
                )
                interactionItem.target = target
                interactionItem.representedObject = control.rawValue
                interactionsMenu.addItem(interactionItem)
            }

            let interactionsRootItem = NSMenuItem(title: "Phase 5 Interactions", action: nil, keyEquivalent: "")
            interactionsRootItem.submenu = interactionsMenu
            menu.addItem(interactionsRootItem)
        }

        let preferencesItem = NSMenuItem(title: "Preferences", action: preferencesAction, keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)

        let logoutItem = NSMenuItem(title: "Logout", action: logoutAction, keyEquivalent: "")
        logoutItem.target = target
        menu.addItem(logoutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
