import AppKit
import SwiftUI

protocol PreferencesWindowControlling: AnyObject {
    func show()
}

final class PreferencesWindowController: NSWindowController, PreferencesWindowControlling {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MemoryFlowPreferencesWindow")
        window.contentView = NSHostingView(rootView: PreferencesView())

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
