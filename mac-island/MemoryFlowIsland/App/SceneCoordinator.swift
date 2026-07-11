import AppKit

protocol IslandWindowControlling: AnyObject {
    var onLoginRequested: (() -> Void)? { get set }
    func show()
    func hide()
    func applyAuthenticatedUser(_ user: AuthenticatedUser)
    func applyLoggedOutState()
    func applyReviewSnapshot(_ snapshot: ReviewSnapshot)
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
    let desktopLoginCoordinator: DesktopLoginCoordinating
    let reviewRepository: ReviewRepositoryProtocol

    init() {
        let windowController = IslandWindowController(initialPhase5PreviewState: .loggedOutCompact)
        let preferencesWindowController = PreferencesWindowController()
        let sessionStore = KeychainAuthSessionStore()
        let apiBaseURL = URL(string: ProcessInfo.processInfo.environment["MEMORYFLOW_API_BASE_URL"] ?? "http://127.0.0.1:8080")!
        let apiClient = try! APIClient(
            baseURL: apiBaseURL,
            tokenProvider: sessionStore,
            sessionStore: sessionStore
        )
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        let reviewRepository = ReviewRepository(apiClient: apiClient)
        self.reviewRepository = reviewRepository
        let authCoordinator = AuthCoordinator(
            apiClient: apiClient,
            sessionStore: sessionStore,
            onAuthStateChanged: { [weak windowController] state in
                if state == .loggedOut {
                    windowController?.applyLoggedOutState()
                }
            },
            onUserChanged: { [weak windowController] user in
                if let user {
                    windowController?.applyAuthenticatedUser(user)
                    Task { [weak windowController, weak reviewRepository] in
                        guard let snapshot = try? await reviewRepository?.fetchSummary() else { return }
                        await MainActor.run { windowController?.applyReviewSnapshot(snapshot) }
                    }
                }
            }
        )
        self.authCoordinator = authCoordinator
        self.desktopLoginCoordinator = DesktopLoginCoordinator(
            webBaseURL: URL(string: ProcessInfo.processInfo.environment["MEMORYFLOW_WEB_BASE_URL"] ?? "https://memoryflow.tanxhub.com")!,
            sessionStore: sessionStore,
            authCoordinator: authCoordinator
        )
        let desktopLoginCoordinator = self.desktopLoginCoordinator
        windowController.onLoginRequested = { [weak desktopLoginCoordinator] in
            _ = desktopLoginCoordinator?.openLogin()
        }
        self.menuBarController = StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController,
            logoutHandler: { [weak authCoordinator] in
                Task { await authCoordinator?.logout() }
            }
        )
    }

    init(
        windowController: IslandWindowControlling,
        preferencesWindowController: PreferencesWindowControlling,
        menuBarController: MenuBarControlling? = nil,
        authCoordinator: AuthCoordinating? = nil,
        desktopLoginCoordinator: DesktopLoginCoordinating? = nil,
        reviewRepository: ReviewRepositoryProtocol? = nil
    ) {
        self.windowController = windowController
        self.preferencesWindowController = preferencesWindowController
        let resolvedAuthCoordinator: AuthCoordinating
        let resolvedSessionStore: AuthSessionStoring
        if let authCoordinator {
            resolvedAuthCoordinator = authCoordinator
            resolvedSessionStore = InMemoryAuthSessionStore()
        } else {
            let sessionStore = InMemoryAuthSessionStore()
            let apiClient = try! APIClient(
                baseURL: URL(string: "http://127.0.0.1:8080")!,
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
        self.desktopLoginCoordinator = desktopLoginCoordinator ?? DesktopLoginCoordinator(
            webBaseURL: URL(string: "https://memoryflow.tanxhub.com")!,
            sessionStore: resolvedSessionStore,
            authCoordinator: resolvedAuthCoordinator
        )
        self.windowController.onLoginRequested = { [weak desktopLoginCoordinator = self.desktopLoginCoordinator] in
            _ = desktopLoginCoordinator?.openLogin()
        }
        self.menuBarController = menuBarController ?? StatusBarController(
            windowController: windowController,
            preferencesWindowController: preferencesWindowController
        )
    }

    func start() {
        menuBarController.install()
        windowController.show()
        Task { [weak authCoordinator] in
            _ = try? await authCoordinator?.restoreAndVerifySession()
        }
    }

    func stop() {
        windowController.hide()
        menuBarController.uninstall()
    }

    func handleIncomingURL(_ url: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let user = try await desktopLoginCoordinator.handleCallback(url)
                await MainActor.run { windowController.applyAuthenticatedUser(user) }
            } catch DesktopLoginCallbackError.duplicate {
                return
            } catch {
                await MainActor.run { windowController.applyLoggedOutState() }
            }
        }
    }
}
