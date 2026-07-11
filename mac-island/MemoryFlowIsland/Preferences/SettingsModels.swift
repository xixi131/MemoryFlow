import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    var id: String { rawValue }
}

protocol AppLanguagePersisting: AnyObject {
    func loadLanguageIdentifier() -> String?
    func saveLanguageIdentifier(_ identifier: String)
}

final class UserDefaultsAppLanguageStore: AppLanguagePersisting {
    private let defaults: UserDefaults
    private let key = "com.memoryflow.island.settings.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLanguageIdentifier() -> String? {
        defaults.string(forKey: key)
    }

    func saveLanguageIdentifier(_ identifier: String) {
        defaults.set(identifier, forKey: key)
    }
}

final class AppLanguageSettings: ObservableObject {
    static let didChangeNotification = Notification.Name("com.memoryflow.island.settings.languageDidChange")

    @Published private(set) var language: AppLanguage
    private let store: AppLanguagePersisting

    init(store: AppLanguagePersisting = UserDefaultsAppLanguageStore()) {
        self.store = store
        language = AppLanguage(rawValue: store.loadLanguageIdentifier() ?? "") ?? .english
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        store.saveLanguageIdentifier(language.rawValue)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

final class SettingsAccountState: ObservableObject {
    @Published private(set) var user: AuthenticatedUser?

    func apply(_ user: AuthenticatedUser?) {
        self.user = user
    }
}

enum AppCopy {
    enum Key: CaseIterable {
        case menuBarTooltip
        case showIsland
        case hideIsland
        case phase5Scenarios
        case phase5Interactions
        case settings
        case settingsWindowTitle
        case quit
        case account
        case language
        case languageDescription
        case english
        case simplifiedChinese
        case signedInAs
        case notSignedIn
        case signIn
        case signOut
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key]!
        case .simplifiedChinese:
            return simplifiedChinese[key]!
        }
    }

    private static let english: [Key: String] = [
        .menuBarTooltip: "MemoryFlow Island",
        .showIsland: "Show Island",
        .hideIsland: "Hide Island",
        .phase5Scenarios: "Phase 5 Scenarios",
        .phase5Interactions: "Phase 5 Interactions",
        .settings: "Settings...",
        .settingsWindowTitle: "MemoryFlow Settings",
        .quit: "Quit",
        .account: "Account",
        .language: "Language",
        .languageDescription: "Choose the language used by menu bar controls and settings.",
        .english: "English",
        .simplifiedChinese: "Simplified Chinese",
        .signedInAs: "Signed in as",
        .notSignedIn: "Not signed in",
        .signIn: "Sign In",
        .signOut: "Sign Out"
    ]

    private static let simplifiedChinese: [Key: String] = [
        .menuBarTooltip: "MemoryFlow 灵动岛",
        .showIsland: "显示灵动岛",
        .hideIsland: "隐藏灵动岛",
        .phase5Scenarios: "第五阶段场景",
        .phase5Interactions: "第五阶段交互",
        .settings: "设置...",
        .settingsWindowTitle: "MemoryFlow 设置",
        .quit: "退出",
        .account: "账号",
        .language: "语言",
        .languageDescription: "选择菜单栏控制项和设置页面使用的语言。",
        .english: "英文",
        .simplifiedChinese: "简体中文",
        .signedInAs: "当前登录账号",
        .notSignedIn: "尚未登录",
        .signIn: "登录",
        .signOut: "退出登录"
    ]
}
