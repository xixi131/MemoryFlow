import AppKit
import Foundation

enum SettingsAndMenuProbeError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

@MainActor
enum SettingsAndMenuProbe {
    static func run() throws -> String {
        let suiteName = "com.memoryflow.island.probe.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SettingsAndMenuProbeError.failed("Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = AdvancedFeaturesSettings(store: UserDefaultsAdvancedFeaturesStore(defaults: defaults))
        guard firstLaunch.isEnabled == false else {
            throw SettingsAndMenuProbeError.failed("Advanced Features did not default to disabled")
        }
        firstLaunch.setEnabled(true)
        let relaunched = AdvancedFeaturesSettings(store: UserDefaultsAdvancedFeaturesStore(defaults: defaults))
        guard relaunched.isEnabled else {
            throw SettingsAndMenuProbeError.failed("Advanced Features did not persist across relaunch")
        }

        let user = AuthenticatedUser(
            id: 7,
            email: "probe@memoryflow.test",
            nickname: "Probe",
            avatarUrl: nil,
            profession: nil,
            age: nil
        )
        guard PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: false, user: nil) == .hidden,
              PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: true, user: nil) == .loggedOut,
              PreferencesAccountPresentation.resolve(advancedFeaturesEnabled: true, user: user) == .loggedIn(email: user.email)
        else {
            throw SettingsAndMenuProbeError.failed("Settings account presentation states are incomplete")
        }

        let menu = StatusMenuBuilder().buildMenu(
            target: ProbeTarget(),
            isIslandVisible: true,
            language: .english,
            phase5Scenarios: [],
            showHideAction: #selector(ProbeTarget.action(_:)),
            phase5ScenarioAction: #selector(ProbeTarget.action(_:)),
            preferencesAction: #selector(ProbeTarget.action(_:)),
            logoutAction: #selector(ProbeTarget.action(_:)),
            quitAction: #selector(ProbeTarget.action(_:))
        )
        let titles = menu.items.map(\.title)
        guard titles.contains("Phase 5 Interactions") == false,
              titles.contains(AppCopy.text(.settings, language: .english)),
              titles.contains(AppCopy.text(.signOut, language: .english)),
              titles.contains(AppCopy.text(.quit, language: .english))
        else {
            throw SettingsAndMenuProbeError.failed("Status menu removal changed an unrelated command: \(titles)")
        }

        return "settings-menu-probe: PASS; default=disabled; persisted=enabled; states=hidden,logged-out,logged-in; interactions=absent; menu=preserved"
    }
}

private final class ProbeTarget: NSObject {
    @objc func action(_ sender: Any?) {}
}
