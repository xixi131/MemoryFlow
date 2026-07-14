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
        receivedBytes = 0
        expectedBytes = nil
        emit(.downloadStarted(totalBytes: nil))
    }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedBytes = expectedContentLength
        emit(.downloadExpectedContentLength(Int64(expectedContentLength)))
    }
    func showDownloadDidReceiveData(ofLength length: UInt64) { receivedBytes += length; emit(.downloadProgress(receivedBytes: Int64(receivedBytes), totalBytes: expectedBytes.map(Int64.init))) }
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
