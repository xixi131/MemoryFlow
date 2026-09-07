import Foundation
import OSLog
import Sparkle

@MainActor
final class SparkleUpdateAdapter: NSObject, UpdateEngine {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)?
    private let logger = Logger(subsystem: "com.memoryflow.island", category: "Updater")
    private var startupFailure: UpdateFailure?

    private lazy var userDriver = SparkleUpdateUserDriver { [weak self] event in
        self?.handleUserDriverEvent(event)
    }
    private lazy var updater = SPUUpdater(
        hostBundle: .main,
        applicationBundle: .main,
        userDriver: userDriver,
        delegate: self
    )
    private var sessionID: UUID?

    override init() {
        super.init()
        do {
            try updater.start()
        } catch {
            startupFailure = UpdateFailureMapper.map(error)
            log(error, context: "start")
        }
    }

    func check(sessionID: UUID) {
        guard self.sessionID == nil else { return }
        if let startupFailure {
            eventHandler?(sessionID, .failed(startupFailure))
            return
        }
        self.sessionID = sessionID
        updater.checkForUpdates()
    }

    func cancelCheck(sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        userDriver.cancelUpdateCheck()
        self.sessionID = nil
    }

    func download(_ release: UpdateRelease, sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        userDriver.acceptAvailableUpdate()
    }

    func dismissAvailableUpdate(sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        userDriver.dismissAvailableUpdate()
        self.sessionID = nil
    }

    func install(_ release: UpdateRelease, sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        userDriver.acceptInstallation()
    }

    private func handleUserDriverEvent(_ event: UpdateEngineEvent) {
        guard let sessionID else { return }
        eventHandler?(sessionID, event)
        switch event {
        case .authorizationCancelled, .installationFinished, .failed:
            self.sessionID = nil
        default:
            break
        }
    }

    private func log(_ error: Error, context: String) {
        let nsError = error as NSError
        logger.error(
            "Sparkle \(context, privacy: .public) failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) description=\(nsError.localizedDescription, privacy: .public)"
        )
    }
}

extension SparkleUpdateAdapter: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard let sessionID, let url = item.fileURL else { return }
        let release = UpdateRelease(
            version: item.displayVersionString,
            build: item.versionString,
            downloadURL: url,
            contentLength: nil
        )
        eventHandler?(sessionID, .available(release))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        guard let sessionID else { return }
        userDriver.finishUpdateCheck()
        eventHandler?(sessionID, .current)
        self.sessionID = nil
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard let sessionID else { return }
        userDriver.finishUpdateCheck()
        // Sparkle aborts the driver with `SUNoUpdateError` after a check that
        // simply found nothing. Normally `updaterDidNotFindUpdate` has already
        // closed the session by then, but if this lands first it must NOT be
        // reported as a failure: the policy layer would skip recording a
        // successful check and start retrying a perfectly healthy "you are up
        // to date" result every half hour.
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain, nsError.code == SUError.noUpdateError.rawValue {
            eventHandler?(sessionID, .current)
            self.sessionID = nil
            return
        }
        log(error, context: "check")
        eventHandler?(sessionID, .failed(UpdateFailureMapper.map(error)))
        self.sessionID = nil
    }
}

@MainActor
private final class SparkleUpdateUserDriver: NSObject, SPUUserDriver {
    private let emit: (UpdateEngineEvent) -> Void
    private var updateReply: ((SPUUserUpdateChoice) -> Void)?
    private var installationReply: ((SPUUserUpdateChoice) -> Void)?
    private var checkCancellation: (() -> Void)?
    private var receivedBytes: UInt64 = 0
    private var expectedBytes: UInt64?

    init(emit: @escaping (UpdateEngineEvent) -> Void) { self.emit = emit }

    func acceptAvailableUpdate() {
        updateReply?(.install)
        updateReply = nil
    }

    func cancelUpdateCheck() {
        checkCancellation?()
        checkCancellation = nil
    }

    func finishUpdateCheck() {
        checkCancellation = nil
    }

    func dismissAvailableUpdate() {
        updateReply?(.dismiss)
        updateReply = nil
    }

    func acceptInstallation() {
        emit(.authorizationRequested)
        installationReply?(.install)
        installationReply = nil
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { checkCancellation = cancellation }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        checkCancellation = nil
        updateReply = reply
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        checkCancellation = nil
        acknowledgement()
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        checkCancellation = nil
        emit(.failed(UpdateFailureMapper.map(error)))
        acknowledgement()
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        // Sparkle starts a second download when a delta fails to apply and it
        // falls back to the full archive. Resetting here (and letting the
        // coordinator restart its progress) keeps the percentage counting from
        // 0 instead of freezing at the delta's byte count.
        receivedBytes = 0
        expectedBytes = nil
        emit(.downloadStarted(totalBytes: nil))
    }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        // `expectedContentLength` originates from `URLResponse.expectedContentLength`,
        // which is -1 when the server sends no Content-Length. Sparkle widens that
        // to UInt64, so it arrives here as UInt64.max — `Int64(_:)` would trap on
        // it, and any absurd value would peg the percentage at 0% for the whole
        // download. Treat anything unrepresentable as "length unknown" and stay
        // on the indeterminate spinner.
        guard let normalized = Self.normalizedByteCount(expectedContentLength) else {
            expectedBytes = nil
            return
        }
        expectedBytes = expectedContentLength
        emit(.downloadExpectedContentLength(normalized))
    }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        // `&+` cannot realistically overflow for a download, but it keeps a
        // malformed callback from trapping mid-update.
        receivedBytes = receivedBytes &+ length
        emit(.downloadProgress(
            receivedBytes: Self.normalizedByteCount(receivedBytes) ?? 0,
            totalBytes: expectedBytes.flatMap(Self.normalizedByteCount)
        ))
    }

    /// UInt64 → Int64 for byte counts, rejecting 0 and anything Int64 cannot hold.
    private static func normalizedByteCount(_ value: UInt64) -> Int64? {
        guard value > 0, value <= UInt64(Int64.max) else { return nil }
        return Int64(value)
    }
    func showDownloadDidStartExtractingUpdate() { emit(.verificationStarted) }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { installationReply = reply; emit(.verificationSucceeded) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) { emit(.installationStarted) }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { emit(.installationFinished(relaunched: relaunched)); acknowledgement() }
    func dismissUpdateInstallation() {
        if installationReply != nil { emit(.authorizationCancelled) }
        updateReply = nil
        installationReply = nil
    }
}
