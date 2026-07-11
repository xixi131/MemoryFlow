import Foundation

struct APIResponseEnvelope<Value: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: Value?
    let timestamp: Int64?
}
struct EmptyAPIResponse: Decodable {}

enum APIClientError: Error, Equatable {
    case invalidBaseURL
    case invalidEndpoint
    case nonHTTPResponse
    case transportStatus(Int)
    case backend(code: Int, message: String)
    case missingData
    case encodingFailed
    case decodingFailed
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}
