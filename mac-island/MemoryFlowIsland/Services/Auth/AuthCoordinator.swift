import Foundation

protocol AuthCoordinating: AnyObject {
    var authenticatedAPIClient: APIClient { get }
    func storedSession() throws -> AuthSession?
    func verifyCurrentSession() async throws -> AuthenticatedUser
    func restoreAndVerifySession() async throws -> AuthenticatedUser?
    func logout() async
}

protocol AuthLifecycleCleaning: AnyObject {
    func cancelAuthenticatedWork()
    func clearAuthenticatedSnapshotsAndMutations()
}

final class AuthLifecycleHooks: AuthLifecycleCleaning {
    var onCancelAuthenticatedWork: () -> Void = {}
    var onClearAuthenticatedSnapshotsAndMutations: () -> Void = {}

    func cancelAuthenticatedWork() { onCancelAuthenticatedWork() }
    func clearAuthenticatedSnapshotsAndMutations() { onClearAuthenticatedSnapshotsAndMutations() }
}

enum AuthCoordinatorState: Equatable {
    case loggedOut
    case authenticated
}

final class AuthCoordinator: AuthCoordinating {
    let authenticatedAPIClient: APIClient
    private let sessionStore: AuthSessionStoring
    private let onAuthStateChanged: @MainActor (AuthCoordinatorState) -> Void
    private let onUserChanged: @MainActor (AuthenticatedUser?) -> Void
    private let lifecycleCleaner: AuthLifecycleCleaning

    init(
        apiClient: APIClient,
        sessionStore: AuthSessionStoring,
        onAuthStateChanged: @escaping @MainActor (AuthCoordinatorState) -> Void = { _ in },
        onUserChanged: @escaping @MainActor (AuthenticatedUser?) -> Void = { _ in },
        lifecycleCleaner: AuthLifecycleCleaning = AuthLifecycleHooks()
    ) {
        self.authenticatedAPIClient = apiClient
        self.sessionStore = sessionStore
        self.onAuthStateChanged = onAuthStateChanged
        self.onUserChanged = onUserChanged
        self.lifecycleCleaner = lifecycleCleaner
    }

    func storedSession() throws -> AuthSession? {
        try sessionStore.load()
    }

    func verifyCurrentSession() async throws -> AuthenticatedUser {
        let user: AuthenticatedUser = try await authenticatedAPIClient.request(
            "auth/me",
            authenticated: true
        )
        await MainActor.run {
            onUserChanged(user)
            onAuthStateChanged(.authenticated)
        }
        return user
    }

    func restoreAndVerifySession() async throws -> AuthenticatedUser? {
        guard try sessionStore.load() != nil else {
            await publishLoggedOut()
            return nil
        }
        do {
            return try await verifyCurrentSession()
        } catch {
            if APIClient.isAuthenticationFailure(error) {
                try? sessionStore.clear()
                await publishLoggedOut()
                return nil
            }
            throw error
        }
    }

    func logout() async {
        try? await authenticatedAPIClient.requestWithoutResponse(
            "auth/logout",
            method: .post,
            authenticated: true,
            retryAfterRefresh: false
        )
        try? sessionStore.clear()
        lifecycleCleaner.cancelAuthenticatedWork()
        lifecycleCleaner.clearAuthenticatedSnapshotsAndMutations()
        await publishLoggedOut()
    }

    private func publishLoggedOut() async {
        await MainActor.run {
            onUserChanged(nil)
            onAuthStateChanged(.loggedOut)
        }
    }
}
