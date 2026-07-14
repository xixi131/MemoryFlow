import AppKit
import Foundation

protocol ExternalURLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

extension NSWorkspace: ExternalURLOpening {}

enum DesktopLoginCallbackError: Error, Equatable {
    case invalidCallback
    case missingToken
    case missingRefreshToken
    case invalidExpiry
    case duplicate
}

protocol DesktopLoginCoordinating: AnyObject {
    var loginURL: URL { get }
    @discardableResult func openLogin() -> Bool
    func handleCallback(_ url: URL) async throws -> AuthenticatedUser
}

final class DesktopLoginCoordinator: DesktopLoginCoordinating {
    let loginURL: URL
    private let opener: ExternalURLOpening
    private let sessionStore: AuthSessionStoring
    private let authCoordinator: AuthCoordinating
    private let lock = NSLock()
    private var callbacksInFlight = Set<String>()
    private var completedCallbacks = Set<String>()

    init(
        webBaseURL: URL,
        opener: ExternalURLOpening = NSWorkspace.shared,
        sessionStore: AuthSessionStoring,
        authCoordinator: AuthCoordinating
    ) {
        let normalized = webBaseURL.absoluteString
            .components(separatedBy: "#")[0]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.loginURL = URL(string: "\(normalized)/#/login?callback=desktop&client=mac-island")!
        self.opener = opener
        self.sessionStore = sessionStore
        self.authCoordinator = authCoordinator
    }

    @discardableResult
    func openLogin() -> Bool {
        opener.open(loginURL)
    }

    func handleCallback(_ url: URL) async throws -> AuthenticatedUser {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "memoryflow-island",
              components.host?.lowercased() == "callback" else {
            throw DesktopLoginCallbackError.invalidCallback
        }
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        guard let accessToken = values["token"] ?? nil, accessToken.isEmpty == false else {
            throw DesktopLoginCallbackError.missingToken
        }
        guard let refreshToken = values["refreshToken"] ?? nil, refreshToken.isEmpty == false else {
            throw DesktopLoginCallbackError.missingRefreshToken
        }
        guard let expiryText = values["expiresIn"] ?? nil,
              let expiresIn = TimeInterval(expiryText),
              expiresIn.isFinite,
              expiresIn > 0 else {
            throw DesktopLoginCallbackError.invalidExpiry
        }

        let callbackKey = url.absoluteString
        let accepted = lock.withLock {
            guard callbacksInFlight.contains(callbackKey) == false,
                  completedCallbacks.contains(callbackKey) == false else {
                return false
            }
            callbacksInFlight.insert(callbackKey)
            return true
        }
        guard accepted else { throw DesktopLoginCallbackError.duplicate }

        let session = AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
        do {
            try sessionStore.save(session)
            let user = try await authCoordinator.verifyCurrentSession()
            lock.withLock {
                _ = callbacksInFlight.remove(callbackKey)
                _ = completedCallbacks.insert(callbackKey)
            }
            return user
        } catch {
            lock.withLock {
                _ = callbacksInFlight.remove(callbackKey)
            }
            if (try? sessionStore.load()) == session {
                try? sessionStore.clear()
            }
            throw error
        }
    }
}
