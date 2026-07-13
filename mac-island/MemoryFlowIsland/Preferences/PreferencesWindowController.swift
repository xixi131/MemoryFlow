import AppKit
import SwiftUI

protocol PreferencesWindowControlling: AnyObject {
    func show()
}

final class PreferencesWindowController: NSWindowController, PreferencesWindowControlling {
    private let languageSettings: AppLanguageSettings
    private var languageObserver: NSObjectProtocol?

    init(
        languageSettings: AppLanguageSettings,
        advancedFeaturesSettings: AdvancedFeaturesSettings,
        accountState: SettingsAccountState,
        onLoginRequested: @escaping () -> Void,
        onLogoutRequested: @escaping () -> Void
    ) {
        self.languageSettings = languageSettings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = AppCopy.text(.settingsWindowTitle, language: languageSettings.language)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MemoryFlowPreferencesWindow")
        window.contentView = NSHostingView(
            rootView: PreferencesView(
                languageSettings: languageSettings,
                advancedFeaturesSettings: advancedFeaturesSettings,
                accountState: accountState,
                onLoginRequested: onLoginRequested,
                onLogoutRequested: onLogoutRequested
            )
        )

        super.init(window: window)
        shouldCascadeWindows = false
        languageObserver = NotificationCenter.default.addObserver(
            forName: AppLanguageSettings.didChangeNotification,
            object: languageSettings,
            queue: .main
        ) { [weak self] _ in
            self?.window?.title = AppCopy.text(.settingsWindowTitle, language: languageSettings.language)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
