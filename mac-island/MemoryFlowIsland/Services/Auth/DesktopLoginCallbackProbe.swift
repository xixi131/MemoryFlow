import Foundation

enum DesktopLoginCallbackProbe {
    static func run() async throws -> AuthenticatedUser {
        let store = InMemoryAuthSessionStore()
        let transport = DesktopLoginProbeSession()
        let apiClient = try APIClient(
            baseURL: URL(string: "https://api.memoryflow.example")!,
            session: transport,
            tokenProvider: store
        )
        let auth = AuthCoordinator(apiClient: apiClient, sessionStore: store)
        let opener = DesktopLoginProbeOpener()
        let coordinator = DesktopLoginCoordinator(
            webBaseURL: URL(string: "https://memoryflow.tanxhub.com/")!,
            opener: opener,
            sessionStore: store,
            authCoordinator: auth
        )

        guard coordinator.openLogin(),
              opener.openedURL?.absoluteString == "https://memoryflow.tanxhub.com/#/login?callback=desktop&client=mac-island" else {
            throw DesktopLoginCallbackError.invalidCallback
        }
        let callback = URL(string: "memoryflow-island://callback?token=access-1&refreshToken=refresh-1&expiresIn=3600")!
        let user = try await coordinator.handleCallback(callback)
        guard try store.load()?.accessToken == "access-1",
              transport.lastAuthorization == "Bearer access-1",
              user.nickname == "Memory Tester" else {
            throw DesktopLoginCallbackError.invalidCallback
        }
        do {
            _ = try await coordinator.handleCallback(callback)
            throw DesktopLoginCallbackError.invalidCallback
        } catch DesktopLoginCallbackError.duplicate {}
        return user
    }
}
private final class DesktopLoginProbeOpener: ExternalURLOpening {
    private(set) var openedURL: URL?

    func open(_ url: URL) -> Bool {
        openedURL = url
        return true
    }
}

private final class DesktopLoginProbeSession: URLSessioning {
    private(set) var lastAuthorization: String?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        let json = """
        {"code":200,"message":"success","data":{"id":11,"email":"tester@memoryflow.example","nickname":"Memory Tester","avatarUrl":null,"profession":"Student","age":null},"timestamp":1}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), response)
    }
}
