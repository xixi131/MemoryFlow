import Combine
import Foundation

@MainActor
final class UpdateCoordinator: ObservableObject {
    @Published private(set) var state: UpdateState = .idle

    private let engine: UpdateEngine
    private let clock: UpdateClock
    private var activeSessionID: UUID?
    private var selectedRelease: UpdateRelease?
    private var handlingEvent = false

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
        state = .downloading(release, receivedBytes: 0, totalBytes: release.contentLength)
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
        case .downloadProgress(let received, let total):
            guard case .downloading(let release, let previous, _) = state else { return }
            guard received >= previous else { return }
            state = .downloading(release, receivedBytes: received, totalBytes: total ?? release.contentLength)
        case .downloadFinished:
            guard case .downloading(let release, _, _) = state else { return }
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
    }
}
