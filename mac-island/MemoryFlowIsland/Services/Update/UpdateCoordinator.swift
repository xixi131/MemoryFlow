import Combine
import AppKit
import Foundation

@MainActor
final class UpdateCoordinator: ObservableObject {
    @Published private(set) var state: UpdateState = .idle

    private let engine: UpdateEngine
    private let clock: UpdateClock
    private var activeSessionID: UUID?
    private var selectedRelease: UpdateRelease?
    private var handlingEvent = false
    private var pendingReceivedBytes: Int64 = 0

    init(engine: UpdateEngine, clock: UpdateClock = SystemUpdateClock()) {
        self.engine = engine
        self.clock = clock
        engine.eventHandler = { [weak self] sessionID, event in
            Task { @MainActor [weak self] in self?.handle(event, sessionID: sessionID) }
        }
    }

    @discardableResult
    func checkForUpdates() -> Bool {
        guard activeSessionID == nil else { return false }
        let sessionID = UUID()
        activeSessionID = sessionID
        selectedRelease = nil
        state = .checking
        engine.check(sessionID: sessionID)
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
        guard case .available(let release) = state else { return false }
        state = .deferred(release, until: date)
        finishSession()
        return true
    }

    @discardableResult
    func installReadyUpdate() -> Bool {
        guard case .ready(let release) = state, let sessionID = activeSessionID else { return false }
        state = .installing(release)
        engine.install(release, sessionID: sessionID)
        return true
    }

    func resetFailure() {
        guard case .failed = state else { return }
        state = .idle
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
            state = .available(release)
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
        case .downloadFinished:
            guard case .downloading(let release, _) = state else { return }
            state = .ready(release)
        case .installationStarted:
            guard case .installing = state else { return }
        case .failed(let failure):
            state = .failed(failure)
            finishSession()
        }
    }

    private func finishSession() {
        activeSessionID = nil
        selectedRelease = nil
        pendingReceivedBytes = 0
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
}

final class UserDefaultsUpdatePolicyStore: UpdatePolicyPersisting {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var lastSuccessfulCheck: Date? { get { defaults.object(forKey: "update.lastSuccessfulCheck") as? Date } set { defaults.set(newValue, forKey: "update.lastSuccessfulCheck") } }
    var deferredVersion: String? { get { defaults.string(forKey: "update.deferredVersion") } set { defaults.set(newValue, forKey: "update.deferredVersion") } }
    var deferredUntil: Date? { get { defaults.object(forKey: "update.deferredUntil") as? Date } set { defaults.set(newValue, forKey: "update.deferredUntil") } }
}

@MainActor
final class UpdateCheckPolicy {
    static let cadence: TimeInterval = 24 * 60 * 60
    static let deferral: TimeInterval = 4 * 60 * 60
    private let coordinator: UpdateCoordinator
    private let clock: UpdateClock
    private let store: UpdatePolicyPersisting
    private var timer: Timer?
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
            case .available: self.store.lastSuccessfulCheck = self.clock.now; self.wasChecking = false
            case .failed: self.wasChecking = false
            default: break
            }
        }
    }

    func start() {
        guard timer == nil else { return }
        catchUpIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: Self.cadence, repeats: true) { [weak self] _ in Task { @MainActor in self?.catchUpIfNeeded() } }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.catchUpIfNeeded() } }
    }
    func stop() { timer?.invalidate(); timer = nil; if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }; wakeObserver = nil }
    func manualCheck() { _ = coordinator.checkForUpdates() }
    func catchUpIfNeeded() {
        guard store.lastSuccessfulCheck.map({ clock.now.timeIntervalSince($0) >= Self.cadence }) ?? true else { return }
        _ = coordinator.checkForUpdates()
    }
    @discardableResult
    func deferVersion(_ version: String) -> Date {
        let until = clock.now.addingTimeInterval(Self.deferral)
        store.deferredVersion = version
        store.deferredUntil = until
        return until
    }
    func shouldPresent(version: String) -> Bool {
        guard store.deferredVersion == version, let until = store.deferredUntil else { return true }
        return clock.now >= until
    }
    func suppressionUntil(version: String) -> Date? {
        guard store.deferredVersion == version,
              let until = store.deferredUntil,
              clock.now < until else { return nil }
        return until
    }
    func clearDeferralIfSuperseded(by version: String) { if store.deferredVersion != version { store.deferredVersion = nil; store.deferredUntil = nil } }
}
