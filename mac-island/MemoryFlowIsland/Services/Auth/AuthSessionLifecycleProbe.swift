import Foundation

struct AuthSessionLifecycleProbeResult: Equatable {
    let startupVerified: Bool
    let staleLoggedOutSuppressed: Bool
    let concurrentRefreshCount: Int
    let failedRefreshClearedSession: Bool
    let offlineRestorePreservedSession: Bool
    let offlineLogoutClearedState: Bool
    let normalLogoutClearedState: Bool
}

enum AuthSessionLifecycleProbe {
    static func run() async throws -> AuthSessionLifecycleProbeResult {
        let validSession = AuthSession(
            accessToken: "old-access",
            refreshToken: "valid-refresh",
            expiresAt: Date().addingTimeInterval(60)
        )

        let startupStore = InMemoryAuthSessionStore(session: validSession)
        let startupTransport = LifecycleProbeTransport(mode: .valid)
        let startupAuth = try makeAuth(store: startupStore, transport: startupTransport)
        let startupVerified = try await startupAuth.restoreAndVerifySession()?.email == "lifecycle@memoryflow.example"

        let replacementStore = StartupReplacementSessionStore(replacementSession: validSession)
        let replacementTransport = LifecycleProbeTransport(mode: .offline)
        let replacementClient = try APIClient(
            baseURL: URL(string: "https://api.memoryflow.example")!,
            session: replacementTransport,
            tokenProvider: replacementStore,
            sessionStore: replacementStore
        )
        let replacementRecorder = LifecycleAuthStateRecorder()
        let replacementAuth = AuthCoordinator(
            apiClient: replacementClient,
            sessionStore: replacementStore,
            onAuthStateChanged: { state in replacementRecorder.states.append(state) }
        )
        _ = try await replacementAuth.restoreAndVerifySession()
        let replacementSessionWasPreserved = try replacementStore.load() == validSession
        let staleLoggedOutSuppressed = replacementRecorder.states.contains(.loggedOut) == false
            && replacementSessionWasPreserved

        let refreshStore = InMemoryAuthSessionStore(session: validSession)
        let refreshTransport = LifecycleProbeTransport(mode: .requiresRefresh)
        let refreshAuth = try makeAuth(store: refreshStore, transport: refreshTransport)
        async let first = refreshAuth.verifyCurrentSession()
        async let second = refreshAuth.verifyCurrentSession()
        _ = try await [first, second]
        let refreshCount = refreshTransport.refreshCount
        guard refreshCount == 1, try refreshStore.load()?.accessToken == "new-access" else {
            throw APIClientError.decodingFailed
        }

        let failedStore = InMemoryAuthSessionStore(session: validSession)
        let failedAuth = try makeAuth(
            store: failedStore,
            transport: LifecycleProbeTransport(mode: .failedRefresh)
        )
        _ = try await failedAuth.restoreAndVerifySession()
        let failedRefreshCleared = try failedStore.load() == nil

        let offlineStore = InMemoryAuthSessionStore(session: validSession)
        let offlineHooks = LifecycleProbeHooks()
        let offlineAuth = try makeAuth(
            store: offlineStore,
            transport: LifecycleProbeTransport(mode: .offline),
            hooks: offlineHooks
        )
        do { _ = try await offlineAuth.restoreAndVerifySession() } catch {}
        let offlinePreserved = try offlineStore.load() == validSession
        await offlineAuth.logout()
        let offlineLogoutCleared = try offlineStore.load() == nil && offlineHooks.didClean

        let logoutStore = InMemoryAuthSessionStore(session: validSession)
        let logoutHooks = LifecycleProbeHooks()
        let logoutTransport = LifecycleProbeTransport(mode: .valid)
        let logoutAuth = try makeAuth(store: logoutStore, transport: logoutTransport, hooks: logoutHooks)
        await logoutAuth.logout()
        let normalLogoutCleared = try logoutStore.load() == nil && logoutHooks.didClean && logoutTransport.logoutCount == 1

        return AuthSessionLifecycleProbeResult(
            startupVerified: startupVerified,
            staleLoggedOutSuppressed: staleLoggedOutSuppressed,
            concurrentRefreshCount: refreshCount,
            failedRefreshClearedSession: failedRefreshCleared,
            offlineRestorePreservedSession: offlinePreserved,
            offlineLogoutClearedState: offlineLogoutCleared,
            normalLogoutClearedState: normalLogoutCleared
        )
    }

    private static func makeAuth(
        store: InMemoryAuthSessionStore,
        transport: LifecycleProbeTransport,
        hooks: AuthLifecycleCleaning = AuthLifecycleHooks()
    ) throws -> AuthCoordinator {
        let client = try APIClient(
            baseURL: URL(string: "https://api.memoryflow.example")!,
            session: transport,
            tokenProvider: store,
            sessionStore: store
        )
        return AuthCoordinator(apiClient: client, sessionStore: store, lifecycleCleaner: hooks)
    }
}

private final class LifecycleAuthStateRecorder {
    var states: [AuthCoordinatorState] = []
}

private final class StartupReplacementSessionStore: AuthSessionStoring {
    private let lock = NSLock()
    private var session: AuthSession?
    private var shouldSimulateInitialMiss = true
    private let replacementSession: AuthSession

    init(replacementSession: AuthSession) {
        self.replacementSession = replacementSession
    }

    func load() throws -> AuthSession? {
        lock.withLock {
            if shouldSimulateInitialMiss {
                shouldSimulateInitialMiss = false
                session = replacementSession
                return nil
            }
            return session
        }
    }

    func save(_ session: AuthSession) throws {
        lock.withLock { self.session = session }
    }

    func clear() throws {
        lock.withLock { session = nil }
    }
}

private final class LifecycleProbeHooks: AuthLifecycleCleaning {
    private(set) var cancelled = false
    private(set) var cleared = false
    var didClean: Bool { cancelled && cleared }
    func cancelAuthenticatedWork() { cancelled = true }
    func clearAuthenticatedSnapshotsAndMutations() { cleared = true }
}

private final class LifecycleProbeTransport: URLSessioning {
    enum Mode { case valid, requiresRefresh, failedRefresh, offline }
    private let mode: Mode
    private let lock = NSLock()
    private var refreshCalls = 0
    private var logoutCalls = 0
    var refreshCount: Int { lock.withLock { refreshCalls } }
    var logoutCount: Int { lock.withLock { logoutCalls } }

    init(mode: Mode) { self.mode = mode }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if mode == .offline { throw URLError(.notConnectedToInternet) }
        let path = request.url!.path
        if path.hasSuffix("/auth/refresh") {
            lock.withLock { refreshCalls += 1 }
            if mode == .failedRefresh { return response(request, status: 401, json: "{}") }
            return response(request, json: envelope("{\"accessToken\":\"new-access\",\"refreshToken\":\"new-refresh\",\"expiresIn\":3600}"))
        }
        if path.hasSuffix("/auth/logout") {
            lock.withLock { logoutCalls += 1 }
            return response(request, json: "{\"code\":200,\"message\":\"success\",\"data\":null,\"timestamp\":1}")
        }
        if (mode == .requiresRefresh || mode == .failedRefresh),
           request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
            return response(request, status: 401, json: "{}")
        }
        return response(request, json: envelope("{\"id\":12,\"email\":\"lifecycle@memoryflow.example\",\"nickname\":\"Lifecycle\",\"avatarUrl\":null,\"profession\":null,\"age\":null}"))
    }

    private func envelope(_ data: String) -> String {
        "{\"code\":200,\"message\":\"success\",\"data\":\(data),\"timestamp\":1}"
    }

    private func response(_ request: URLRequest, status: Int = 200, json: String) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}
