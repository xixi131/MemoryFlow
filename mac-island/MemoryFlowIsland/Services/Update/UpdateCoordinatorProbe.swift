import Foundation

enum UpdateCoordinatorProbeError: Error { case failed(String) }

@MainActor
enum UpdateCoordinatorProbe {
    static func run(fixtures: URL) async throws -> String {
        let publicKey = try String(contentsOf: fixtures.appendingPathComponent("public_ed_key.txt"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let config = try AppcastConfiguration(feedURL: URL(string: "https://updates.memoryflow.example/appcast.xml")!, publicEdKeyBase64: publicKey)
        let verifier = SignedAppcastVerifier(configuration: config)

        let currentData = try Data(contentsOf: fixtures.appendingPathComponent("current.xml"))
        guard try verifier.release(from: currentData, currentBuild: "100", fixtureRoot: fixtures) == nil else { throw UpdateCoordinatorProbeError.failed("current release offered") }
        let newerData = try Data(contentsOf: fixtures.appendingPathComponent("newer.xml"))
        guard try verifier.release(from: newerData, currentBuild: "100", fixtureRoot: fixtures)?.build == "101" else { throw UpdateCoordinatorProbeError.failed("newer release missing") }
        do { _ = try verifier.release(from: Data("<rss>".utf8), currentBuild: "100", fixtureRoot: fixtures); throw UpdateCoordinatorProbeError.failed("malformed feed accepted") } catch UpdateFailure.invalidFeed { }
        do { _ = try AppcastConfiguration(feedURL: URL(string: "http://updates.memoryflow.example/appcast.xml")!, publicEdKeyBase64: publicKey); throw UpdateCoordinatorProbeError.failed("HTTP feed accepted") } catch UpdateFailure.invalidConfiguration { }
        let invalidData = try Data(contentsOf: fixtures.appendingPathComponent("invalid-signature.xml"))
        do { _ = try verifier.release(from: invalidData, currentBuild: "100", fixtureRoot: fixtures); throw UpdateCoordinatorProbeError.failed("invalid signature accepted") } catch UpdateFailure.signatureRejected { }

        let engine = ProbeEngine()
        let coordinator = UpdateCoordinator(engine: engine)
        guard coordinator.checkForUpdates(), !coordinator.checkForUpdates() else { throw UpdateCoordinatorProbeError.failed("duplicate check guard failed") }
        let active = engine.lastSession!
        engine.emit(.available(UpdateRelease(version: "1.0.1", build: "101", downloadURL: URL(string: "https://updates.memoryflow.example/MemoryFlow.zip")!, contentLength: 12)), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .available = coordinator.state else { throw UpdateCoordinatorProbeError.failed("available state missing") }
        guard coordinator.downloadAvailableUpdate(), !coordinator.downloadAvailableUpdate() else { throw UpdateCoordinatorProbeError.failed("duplicate download guard failed") }
        engine.emit(.downloadProgress(receivedBytes: 8, totalBytes: 12), sessionID: UUID())
        engine.emit(.downloadProgress(receivedBytes: 4, totalBytes: 12), sessionID: active)
        engine.emit(.downloadProgress(receivedBytes: 2, totalBytes: 12), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .downloading(_, 4, 12) = coordinator.state else { throw UpdateCoordinatorProbeError.failed("stale or regressive progress applied") }
        engine.emit(.downloadFinished, sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .ready = coordinator.state, coordinator.installReadyUpdate() else { throw UpdateCoordinatorProbeError.failed("ready/install states missing") }
        guard case .installing = coordinator.state else { throw UpdateCoordinatorProbeError.failed("installing state missing") }

        let deferredEngine = ProbeEngine()
        let deferred = UpdateCoordinator(engine: deferredEngine)
        _ = deferred.checkForUpdates()
        deferredEngine.emit(.available(UpdateRelease(version: "1.0.1", build: "101", downloadURL: URL(string: "https://updates.memoryflow.example/MemoryFlow.zip")!, contentLength: nil)), sessionID: deferredEngine.lastSession!)
        try await Task.sleep(for: .milliseconds(20))
        guard deferred.deferAvailableUpdate(until: Date(timeIntervalSince1970: 10)), case .deferred = deferred.state else { throw UpdateCoordinatorProbeError.failed("deferred state missing") }

        let failedEngine = ProbeEngine()
        let failed = UpdateCoordinator(engine: failedEngine)
        _ = failed.checkForUpdates()
        failedEngine.emit(.failed(.transport("probe")), sessionID: failedEngine.lastSession!)
        try await Task.sleep(for: .milliseconds(20))
        guard case .failed(.transport("probe")) = failed.state else { throw UpdateCoordinatorProbeError.failed("failed state missing") }
        failed.resetFailure()
        guard case .idle = failed.state else { throw UpdateCoordinatorProbeError.failed("idle reset missing") }
        return "update-coordinator-probe: PASS; signed=current,newer,malformed,http,invalid-signature; guards=check,download,stale,regressive; states=idle,checking,available,deferred,downloading,ready,installing,failed"
    }
}

private final class ProbeEngine: UpdateEngine {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)?
    var lastSession: UUID?
    func check(sessionID: UUID) { lastSession = sessionID }
    func download(_ release: UpdateRelease, sessionID: UUID) {}
    func install(_ release: UpdateRelease, sessionID: UUID) { emit(.installationStarted, sessionID: sessionID) }
    func emit(_ event: UpdateEngineEvent, sessionID: UUID) { eventHandler?(sessionID, event) }
}
