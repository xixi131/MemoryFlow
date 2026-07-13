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

protocol AdvancedFeaturesPersisting: AnyObject {
    func loadAdvancedFeaturesEnabled() -> Bool
    func saveAdvancedFeaturesEnabled(_ isEnabled: Bool)
}

final class InMemoryAdvancedFeaturesStore: AdvancedFeaturesPersisting {
    private var isEnabled: Bool

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func loadAdvancedFeaturesEnabled() -> Bool { isEnabled }
    func saveAdvancedFeaturesEnabled(_ isEnabled: Bool) { self.isEnabled = isEnabled }
}

final class UserDefaultsAdvancedFeaturesStore: AdvancedFeaturesPersisting {
    static let key = "com.memoryflow.island.settings.advancedFeaturesEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAdvancedFeaturesEnabled() -> Bool {
        defaults.bool(forKey: Self.key)
    }

    func saveAdvancedFeaturesEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.key)
    }
}

final class AdvancedFeaturesSettings: ObservableObject {
    static let didChangeNotification = Notification.Name("com.memoryflow.island.settings.advancedFeaturesDidChange")

    @Published private(set) var isEnabled: Bool
    private let store: AdvancedFeaturesPersisting

    init(store: AdvancedFeaturesPersisting = UserDefaultsAdvancedFeaturesStore()) {
        self.store = store
        isEnabled = store.loadAdvancedFeaturesEnabled()
    }

    func setEnabled(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else { return }
        self.isEnabled = isEnabled
        store.saveAdvancedFeaturesEnabled(isEnabled)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

struct AdvancedCapabilityPolicy: Equatable {
    let advancedFeaturesEnabled: Bool

    var allowsAuthentication: Bool { advancedFeaturesEnabled }
    var allowsProtectedStudyData: Bool { advancedFeaturesEnabled }
    var allowsMusic: Bool { true }
    var allowsUpdates: Bool { true }
}

final class SettingsAccountState: ObservableObject {
    @Published private(set) var user: AuthenticatedUser?

    func apply(_ user: AuthenticatedUser?) {
        self.user = user
    }
}

enum PreferencesAccountPresentation: Equatable {
    case hidden
    case loggedOut
    case loggedIn(email: String)

    static func resolve(advancedFeaturesEnabled: Bool, user: AuthenticatedUser?) -> Self {
        guard advancedFeaturesEnabled else { return .hidden }
        guard let user else { return .loggedOut }
        return .loggedIn(email: user.email)
    }
}

enum AppCopy {
    enum Key: CaseIterable {
        case menuBarTooltip
        case showIsland
        case hideIsland
        case phase5Scenarios
        case settings
        case settingsWindowTitle
        case quit
        case account
        case advancedFeatures
        case advancedFeaturesDescription
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
        .settings: "Settings...",
        .settingsWindowTitle: "MemoryFlow Settings",
        .quit: "Quit",
        .account: "Account",
        .advancedFeatures: "Advanced Features",
        .advancedFeaturesDescription: "Enable account-based review, todo, and reminder features.",
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
        .settings: "设置...",
        .settingsWindowTitle: "MemoryFlow 设置",
        .quit: "退出",
        .account: "账号",
        .advancedFeatures: "高级功能",
        .advancedFeaturesDescription: "启用需要账号的复习、待办和提醒功能。",
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
