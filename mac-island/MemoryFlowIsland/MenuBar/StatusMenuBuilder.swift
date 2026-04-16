import AppKit

protocol StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        showHideAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu
}

struct StatusMenuBuilder: StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        showHideAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let showHideTitle = isIslandVisible ? "Hide Island" : "Show Island"
        let showHideItem = NSMenuItem(title: showHideTitle, action: showHideAction, keyEquivalent: "")
        showHideItem.target = target
        menu.addItem(showHideItem)

        let preferencesItem = NSMenuItem(title: "Preferences", action: preferencesAction, keyEquivalent: ",")
        preferencesItem.target = target
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
