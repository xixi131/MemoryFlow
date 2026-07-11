import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isExpired: Bool {
        expiresAt <= Date()
    }
}
struct AuthenticatedUser: Codable, Equatable {
    let id: Int64
    let email: String
    let nickname: String?
    let avatarUrl: String?
    let profession: String?
    let age: String?
}
