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
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSessioning = URLSession.shared,
        tokenProvider: AccessTokenProviding? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws {
        self.apiBaseURL = try Self.normalizedAPIBaseURL(from: baseURL)
        self.session = session
        self.tokenProvider = tokenProvider
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
        authenticated: Bool = false
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
