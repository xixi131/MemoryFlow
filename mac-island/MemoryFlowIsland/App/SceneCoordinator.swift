import AppKit

private enum MemoryFlowRuntimeEndpoints {
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["MEMORYFLOW_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
#if DEBUG
        return URL(string: "http://127.0.0.1:8080")!
#else
        return URL(string: "https://memoryflow.tanxhub.com")!
#endif
    }

    static var webBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["MEMORYFLOW_WEB_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
#if DEBUG
        return URL(string: "http://127.0.0.1:3101")!
#else
        return URL(string: "https://memoryflow.tanxhub.com")!
#endif
    }
}

protocol IslandWindowControlling: AnyObject {
    var onLoginRequested: (() -> Void)? { get set }
    var onTodoCompletionRequested: ((Int64) -> Void)? { get set }
    func show()
    func hide()
    func applyAuthenticatedUser(_ user: AuthenticatedUser)
    func applyLoggedOutState()
    func applyBasicCapabilityState()
    func applyReviewSnapshot(_ snapshot: ReviewSnapshot)
    func applyTodoSnapshot(_ snapshot: TodoSnapshot)
}

protocol MenuBarControlling {
    func install()
    func uninstall()
}

@MainActor
final class SceneCoordinator {
    private let windowController: IslandWindowControlling
    private let preferencesWindowController: PreferencesWindowControlling
    private let menuBarController: MenuBarControlling
    private let languageSettings: AppLanguageSettings
    private let advancedFeaturesSettings: AdvancedFeaturesSettings
    private let settingsAccountState: SettingsAccountState
    private var advancedFeaturesObserver: NSObjectProtocol?
    private var capabilityGeneration = 0
    let authCoordinator: AuthCoordinating
    let desktopLoginCoordinator: DesktopLoginCoordinating
    let reviewRepository: ReviewRepositoryProtocol
    let reviewPollingController: ReviewPollingController
    let todoRepository: TodoRepositoryProtocol
    let todoPollingController: TodoPollingController
    let todoMutationController: TodoMutationController

    init() {
        let windowController = IslandWindowController(initialPhase5PreviewState: .loggedOutCompact)
        let languageSettings = AppLanguageSettings()
        let advancedFeaturesSettings = AdvancedFeaturesSettings()
        let settingsAccountState = SettingsAccountState()
        let sessionStore = KeychainAuthSessionStore()
        let apiClient = try! APIClient(
            baseURL: MemoryFlowRuntimeEndpoints.apiBaseURL,
            tokenProvider: sessionStore,
            sessionStore: sessionStore
        )
        self.windowController = windowController
        self.languageSettings = languageSettings
        self.advancedFeaturesSettings = advancedFeaturesSettings
        self.settingsAccountState = settingsAccountState
        let reviewRepository = ReviewRepository(apiClient: apiClient)
        self.reviewRepository = reviewRepository
        let reviewPollingController = ReviewPollingController(
            repository: reviewRepository,
            onSnapshot: { [weak windowController] snapshot in
                windowController?.applyReviewSnapshot(snapshot)
            }
        )
        self.reviewPollingController = reviewPollingController
        let todoRepository = TodoRepository(apiClient: apiClient)
        self.todoRepository = todoRepository
        let todoMutationController = TodoMutationController(
            repository: todoRepository,
            onSnapshot: { [weak windowController] snapshot in
                windowController?.applyTodoSnapshot(snapshot)
            }
        )
        self.todoMutationController = todoMutationController
        let todoPollingController = TodoPollingController(
            repository: todoRepository,
            onSnapshot: { [weak todoMutationController] snapshot in todoMutationController?.acceptSnapshot(snapshot) }
        )
        self.todoPollingController = todoPollingController
        let lifecycleHooks = AuthLifecycleHooks()
        lifecycleHooks.onCancelAuthenticatedWork = { [weak reviewPollingController, weak todoPollingController, weak todoMutationController] in
            Task { @MainActor in
                reviewPollingController?.stop()
                todoPollingController?.stop()
                todoMutationController?.cancelAll()
            }
        }
        let authCoordinator = AuthCoordinator(
            apiClient: apiClient,
            sessionStore: sessionStore,
            onAuthStateChanged: { [weak windowController, weak settingsAccountState, weak advancedFeaturesSettings] state in
                guard advancedFeaturesSettings?.isEnabled == true else { return }
                if state == .loggedOut {
                    settingsAccountState?.apply(nil)
                    reviewPollingController.stop()
                    todoPollingController.stop()
                    windowController?.applyLoggedOutState()
                }
            },
            onUserChanged: { [weak windowController, weak settingsAccountState, weak advancedFeaturesSettings] user in
                guard advancedFeaturesSettings?.isEnabled == true else { return }
                settingsAccountState?.apply(user)
                if let user {
                    windowController?.applyAuthenticatedUser(user)
                    reviewPollingController.start()
                    todoPollingController.start()
                }
            },
            lifecycleCleaner: lifecycleHooks
        )
        reviewPollingController.onAuthenticationInvalidated = { [weak authCoordinator] in
            Task { await authCoordinator?.logout() }
        }
        todoPollingController.onAuthenticationInvalidated = { [weak authCoordinator] in
            Task { await authCoordinator?.logout() }
        }
        todoMutationController.onAuthenticationInvalidated = { [weak authCoordinator] in
            Task { await authCoordinator?.logout() }
        }
        self.authCoordinator = authCoordinator
        self.desktopLoginCoordinator = DesktopLoginCoordinator(
            webBaseURL: MemoryFlowRuntimeEndpoints.webBaseURL,
            sessionStore: sessionStore,
            authCoordinator: authCoordinator
        )
        let desktopLoginCoordinator = self.desktopLoginCoordinator
        let preferencesWindowController = PreferencesWindowController(
            languageSettings: languageSettings,
            advancedFeaturesSettings: advancedFeaturesSettings,
            accountState: settingsAccountState,
            onLoginRequested: { [weak desktopLoginCoordinator] in
                _ = desktopLoginCoordinator?.openLogin()
            },
            onLogoutRequested: { [weak authCoordinator] in
                Task { await authCoordinator?.logout() }
            }
        )
        self.preferencesWindowController = preferencesWindowController
        windowController.onLoginRequested = { [weak desktopLoginCoordinator, weak advancedFeaturesSettings] in
            guard advancedFeaturesSettings?.isEnabled == true else { return }
            _ = desktopLoginCoordinator?.openLogin()
        }
        windowController.onTodoCompletionRequested = { [weak todoMutationController, weak advancedFeaturesSettings] taskID in
            guard advancedFeaturesSettings?.isEnabled == true else { return }
            todoMutationController?.complete(taskID: taskID)
        }
        self.menuBarController = StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController,
            languageSettings: languageSettings,
            logoutHandler: { [weak authCoordinator] in
                Task { await authCoordinator?.logout() }
            }
        )
    }

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        menuBarController: MenuBarControlling? = nil,
        languageSettings: AppLanguageSettings = AppLanguageSettings(),
        authCoordinator: AuthCoordinating? = nil,
        desktopLoginCoordinator: DesktopLoginCoordinating? = nil,
        reviewRepository: ReviewRepositoryProtocol? = nil
    ) {
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        self.languageSettings = languageSettings
        self.advancedFeaturesSettings = AdvancedFeaturesSettings(store: InMemoryAdvancedFeaturesStore(isEnabled: true))
        self.settingsAccountState = SettingsAccountState()
        let resolvedAuthCoordinator: AuthCoordinating
        let resolvedSessionStore: AuthSessionStoring
        if let authCoordinator {
            resolvedAuthCoordinator = authCoordinator
            resolvedSessionStore = InMemoryAuthSessionStore()
        } else {
            let sessionStore = InMemoryAuthSessionStore()
            let apiClient = try! APIClient(
                baseURL: MemoryFlowRuntimeEndpoints.apiBaseURL,
                tokenProvider: sessionStore,
                sessionStore: sessionStore
            )
            resolvedSessionStore = sessionStore
            resolvedAuthCoordinator = AuthCoordinator(apiClient: apiClient, sessionStore: sessionStore)
        }
        self.authCoordinator = resolvedAuthCoordinator
        self.reviewRepository = reviewRepository ?? ReviewRepository(
            apiClient: resolvedAuthCoordinator.authenticatedAPIClient
        )
        self.reviewPollingController = ReviewPollingController(
            repository: self.reviewRepository,
            onSnapshot: { [weak windowController] snapshot in
                windowController?.applyReviewSnapshot(snapshot)
            }
        )
        self.todoRepository = TodoRepository(apiClient: resolvedAuthCoordinator.authenticatedAPIClient)
        self.todoMutationController = TodoMutationController(
            repository: self.todoRepository,
            onSnapshot: { [weak windowController] snapshot in windowController?.applyTodoSnapshot(snapshot) }
        )
        self.todoPollingController = TodoPollingController(
            repository: self.todoRepository,
            onSnapshot: { [weak todoMutationController = self.todoMutationController] snapshot in
                todoMutationController?.acceptSnapshot(snapshot)
            }
        )
        self.desktopLoginCoordinator = desktopLoginCoordinator ?? DesktopLoginCoordinator(
            webBaseURL: MemoryFlowRuntimeEndpoints.webBaseURL,
            sessionStore: resolvedSessionStore,
            authCoordinator: resolvedAuthCoordinator
        )
        self.windowController.onLoginRequested = { [weak desktopLoginCoordinator = self.desktopLoginCoordinator] in
            _ = desktopLoginCoordinator?.openLogin()
        }
        self.windowController.onTodoCompletionRequested = { [weak todoMutationController = self.todoMutationController] taskID in
            todoMutationController?.complete(taskID: taskID)
        }
        self.menuBarController = menuBarController ?? StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController,
            languageSettings: languageSettings
        )
    }

    func start() {
        menuBarController.install()
        windowController.show()
        Task { [weak authCoordinator] in
            _ = try? await authCoordinator?.restoreAndVerifySession()
        }
        advancedFeaturesObserver = NotificationCenter.default.addObserver(
            forName: AdvancedFeaturesSettings.didChangeNotification,
            object: advancedFeaturesSettings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyCapabilityPolicy() }
        }
        applyCapabilityPolicy()
    }

    func stop() {
        reviewPollingController.stop()
        todoPollingController.stop()
        todoMutationController.cancelAll()
        capabilityGeneration += 1
        if let advancedFeaturesObserver {
            NotificationCenter.default.removeObserver(advancedFeaturesObserver)
            self.advancedFeaturesObserver = nil
        }
        windowController.hide()
        menuBarController.uninstall()
    }

    func handleIncomingURL(_ url: URL) {
        Task { [weak self] in
            guard let self else { return }
            guard advancedFeaturesSettings.isEnabled else { return }
            do {
                let user = try await desktopLoginCoordinator.handleCallback(url)
                await MainActor.run { self.windowController.applyAuthenticatedUser(user) }
            } catch DesktopLoginCallbackError.duplicate {
                return
            } catch {
                await MainActor.run { self.windowController.applyLoggedOutState() }
            }
        }
    }

    private func applyCapabilityPolicy() {
        capabilityGeneration += 1
        let generation = capabilityGeneration
        let policy = AdvancedCapabilityPolicy(advancedFeaturesEnabled: advancedFeaturesSettings.isEnabled)

        guard policy.allowsProtectedStudyData else {
            reviewPollingController.stop()
            todoPollingController.stop()
            todoMutationController.cancelAll()
            settingsAccountState.apply(nil)
            windowController.applyBasicCapabilityState()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            _ = try? await authCoordinator.restoreAndVerifySession()
            guard generation == capabilityGeneration,
                  advancedFeaturesSettings.isEnabled else { return }
        }
    }
}
