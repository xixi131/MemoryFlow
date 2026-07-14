import Foundation

struct UpdateRelease: Equatable, Sendable {
    let version: String
    let build: String
    let downloadURL: URL
    let contentLength: Int64?
}

struct UpdateDownloadProgress: Codable, Equatable, Sendable {
    let receivedBytes: Int64
    let totalBytes: Int64?

    var fraction: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(receivedBytes) / Double(totalBytes), 0), 1)
    }

    var percentage: Int? {
        fraction.map { Int(($0 * 100).rounded(.down)) }
    }

    static let indeterminate = UpdateDownloadProgress(receivedBytes: 0, totalBytes: nil)
}

enum UpdateFailure: Error, Equatable, Sendable {
    case offline
    case httpStatus(Int)
    case invalidConfiguration(String)
    case invalidFeed(String)
    case signatureRejected
    case insufficientDisk
    case authorizationCancelled
    case transport(String)
    case engine(String)
}

enum UpdateFailureMapper {
    static func map(_ error: Error) -> UpdateFailure {
        map(error, depth: 0)
    }

    private static func map(_ error: Error, depth: Int) -> UpdateFailure {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           [
               NSURLErrorNotConnectedToInternet,
               NSURLErrorTimedOut,
               NSURLErrorNetworkConnectionLost,
               NSURLErrorCannotFindHost,
               NSURLErrorCannotConnectToHost,
               NSURLErrorDNSLookupFailed,
               NSURLErrorSecureConnectionFailed
           ].contains(nsError.code) {
            return .offline
        }
        if depth < 4,
           let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let mappedUnderlying = map(underlyingError, depth: depth + 1)
            if case .engine = mappedUnderlying {
                // Preserve a more specific outer Sparkle error below when available.
            } else {
                return mappedUnderlying
            }
        }
        if nsError.code == NSUserCancelledError {
            return .authorizationCancelled
        }
        let message = nsError.localizedDescription.lowercased()
        if message.contains("signature") || message.contains("eddsa") || message.contains("ed25519") {
            return .signatureRejected
        }
        if message.contains("disk") || message.contains("no space") || message.contains("space available") {
            return .insufficientDisk
        }
        if message.contains("appcast") || message.contains("malformed") || message.contains("xml") {
            return .invalidFeed(nsError.localizedDescription)
        }
        if let status = (400...599).first(where: { message.contains(String($0)) }) {
            return .httpStatus(status)
        }
        return .engine(nsError.localizedDescription)
    }
}

enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case available(UpdateRelease)
    case deferred(UpdateRelease, until: Date)
    case downloadRequested(UpdateRelease)
    case downloading(UpdateRelease, progress: UpdateDownloadProgress)
    case verifying(UpdateRelease)
    case ready(UpdateRelease)
    case awaitingAuthorization(UpdateRelease)
    case installing(UpdateRelease)
    case installed(UpdateRelease, relaunched: Bool)
    case failed(UpdateFailure)
}

enum UpdateEngineEvent: Equatable, Sendable {
    case current
    case available(UpdateRelease)
    case downloadStarted(totalBytes: Int64?)
    case downloadExpectedContentLength(Int64)
    case downloadProgress(receivedBytes: Int64, totalBytes: Int64?)
    case verificationStarted
    case verificationSucceeded
    case authorizationRequested
    case authorizationCancelled
    case installationStarted
    case installationFinished(relaunched: Bool)
    case failed(UpdateFailure)
}

@MainActor
protocol UpdateEngine: AnyObject {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)? { get set }
    func check(sessionID: UUID)
    func cancelCheck(sessionID: UUID)
    func download(_ release: UpdateRelease, sessionID: UUID)
    func dismissAvailableUpdate(sessionID: UUID)
    func install(_ release: UpdateRelease, sessionID: UUID)
}

protocol UpdateClock: Sendable {
    var now: Date { get }
}

struct SystemUpdateClock: UpdateClock {
    var now: Date { Date() }
}
