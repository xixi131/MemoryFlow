import AppKit

protocol StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        previewMotionControls: [IslandPreviewMotionControl],
        showHideAction: Selector,
        previewMotionAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu
}

struct StatusMenuBuilder: StatusMenuBuilding {
    func buildMenu(
        target: AnyObject,
        isIslandVisible: Bool,
        previewMotionControls: [IslandPreviewMotionControl],
        showHideAction: Selector,
        previewMotionAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let showHideTitle = isIslandVisible ? "Hide Island" : "Show Island"
        let showHideItem = NSMenuItem(title: showHideTitle, action: showHideAction, keyEquivalent: "")
        showHideItem.target = target
        menu.addItem(showHideItem)

        if previewMotionControls.isEmpty == false {
            let previewMenu = NSMenu(title: "Preview Motion")
            for control in previewMotionControls {
                let previewItem = NSMenuItem(
                    title: control.menuTitle,
                    action: previewMotionAction,
                    keyEquivalent: ""
                )
                previewItem.target = target
                previewItem.representedObject = control.rawValue
                previewMenu.addItem(previewItem)
            }

            let previewRootItem = NSMenuItem(title: "Preview Motion", action: nil, keyEquivalent: "")
            previewRootItem.submenu = previewMenu
            menu.addItem(previewRootItem)
        }

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
