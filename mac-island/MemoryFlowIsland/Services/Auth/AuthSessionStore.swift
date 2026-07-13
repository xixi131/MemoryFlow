import Foundation
import Security

protocol AuthSessionStoring: AnyObject, AccessTokenProviding {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear() throws
}
extension AuthSessionStoring {
    func accessToken() -> String? {
        try? load()?.accessToken
    }
}

enum AuthSessionStoreError: Error, Equatable {
    case keychain(OSStatus)
    case encoding
    case decoding
}

final class KeychainAuthSessionStore: AuthSessionStoring {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "com.memoryflow.island.auth",
        account: String = "current-session"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AuthSessionStoreError.keychain(status) }
        guard let data = result as? Data,
              let session = try? decoder.decode(AuthSession.self, from: data) else {
            throw AuthSessionStoreError.decoding
        }
        return session
    }

    func save(_ session: AuthSession) throws {
        guard let data = try? encoder.encode(session) else {
            throw AuthSessionStoreError.encoding
        }
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AuthSessionStoreError.keychain(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw AuthSessionStoreError.keychain(updateStatus)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthSessionStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

final class InMemoryAuthSessionStore: AuthSessionStoring {
    private let lock = NSLock()
    private var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() throws -> AuthSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    func save(_ session: AuthSession) throws {
        lock.lock()
        defer { lock.unlock() }
        self.session = session
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        session = nil
    }
}
