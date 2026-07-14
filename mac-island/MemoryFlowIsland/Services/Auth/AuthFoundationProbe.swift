import Foundation

enum AuthFoundationProbe {
    static func runTransportAndSessionProbe() async throws -> AuthenticatedUser {
        let expectedSession = AuthSession(
            accessToken: "probe-access-token",
            refreshToken: "probe-refresh-token",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let store = InMemoryAuthSessionStore(session: expectedSession)
        let transport = ProbeURLSession()
        let client = try APIClient(
            baseURL: URL(string: "https://memoryflow.example/root")!,
            session: transport,
            tokenProvider: store
        )
        let coordinator = AuthCoordinator(apiClient: client, sessionStore: store)
        let user = try await coordinator.verifyCurrentSession()
        guard transport.lastRequest?.url?.absoluteString == "https://memoryflow.example/root/api/auth/me",
              transport.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer probe-access-token",
              try coordinator.storedSession() == expectedSession,
              user.email == "probe@memoryflow.example" else {
            throw APIClientError.decodingFailed
        }
        return user
    }

    static func runKeychainProbe() throws {
        let store = KeychainAuthSessionStore(
            service: "com.memoryflow.island.auth.probe",
            account: UUID().uuidString
        )
        let session = AuthSession(
            accessToken: "keychain-access",
            refreshToken: "keychain-refresh",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        try store.save(session)
        guard try store.load() == session else { throw AuthSessionStoreError.decoding }
        try store.clear()
        guard try store.load() == nil else { throw AuthSessionStoreError.decoding }
    }

    static func runApplicationSupportStoreProbe() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("memoryflow-auth-store-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("session.json")
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = ApplicationSupportAuthSessionStore(fileURL: fileURL)
        let session = AuthSession(
            accessToken: "file-access",
            refreshToken: "file-refresh",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        try store.save(session)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard try store.load() == session,
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
            throw AuthSessionStoreError.decoding
        }
        try store.clear()
        guard try store.load() == nil else { throw AuthSessionStoreError.decoding }
    }
}
private final class ProbeURLSession: URLSessioning {
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let json = """
        {"code":200,"message":"success","data":{"id":7,"email":"probe@memoryflow.example","nickname":"Probe","avatarUrl":null,"profession":null,"age":null},"timestamp":1}
        """
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(json.utf8), response)
    }
}
