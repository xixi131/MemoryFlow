import AppKit
import Combine

private enum MemoryFlowRuntimeEndpoints {
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["MEMORYFLOW_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://memoryflow.tanxhub.com")!
    }

    static var webBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["MEMORYFLOW_WEB_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://memoryflow.tanxhub.com")!
    }
}

protocol IslandWindowControlling: AnyObject {
    var onLoginRequested: (() -> Void)? { get set }
    var onTodoCompletionRequested: ((Int64) -> Void)? { get set }
    var onTodoModeActivityChanged: ((Bool) -> Void)? { get set }
    var onUpdateRequested: (() -> Void)? { get set }
    var onUpdateLaterRequested: (() -> Void)? { get set }
    func show()
    func hide()
    func applyAuthenticatedUser(_ user: AuthenticatedUser)
    func applyLoggedOutState()
    func applyBasicCapabilityState()
    func setAdvancedFeaturesEnabled(_ isEnabled: Bool)
    func presentUpdatePrompt(version: String, build: String)
    func applyUpdateDownloadProgress(_ progress: UpdateDownloadProgress)
    func endUpdateDownloadActivity()
    func applyReviewSnapshot(_ snapshot: ReviewSnapshot)
    func applyTodoSnapshot(_ snapshot: TodoSnapshot)
}

@MainActor
final class TodoLiveSyncOrchestrator {
    private let pollingController: TodoPollingController
    private var capabilityEnabled = false
    private var authenticated = false
    private var todoModeActive = false

    init(pollingController: TodoPollingController) {
        self.pollingController = pollingController
    }

    func setCapabilityEnabled(_ isEnabled: Bool) {
        guard capabilityEnabled != isEnabled else { return }
        capabilityEnabled = isEnabled
        synchronizePolling()
    }

    func setAuthenticated(_ isAuthenticated: Bool) {
        guard authenticated != isAuthenticated else { return }
        authenticated = isAuthenticated
        synchronizePolling()
    }

    func setTodoModeActive(_ isActive: Bool) {
        guard todoModeActive != isActive else { return }
        todoModeActive = isActive
        guard pollingController.isRunning else { return }
        pollingController.setCadence(resolvedCadence)
        if isActive {
            pollingController.refresh()
        }
    }

    func refreshForApplicationActivation() {
        pollingController.refresh()
    }

    func refreshForWake() {
        pollingController.refresh()
    }

    func acceptCompletionRefresh(_ snapshot: TodoSnapshot) {
        pollingController.acceptRefreshedSnapshot(snapshot)
    }

    func stop() {
        capabilityEnabled = false
        authenticated = false
        pollingController.stop()
    }

    private var resolvedCadence: TodoPollingController.Cadence {
        todoModeActive ? .activeTodo : .background
    }

    private func synchronizePolling() {
        guard capabilityEnabled, authenticated else {
            pollingController.stop()
            return
        }
        pollingController.start(cadence: resolvedCadence)
    }
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
    private var applicationActivationObserver: NSObjectProtocol?
    private var workspaceWakeObserver: NSObjectProtocol?
    private var capabilityGeneration = 0
    let authCoordinator: AuthCoordinating
    let desktopLoginCoordinator: DesktopLoginCoordinating
    let reviewRepository: ReviewRepositoryProtocol
    let reviewPollingController: ReviewPollingController
    let todoRepository: TodoRepositoryProtocol
    let todoPollingController: TodoPollingController
    let todoMutationController: TodoMutationController
    private let todoLiveSyncOrchestrator: TodoLiveSyncOrchestrator
    private let updateCheckPolicy: UpdateCheckPolicy
    private let updateCoordinator: UpdateCoordinator
    private var updateStateCancellable: AnyCancellable?

    init() {
        let windowController = IslandWindowController(initialPhase5PreviewState: .loggedOutCompact)
        let languageSettings = AppLanguageSettings()
        let advancedFeaturesSettings = AdvancedFeaturesSettings()
        let settingsAccountState = SettingsAccountState()
        let updateCoordinator = UpdateCoordinator(engine: SparkleUpdateAdapter())
        self.updateCoordinator = updateCoordinator
        let updateCheckPolicy = UpdateCheckPolicy(coordinator: updateCoordinator)
        self.updateCheckPolicy = updateCheckPolicy
        let sessionStore = DefaultAuthSessionStore.make()
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
        let todoLiveSyncOrchestrator = TodoLiveSyncOrchestrator(pollingController: todoPollingController)
        self.todoLiveSyncOrchestrator = todoLiveSyncOrchestrator
        let lifecycleHooks = AuthLifecycleHooks()
        lifecycleHooks.onCancelAuthenticatedWork = { [weak reviewPollingController, weak todoLiveSyncOrchestrator, weak todoMutationController] in
            Task { @MainActor in
                reviewPollingController?.stop()
                todoLiveSyncOrchestrator?.setAuthenticated(false)
                todoMutationController?.cancelAll()
            }
        }
        let authCoordinator = AuthCoordinator(
            apiClient: apiClient,
            sessionStore: sessionStore,
            onAuthStateChanged: { [weak windowController, weak settingsAccountState, weak advancedFeaturesSettings, weak todoLiveSyncOrchestrator] state in
                guard advancedFeaturesSettings?.isEnabled == true else { return }
                if state == .loggedOut {
                    settingsAccountState?.apply(nil)
                    reviewPollingController.stop()
                    todoLiveSyncOrchestrator?.setAuthenticated(false)
                    windowController?.applyLoggedOutState()
                }
            },
            onUserChanged: { [weak windowController, weak settingsAccountState, weak advancedFeaturesSettings, weak todoLiveSyncOrchestrator] user in
                guard advancedFeaturesSettings?.isEnabled == true else { return }
                settingsAccountState?.apply(user)
                todoLiveSyncOrchestrator?.setAuthenticated(user != nil)
                if let user {
                    windowController?.applyAuthenticatedUser(user)
                    reviewPollingController.start()
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
        todoMutationController.onCompletionSucceeded = { [weak todoLiveSyncOrchestrator] snapshot in
            todoLiveSyncOrchestrator?.acceptCompletionRefresh(snapshot)
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
            updateCoordinator: updateCoordinator,
            onLoginRequested: { [weak desktopLoginCoordinator] in
                _ = desktopLoginCoordinator?.openLogin()
            },
            onLogoutRequested: { [weak authCoordinator] in
                Task { await authCoordinator?.logout() }
            },
            onUpdateCommand: { command in
                switch command {
                case .check:
                    updateCheckPolicy.manualCheck()
                case .retry:
                    _ = updateCoordinator.retryFailure()
                case .update:
                    updateCheckPolicy.clearDeferral()
                    _ = updateCoordinator.requestAvailableUpdate()
                }
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
        windowController.onTodoModeActivityChanged = { [weak todoLiveSyncOrchestrator] isActive in
            todoLiveSyncOrchestrator?.setTodoModeActive(isActive)
        }
        self.menuBarController = StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController,
            languageSettings: languageSettings,
            logoutHandler: { [weak authCoordinator] in
                Task { await authCoordinator?.logout() }
            }
        )
        configureUpdatePromptBridge()
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
        let updateCoordinator = UpdateCoordinator(engine: SparkleUpdateAdapter())
        self.updateCoordinator = updateCoordinator
        self.updateCheckPolicy = UpdateCheckPolicy(coordinator: updateCoordinator)
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
        self.todoLiveSyncOrchestrator = TodoLiveSyncOrchestrator(
            pollingController: self.todoPollingController
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
        self.windowController.onTodoModeActivityChanged = { [weak todoLiveSyncOrchestrator = self.todoLiveSyncOrchestrator] isActive in
            todoLiveSyncOrchestrator?.setTodoModeActive(isActive)
        }
        self.todoMutationController.onCompletionSucceeded = { [weak todoLiveSyncOrchestrator = self.todoLiveSyncOrchestrator] snapshot in
            todoLiveSyncOrchestrator?.acceptCompletionRefresh(snapshot)
        }
        self.menuBarController = menuBarController ?? StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController,
            languageSettings: languageSettings
        )
        configureUpdatePromptBridge()
    }

    func start() {
        menuBarController.install()
        windowController.show()
        if let scenarioID = ProcessInfo.processInfo.environment["MEMORYFLOW_ISLAND_INITIAL_SCENARIO"],
           let scenarioController = windowController as? IslandPhase5ScenarioControlling {
            scenarioController.selectPhase5Scenario(id: scenarioID)
            return
        }
        advancedFeaturesObserver = NotificationCenter.default.addObserver(
            forName: AdvancedFeaturesSettings.didChangeNotification,
            object: advancedFeaturesSettings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyCapabilityPolicy() }
        }
        applicationActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.todoLiveSyncOrchestrator.refreshForApplicationActivation() }
        }
        workspaceWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.todoLiveSyncOrchestrator.refreshForWake() }
        }
        applyCapabilityPolicy()
        updateCheckPolicy.start()
    }

    func stop() {
        reviewPollingController.stop()
        todoLiveSyncOrchestrator.stop()
        todoMutationController.cancelAll()
        updateCheckPolicy.stop()
        capabilityGeneration += 1
        if let advancedFeaturesObserver {
            NotificationCenter.default.removeObserver(advancedFeaturesObserver)
            self.advancedFeaturesObserver = nil
        }
        if let applicationActivationObserver {
            NotificationCenter.default.removeObserver(applicationActivationObserver)
            self.applicationActivationObserver = nil
        }
        if let workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceWakeObserver)
            self.workspaceWakeObserver = nil
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
                await MainActor.run {
                    self.todoLiveSyncOrchestrator.setAuthenticated(true)
                    self.windowController.applyAuthenticatedUser(user)
                }
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
        windowController.setAdvancedFeaturesEnabled(policy.allowsAuthentication)
        todoLiveSyncOrchestrator.setCapabilityEnabled(policy.allowsProtectedStudyData)

        guard policy.allowsProtectedStudyData else {
            reviewPollingController.stop()
            todoMutationController.cancelAll()
            settingsAccountState.apply(nil)
            windowController.applyBasicCapabilityState()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let restoredUser = try? await authCoordinator.restoreAndVerifySession()
            guard generation == capabilityGeneration,
                  advancedFeaturesSettings.isEnabled else { return }
            todoLiveSyncOrchestrator.setAuthenticated(restoredUser != nil)
            if restoredUser != nil {
                reviewPollingController.start()
            }
        }
    }

    private func configureUpdatePromptBridge() {
        windowController.onUpdateRequested = { [weak self] in
            guard let self else { return }
            self.updateCheckPolicy.clearDeferral()
            _ = self.updateCoordinator.requestAvailableUpdate()
        }
        windowController.onUpdateLaterRequested = { [weak self] in
            guard let self,
                  case .available(let release) = self.updateCoordinator.state else { return }
            let until = self.updateCheckPolicy.deferVersion(release.build)
            _ = self.updateCoordinator.deferAvailableUpdate(until: until)
        }
        updateStateCancellable = updateCoordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
            guard let self else { return }
            switch state {
            case .available(let release):
                self.updateCheckPolicy.clearDeferralIfSuperseded(by: release.build)
                guard self.updateCheckPolicy.shouldPresent(version: release.build) else {
                    if self.updateCheckPolicy.wasInstalled(build: release.build) {
                        _ = self.updateCoordinator.discardAvailableUpdate()
                    } else if let until = self.updateCheckPolicy.suppressionUntil(version: release.build) {
                        _ = self.updateCoordinator.deferAvailableUpdate(until: until)
                    }
                    return
                }
                self.windowController.presentUpdatePrompt(version: release.version, build: release.build)
            case .downloading(_, let progress):
                self.windowController.applyUpdateDownloadProgress(progress)
            case .ready:
                self.windowController.endUpdateDownloadActivity()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(
                        for: .seconds(IslandMotionTokens.activityCollapseDuration)
                    )
                    _ = self?.updateCoordinator.installReadyUpdate()
                }
            case .failed:
                self.windowController.endUpdateDownloadActivity()
            case .installed(let release, _):
                self.updateCheckPolicy.markInstalled(build: release.build)
                self.windowController.endUpdateDownloadActivity()
            case .idle, .checking, .deferred, .downloadRequested, .verifying,
                 .awaitingAuthorization, .installing:
                break
            }
            }
    }
}
