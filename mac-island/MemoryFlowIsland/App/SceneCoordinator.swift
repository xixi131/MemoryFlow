import AppKit

protocol IslandWindowControlling {
    func show()
    func hide()
}

protocol MenuBarControlling {
    func install()
    func uninstall()
}

final class SceneCoordinator {
    private let windowController: IslandWindowControlling
    private let preferencesWindowController: PreferencesWindowControlling
    private let menuBarController: MenuBarControlling
    let authCoordinator: AuthCoordinating

    init() {
        let windowController = IslandWindowController()
        let preferencesWindowController = PreferencesWindowController()
        let sessionStore = KeychainAuthSessionStore()
        let apiBaseURL = URL(string: ProcessInfo.processInfo.environment["MEMORYFLOW_API_BASE_URL"] ?? "http://127.0.0.1:8080")!
        let apiClient = try! APIClient(baseURL: apiBaseURL, tokenProvider: sessionStore)
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        self.authCoordinator = AuthCoordinator(
            apiClient: apiClient,
            sessionStore: sessionStore,
            onAuthStateChanged: { _ in
                // UI state integration is intentionally callback-based; tokens remain in Keychain.
            },
            onUserChanged: { _ in }
        )
        self.menuBarController = StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController
        )
    }

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        menuBarController: MenuBarControlling? = nil,
        authCoordinator: AuthCoordinating? = nil
    ) {
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        if let authCoordinator {
            self.authCoordinator = authCoordinator
        } else {
            let sessionStore = InMemoryAuthSessionStore()
            let apiClient = try! APIClient(
                baseURL: URL(string: "http://127.0.0.1:8080")!,
                tokenProvider: sessionStore
            )
            self.authCoordinator = AuthCoordinator(apiClient: apiClient, sessionStore: sessionStore)
        }
        self.menuBarController = menuBarController ?? StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController
        )
    }

    func start() {
        menuBarController.install()
        windowController.show()
    }

    func stop() {
        windowController.hide()
        menuBarController.uninstall()
    }
}
