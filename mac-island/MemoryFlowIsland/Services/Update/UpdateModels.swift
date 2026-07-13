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
    case invalidConfiguration(String)
    case invalidFeed(String)
    case signatureRejected
    case transport(String)
    case engine(String)
}

enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case available(UpdateRelease)
    case deferred(UpdateRelease, until: Date)
    case downloadRequested(UpdateRelease)
    case downloading(UpdateRelease, progress: UpdateDownloadProgress)
    case ready(UpdateRelease)
    case installing(UpdateRelease)
    case failed(UpdateFailure)
}

enum UpdateEngineEvent: Equatable, Sendable {
    case current
    case available(UpdateRelease)
    case downloadStarted(totalBytes: Int64?)
    case downloadExpectedContentLength(Int64)
    case downloadProgress(receivedBytes: Int64, totalBytes: Int64?)
    case downloadFinished
    case installationStarted
    case failed(UpdateFailure)
}

@MainActor
protocol UpdateEngine: AnyObject {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)? { get set }
    func check(sessionID: UUID)
    func download(_ release: UpdateRelease, sessionID: UUID)
    func install(_ release: UpdateRelease, sessionID: UUID)
}

protocol UpdateClock: Sendable {
    var now: Date { get }
}

struct SystemUpdateClock: UpdateClock {
    var now: Date { Date() }
}
