import Foundation

protocol AuthCoordinating: AnyObject {
    var authenticatedAPIClient: APIClient { get }
    func storedSession() throws -> AuthSession?
    func verifyCurrentSession() async throws -> AuthenticatedUser
}

enum AuthCoordinatorState: Equatable {
    case loggedOut
    case authenticated
}

final class AuthCoordinator: AuthCoordinating {
    let authenticatedAPIClient: APIClient
    private let sessionStore: AuthSessionStoring
    private let onAuthStateChanged: (AuthCoordinatorState) -> Void
    private let onUserChanged: (AuthenticatedUser?) -> Void

    init(
        apiClient: APIClient,
        sessionStore: AuthSessionStoring,
        onAuthStateChanged: @escaping (AuthCoordinatorState) -> Void = { _ in },
        onUserChanged: @escaping (AuthenticatedUser?) -> Void = { _ in }
    ) {
        self.authenticatedAPIClient = apiClient
        self.sessionStore = sessionStore
        self.onAuthStateChanged = onAuthStateChanged
        self.onUserChanged = onUserChanged
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
}
