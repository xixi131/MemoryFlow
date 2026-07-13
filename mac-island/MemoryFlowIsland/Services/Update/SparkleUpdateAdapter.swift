import Foundation
import Sparkle

@MainActor
final class SparkleUpdateAdapter: NSObject, UpdateEngine {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)?

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
        do { try updater.start() }
        catch { assertionFailure("Sparkle failed to start: \(error)") }
    }

    func check(sessionID: UUID) {
        guard self.sessionID == nil else { return }
        self.sessionID = sessionID
        updater.checkForUpdates()
    }

    func download(_ release: UpdateRelease, sessionID: UUID) {
        guard sessionID == self.sessionID else { return }
        userDriver.acceptAvailableUpdate()
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
        eventHandler?(sessionID, .current)
        self.sessionID = nil
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard let sessionID else { return }
        eventHandler?(sessionID, .failed(UpdateFailureMapper.map(error)))
        self.sessionID = nil
    }
}

@MainActor
private final class SparkleUpdateUserDriver: NSObject, SPUUserDriver {
    private let emit: (UpdateEngineEvent) -> Void
    private var updateReply: ((SPUUserUpdateChoice) -> Void)?
    private var installationReply: ((SPUUserUpdateChoice) -> Void)?
    private var receivedBytes: UInt64 = 0
    private var expectedBytes: UInt64?

    init(emit: @escaping (UpdateEngineEvent) -> Void) { self.emit = emit }

    func acceptAvailableUpdate() {
        updateReply?(.install)
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
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) { updateReply = reply }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { emit(.failed(UpdateFailureMapper.map(error))); acknowledgement() }
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
