import Foundation

protocol URLSessioning {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: URLSessioning {}

protocol AccessTokenProviding: AnyObject {
    func accessToken() -> String?
}

final class APIClient {
    private let apiBaseURL: URL
    private let session: URLSessioning
    private let tokenProvider: AccessTokenProviding?
    private let sessionStore: AuthSessionStoring?
    private let refreshGate = APIRefreshGate()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSessioning = URLSession.shared,
        tokenProvider: AccessTokenProviding? = nil,
        sessionStore: AuthSessionStoring? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        self.apiBaseURL = try Self.normalizedAPIBaseURL(from: baseURL)
        self.session = session
        self.tokenProvider = tokenProvider
        self.sessionStore = sessionStore
        self.encoder = encoder
        self.decoder = decoder
    }

    static func normalizedAPIBaseURL(from baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme != nil,
              components.host != nil else {
            throw APIClientError.invalidBaseURL
        }
        let parts = components.path.split(separator: "/").map(String.init)
        if parts.last != "api" {
            components.path = "/" + (parts + ["api"]).joined(separator: "/")
        } else {
            components.path = "/" + parts.joined(separator: "/")
        }
        components.query = nil
        components.fragment = nil
        guard let normalized = components.url else {
            throw APIClientError.invalidBaseURL
        }
        return normalized
    }

    func request<Response: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        authenticated: Bool = false,
        retryAfterRefresh: Bool = true
    ) async throws -> Response {
        do {
            return try await performRequest(endpoint, method: method, body: body, authenticated: authenticated)
        } catch {
            guard authenticated, retryAfterRefresh, Self.isAuthenticationFailure(error), sessionStore != nil else {
                throw error
            }
            _ = try await refreshGate.refresh { [weak self] in
                guard let self else { throw APIClientError.missingData }
                return try await self.refreshSession()
            }
            return try await performRequest(endpoint, method: method, body: body, authenticated: true)
        }
    }

    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        authenticated: Bool,
        retryAfterRefresh: Bool = true
    ) async throws {
        do {
            try await performVoidRequest(endpoint, method: method, authenticated: authenticated)
        } catch {
            guard authenticated, retryAfterRefresh, Self.isAuthenticationFailure(error), sessionStore != nil else {
                throw error
            }
            _ = try await refreshGate.refresh { [weak self] in
                guard let self else { throw APIClientError.missingData }
                return try await self.refreshSession()
            }
            try await performVoidRequest(endpoint, method: method, authenticated: true)
        }
    }

    private func performRequest<Response: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        authenticated: Bool
    ) async throws -> Response {
        let relativePath = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard relativePath.isEmpty == false else {
            throw APIClientError.invalidEndpoint
        }
        let url = apiBaseURL.appendingPathComponent(relativePath)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            guard let encoded = try? encoder.encode(AnyEncodable(body)) else {
                throw APIClientError.encodingFailed
            }
            request.httpBody = encoded
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = tokenProvider?.accessToken(), token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.nonHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.transportStatus(httpResponse.statusCode)
        }
        guard let envelope = try? decoder.decode(APIResponseEnvelope<Response>.self, from: data) else {
            throw APIClientError.decodingFailed
        }
        guard envelope.code == 200 else {
            throw APIClientError.backend(code: envelope.code, message: envelope.message)
        }
        guard let value = envelope.data else {
            throw APIClientError.missingData
        }
        return value
    }

    private func performVoidRequest(
        _ endpoint: String,
        method: HTTPMethod,
        authenticated: Bool
    ) async throws {
        let _: APIEmptyPayload? = try await performEnvelopeRequest(
            endpoint,
            method: method,
            body: nil,
            authenticated: authenticated
        )
    }

    private func performEnvelopeRequest<Response: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        authenticated: Bool
    ) async throws -> Response? {
        let relativePath = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard relativePath.isEmpty == false else { throw APIClientError.invalidEndpoint }
        var request = URLRequest(url: apiBaseURL.appendingPathComponent(relativePath))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = tokenProvider?.accessToken(), token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.nonHTTPResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIClientError.transportStatus(http.statusCode) }
        guard let envelope = try? decoder.decode(APIResponseEnvelope<Response>.self, from: data) else {
            throw APIClientError.decodingFailed
        }
        guard envelope.code == 200 else { throw APIClientError.backend(code: envelope.code, message: envelope.message) }
        return envelope.data
    }

    private func refreshSession() async throws -> AuthSession {
        guard let sessionStore, let current = try sessionStore.load() else {
            throw APIClientError.missingData
        }
        let response: AuthRefreshResponse = try await performRequest(
            "auth/refresh",
            method: .post,
            body: AuthRefreshRequest(refreshToken: current.refreshToken),
            authenticated: false
        )
        let replacement = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
        try sessionStore.save(replacement)
        return replacement
    }

    static func isAuthenticationFailure(_ error: Error) -> Bool {
        switch error {
        case APIClientError.transportStatus(401), APIClientError.transportStatus(403): return true
        case APIClientError.backend(let code, _): return code == 401 || code == 403
        default: return false
        }
    }
}

private struct APIEmptyPayload: Decodable {}

private actor APIRefreshGate {
    private var activeTask: Task<AuthSession, Error>?

    func refresh(operation: @escaping () async throws -> AuthSession) async throws -> AuthSession {
        if let activeTask { return try await activeTask.value }
        let task = Task { try await operation() }
        activeTask = task
        defer { activeTask = nil }
        return try await task.value
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
