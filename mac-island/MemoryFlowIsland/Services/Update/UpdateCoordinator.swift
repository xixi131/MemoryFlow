import Combine
import AppKit
import Foundation

@MainActor
final class UpdateCoordinator: ObservableObject {
    @Published private(set) var state: UpdateState = .idle

    private let engine: UpdateEngine
    private let clock: UpdateClock
    private let checkTimeout: Duration
    private var activeSessionID: UUID?
    private var selectedRelease: UpdateRelease?
    private var handlingEvent = false
    private var pendingReceivedBytes: Int64 = 0
    private var retryAvailable = false
    private var downloadWhenAvailable = false
    private var checkTimeoutTask: Task<Void, Never>?

    init(
        engine: UpdateEngine,
        clock: UpdateClock = SystemUpdateClock(),
        checkTimeout: Duration = .seconds(30)
    ) {
        self.engine = engine
        self.clock = clock
        self.checkTimeout = checkTimeout
        engine.eventHandler = { [weak self] sessionID, event in
            Task { @MainActor [weak self] in self?.handle(event, sessionID: sessionID) }
        }
    }

    @discardableResult
    func checkForUpdates() -> Bool {
        beginCheck(downloadWhenAvailable: false)
    }

    @discardableResult
    func requestAvailableUpdate() -> Bool {
        switch state {
        case .available:
            return downloadAvailableUpdate()
        case .deferred:
            return beginCheck(downloadWhenAvailable: true)
        default:
            return false
        }
    }

    private func beginCheck(downloadWhenAvailable: Bool) -> Bool {
        guard activeSessionID == nil else { return false }
        let sessionID = UUID()
        activeSessionID = sessionID
        selectedRelease = nil
        self.downloadWhenAvailable = downloadWhenAvailable
        state = .checking
        engine.check(sessionID: sessionID)
        scheduleCheckTimeout(for: sessionID)
        return true
    }

    @discardableResult
    func downloadAvailableUpdate() -> Bool {
        guard case .available(let release) = state, let sessionID = activeSessionID else { return false }
        pendingReceivedBytes = 0
        state = .downloadRequested(release)
        engine.download(release, sessionID: sessionID)
        return true
    }

    @discardableResult
    func deferAvailableUpdate(until date: Date) -> Bool {
        guard case .available(let release) = state,
              let sessionID = activeSessionID else { return false }
        state = .deferred(release, until: date)
        engine.dismissAvailableUpdate(sessionID: sessionID)
        finishSession()
        return true
    }

    @discardableResult
    func discardAvailableUpdate() -> Bool {
        guard case .available = state,
              let sessionID = activeSessionID else { return false }
        state = .idle
        engine.dismissAvailableUpdate(sessionID: sessionID)
        finishSession()
        return true
    }

    @discardableResult
    func installReadyUpdate() -> Bool {
        guard case .ready(let release) = state, let sessionID = activeSessionID else { return false }
        state = .awaitingAuthorization(release)
        engine.install(release, sessionID: sessionID)
        return true
    }

    @discardableResult
    func retryFailure() -> Bool {
        guard case .failed = state, retryAvailable else { return false }
        state = .idle
        retryAvailable = false
        return checkForUpdates()
    }

    private func handle(_ event: UpdateEngineEvent, sessionID: UUID) {
        guard sessionID == activeSessionID, !handlingEvent else { return }
        handlingEvent = true
        defer { handlingEvent = false }

        switch event {
        case .current:
            state = .idle
            finishSession()
        case .available(let release):
            guard case .checking = state else { return }
            selectedRelease = release
            if downloadWhenAvailable {
                downloadWhenAvailable = false
                pendingReceivedBytes = 0
                state = .downloadRequested(release)
                engine.download(release, sessionID: sessionID)
            } else {
                state = .available(release)
            }
        case .downloadStarted(let total):
            guard case .downloadRequested(let release) = state else { return }
            pendingReceivedBytes = 0
            state = .downloading(
                release,
                progress: UpdateDownloadProgress(
                    receivedBytes: 0,
                    totalBytes: normalizedTotal(total) ?? normalizedTotal(release.contentLength)
                )
            )
        case .downloadExpectedContentLength(let total):
            guard case .downloading(let release, let previous) = state,
                  let normalized = normalizedTotal(total) else { return }
            publishProgress(
                release: release,
                previous: previous,
                received: pendingReceivedBytes,
                total: normalized
            )
        case .downloadProgress(let received, let total):
            guard case .downloading(let release, let previous) = state else { return }
            pendingReceivedBytes = max(pendingReceivedBytes, max(received, 0))
            publishProgress(
                release: release,
                previous: previous,
                received: pendingReceivedBytes,
                total: normalizedTotal(total) ?? previous.totalBytes ?? normalizedTotal(release.contentLength)
            )
        case .verificationStarted:
            guard case .downloading(let release, _) = state else { return }
            state = .verifying(release)
        case .verificationSucceeded:
            guard case .verifying(let release) = state else { return }
            state = .ready(release)
        case .authorizationRequested:
            guard case .awaitingAuthorization = state else { return }
        case .authorizationCancelled:
            guard case .awaitingAuthorization = state else { return }
            state = .failed(.authorizationCancelled)
            retryAvailable = true
            finishSession()
        case .installationStarted:
            guard case .awaitingAuthorization(let release) = state else { return }
            state = .installing(release)
        case .installationFinished(let relaunched):
            guard case .installing(let release) = state else { return }
            state = .installed(release, relaunched: relaunched)
            finishSession()
        case .failed(let failure):
            state = .failed(failure)
            retryAvailable = true
            finishSession()
        }
    }

    private func finishSession() {
        checkTimeoutTask?.cancel()
        checkTimeoutTask = nil
        activeSessionID = nil
        selectedRelease = nil
        pendingReceivedBytes = 0
        downloadWhenAvailable = false
    }

    private func scheduleCheckTimeout(for sessionID: UUID) {
        checkTimeoutTask?.cancel()
        checkTimeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: checkTimeout)
            guard Task.isCancelled == false,
                  activeSessionID == sessionID,
                  case .checking = state else { return }
            engine.cancelCheck(sessionID: sessionID)
            state = .failed(.transport("Update check timed out"))
            retryAvailable = true
            finishSession()
        }
    }

    private func publishProgress(
        release: UpdateRelease,
        previous: UpdateDownloadProgress,
        received: Int64,
        total: Int64?
    ) {
        let monotonicReceived = max(previous.receivedBytes, max(received, 0))
        let monotonicTotal = total.map { max($0, monotonicReceived) }
        let clampedReceived = monotonicTotal.map { min(monotonicReceived, $0) } ?? monotonicReceived
        let candidate = UpdateDownloadProgress(
            receivedBytes: clampedReceived,
            totalBytes: monotonicTotal
        )
        pendingReceivedBytes = candidate.receivedBytes
        let visibleProgressChanged = candidate.percentage != previous.percentage
        let totalBecameKnown = candidate.totalBytes != previous.totalBytes
        guard visibleProgressChanged || totalBecameKnown else { return }
        state = .downloading(release, progress: candidate)
    }

    private func normalizedTotal(_ total: Int64?) -> Int64? {
        guard let total, total > 0 else { return nil }
        return total
    }
}

protocol UpdatePolicyPersisting: AnyObject {
    var lastSuccessfulCheck: Date? { get set }
    var deferredVersion: String? { get set }
    var deferredUntil: Date? { get set }
    var installedBuild: String? { get set }
}

final class UserDefaultsUpdatePolicyStore: UpdatePolicyPersisting {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var lastSuccessfulCheck: Date? { get { defaults.object(forKey: "update.lastSuccessfulCheck") as? Date } set { defaults.set(newValue, forKey: "update.lastSuccessfulCheck") } }
    var deferredVersion: String? { get { defaults.string(forKey: "update.deferredVersion") } set { defaults.set(newValue, forKey: "update.deferredVersion") } }
    var deferredUntil: Date? { get { defaults.object(forKey: "update.deferredUntil") as? Date } set { defaults.set(newValue, forKey: "update.deferredUntil") } }
    var installedBuild: String? { get { defaults.string(forKey: "update.installedBuild") } set { defaults.set(newValue, forKey: "update.installedBuild") } }
}

@MainActor
final class UpdateCheckPolicy {
    static let cadence: TimeInterval = 24 * 60 * 60
    static let deferral: TimeInterval = 4 * 60 * 60
    private let coordinator: UpdateCoordinator
    private let clock: UpdateClock
    private let store: UpdatePolicyPersisting
    private var cadenceTimer: Timer?
    private var deferralTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var cancellable: AnyCancellable?
    private var wasChecking = false

    init(coordinator: UpdateCoordinator, clock: UpdateClock = SystemUpdateClock(), store: UpdatePolicyPersisting = UserDefaultsUpdatePolicyStore()) {
        self.coordinator = coordinator; self.clock = clock; self.store = store
        cancellable = coordinator.$state.sink { [weak self] state in
            guard let self else { return }
            switch state {
            case .checking: self.wasChecking = true
            case .idle where self.wasChecking: self.store.lastSuccessfulCheck = self.clock.now; self.wasChecking = false
            case .available, .downloadRequested:
                self.store.lastSuccessfulCheck = self.clock.now
                self.wasChecking = false
            case .failed: self.wasChecking = false
            default: break
            }
        }
    }

    func start() {
        guard cadenceTimer == nil else { return }
        recheckDeferredVersionIfNeeded()
        catchUpIfNeeded()
        cadenceTimer = Timer.scheduledTimer(withTimeInterval: Self.cadence, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recheckDeferredVersionIfNeeded()
                self?.catchUpIfNeeded()
            }
        }
    }

    func stop() {
        cadenceTimer?.invalidate()
        cadenceTimer = nil
        deferralTimer?.invalidate()
        deferralTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
    }

    func manualCheck() { _ = coordinator.checkForUpdates() }

    func catchUpIfNeeded() {
        guard hasActiveDeferral == false else { return }
        guard store.lastSuccessfulCheck.map({ clock.now.timeIntervalSince($0) >= Self.cadence }) ?? true else { return }
        _ = coordinator.checkForUpdates()
    }
    @discardableResult
    func deferVersion(_ version: String) -> Date {
        let until = clock.now.addingTimeInterval(Self.deferral)
        store.deferredVersion = version
        store.deferredUntil = until
        scheduleDeferralTimer(until: until)
        return until
    }
    func shouldPresent(version: String) -> Bool {
        guard store.installedBuild != version else { return false }
        guard store.deferredVersion == version, let until = store.deferredUntil else { return true }
        return clock.now >= until
    }
    func wasInstalled(build: String) -> Bool { store.installedBuild == build }
    func suppressionUntil(version: String) -> Date? {
        guard store.deferredVersion == version,
              let until = store.deferredUntil,
              clock.now < until else { return nil }
        return until
    }
    func clearDeferral() {
        store.deferredVersion = nil
        store.deferredUntil = nil
        deferralTimer?.invalidate()
        deferralTimer = nil
    }

    func clearDeferralIfSuperseded(by version: String) {
        if store.deferredVersion != version { clearDeferral() }
    }

    func markInstalled(build: String) {
        store.installedBuild = build
        clearDeferral()
    }

    func recheckDeferredVersionIfNeeded() {
        guard store.deferredVersion != nil,
              let until = store.deferredUntil else {
            deferralTimer?.invalidate()
            deferralTimer = nil
            return
        }
        guard clock.now >= until else {
            scheduleDeferralTimer(until: until)
            return
        }
        clearDeferral()
        _ = coordinator.checkForUpdates()
    }

    private var hasActiveDeferral: Bool {
        guard store.deferredVersion != nil,
              let until = store.deferredUntil else { return false }
        return clock.now < until
    }

    private func scheduleDeferralTimer(until: Date) {
        deferralTimer?.invalidate()
        let delay = max(until.timeIntervalSince(clock.now), 0)
        deferralTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.recheckDeferredVersionIfNeeded() }
        }
    }
}
