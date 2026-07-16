import AppKit
import SwiftUI

@main
struct MemoryFlowIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var isMenuBarExtraInserted = true

    @SceneBuilder
    var body: some Scene {
        Settings {
            EmptyView()
        }

        if #available(macOS 26.0, *) {
            MenuBarExtra(isInserted: $isMenuBarExtraInserted) {
                Button(toggleIslandTitle) {
                    appDelegate.toggleIslandFromMenuBar()
                }

                Button(AppCopy.text(.settings, language: menuLanguage)) {
                    appDelegate.showSettingsFromMenuBar()
                }
                .keyboardShortcut(",")

                Button(AppCopy.text(.signOut, language: menuLanguage)) {
                    appDelegate.logoutFromMenuBar()
                }

                Divider()

                Button(AppCopy.text(.quit, language: menuLanguage)) {
                    appDelegate.quitFromMenuBar()
                }
                .keyboardShortcut("q")
            } label: {
                Image(nsImage: menuBarIcon)
                    .accessibilityLabel(AppCopy.text(.menuBarTooltip, language: menuLanguage))
            }
            .menuBarExtraStyle(.menu)
        }
    }

    private var menuLanguage: AppLanguage {
        appDelegate.menuBarState.language
    }

    private var menuBarIcon: NSImage {
        guard let source = NSImage(named: "MemoryFlowStatusBarIcon"),
              let icon = source.copy() as? NSImage else {
            return NSImage(size: NSSize(width: 18, height: 18))
        }
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = true
        return icon
    }

    private var toggleIslandTitle: String {
        AppCopy.text(
            appDelegate.menuBarState.isIslandVisible ? .hideIsland : .showIsland,
            language: menuLanguage
        )
    }
}
