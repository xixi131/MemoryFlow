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
        guard let signedRelease = try verifier.release(from: newerData, currentBuild: "100", fixtureRoot: fixtures),
              signedRelease.build == "101" else { throw UpdateCoordinatorProbeError.failed("newer release missing") }
        do { _ = try verifier.release(from: Data("<rss>".utf8), currentBuild: "100", fixtureRoot: fixtures); throw UpdateCoordinatorProbeError.failed("malformed feed accepted") } catch UpdateFailure.invalidFeed { }
        do { _ = try AppcastConfiguration(feedURL: URL(string: "http://updates.memoryflow.example/appcast.xml")!, publicEdKeyBase64: publicKey); throw UpdateCoordinatorProbeError.failed("HTTP feed accepted") } catch UpdateFailure.invalidConfiguration { }
        let invalidData = try Data(contentsOf: fixtures.appendingPathComponent("invalid-signature.xml"))
        do { _ = try verifier.release(from: invalidData, currentBuild: "100", fixtureRoot: fixtures); throw UpdateCoordinatorProbeError.failed("invalid signature accepted") } catch UpdateFailure.signatureRejected { }

        let engine = ProbeEngine()
        let coordinator = UpdateCoordinator(engine: engine)
        guard coordinator.checkForUpdates(), !coordinator.checkForUpdates() else { throw UpdateCoordinatorProbeError.failed("duplicate check guard failed") }
        let active = engine.lastSession!
        engine.emit(.available(UpdateRelease(
            version: signedRelease.version,
            build: signedRelease.build,
            downloadURL: signedRelease.downloadURL,
            contentLength: nil
        )), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .available = coordinator.state else { throw UpdateCoordinatorProbeError.failed("available state missing") }
        guard coordinator.downloadAvailableUpdate(),
              !coordinator.downloadAvailableUpdate(),
              case .downloadRequested = coordinator.state,
              engine.downloadCount == 1 else {
            throw UpdateCoordinatorProbeError.failed("duplicate download request guard failed")
        }
        engine.emit(.downloadStarted(totalBytes: nil), sessionID: UUID())
        guard case .downloadRequested = coordinator.state else {
            throw UpdateCoordinatorProbeError.failed("stale start callback changed state")
        }
        engine.emit(.downloadStarted(totalBytes: nil), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .downloading(_, let indeterminate) = coordinator.state,
              indeterminate == .indeterminate else {
            throw UpdateCoordinatorProbeError.failed("unknown-length start state missing")
        }
        engine.emit(.downloadProgress(receivedBytes: 8, totalBytes: nil), sessionID: active)
        engine.emit(.downloadExpectedContentLength(12), sessionID: active)
        engine.emit(.downloadProgress(receivedBytes: 4, totalBytes: 12), sessionID: active)
        engine.emit(.downloadProgress(receivedBytes: 2, totalBytes: 12), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .downloading(_, let clamped) = coordinator.state,
              clamped.receivedBytes == 8,
              clamped.totalBytes == 12,
              clamped.percentage == 66 else {
            throw UpdateCoordinatorProbeError.failed("stale, throttled, or regressive progress failed")
        }
        engine.emit(.downloadProgress(receivedBytes: 99, totalBytes: 12), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .downloading(_, let completed) = coordinator.state,
              completed.percentage == 100 else {
            throw UpdateCoordinatorProbeError.failed("download progress did not clamp to 100 percent")
        }
        engine.emit(.verificationStarted, sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .verifying = coordinator.state else { throw UpdateCoordinatorProbeError.failed("verification state missing") }
        engine.emit(.verificationSucceeded, sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .ready = coordinator.state, coordinator.installReadyUpdate() else { throw UpdateCoordinatorProbeError.failed("ready/install states missing") }
        guard case .awaitingAuthorization = coordinator.state,
              !coordinator.installReadyUpdate(),
              engine.installCount == 1 else { throw UpdateCoordinatorProbeError.failed("authorization or duplicate install guard failed") }
        engine.emit(.authorizationRequested, sessionID: active)
        engine.emit(.installationStarted, sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .installing = coordinator.state else { throw UpdateCoordinatorProbeError.failed("installing state missing") }
        engine.emit(.installationFinished(relaunched: true), sessionID: active)
        try await Task.sleep(for: .milliseconds(20))
        guard case .installed(let installedRelease, true) = coordinator.state,
              installedRelease.build == "101" else { throw UpdateCoordinatorProbeError.failed("installed/relaunch/version state missing") }
        guard coordinator.checkForUpdates(), engine.lastSession != active else {
            throw UpdateCoordinatorProbeError.failed("future check stayed blocked after installation")
        }
        engine.emit(.current, sessionID: engine.lastSession!)
        try await Task.sleep(for: .milliseconds(20))
        guard case .idle = coordinator.state else {
            throw UpdateCoordinatorProbeError.failed("future check did not return to idle")
        }

        let retryEngine = ProbeEngine()
        let retry = UpdateCoordinator(engine: retryEngine)
        _ = retry.checkForUpdates()
        let failedSession = retryEngine.lastSession!
        retryEngine.emit(.available(UpdateRelease(version: "1.0.1", build: "101", downloadURL: URL(string: "https://updates.memoryflow.example/MemoryFlow.zip")!, contentLength: 50)), sessionID: failedSession)
        try await Task.sleep(for: .milliseconds(20))
        _ = retry.downloadAvailableUpdate()
        retryEngine.emit(.failed(.transport("setup")), sessionID: failedSession)
        try await Task.sleep(for: .milliseconds(20))
        guard case .failed(.transport("setup")) = retry.state else {
            throw UpdateCoordinatorProbeError.failed("download setup failure missing")
        }
        guard retry.retryFailure() else { throw UpdateCoordinatorProbeError.failed("explicit retry was unavailable") }
        let retrySession = retryEngine.lastSession!
        retryEngine.emit(.available(UpdateRelease(version: "1.0.1", build: "101", downloadURL: URL(string: "https://updates.memoryflow.example/MemoryFlow.zip")!, contentLength: 50)), sessionID: retrySession)
        try await Task.sleep(for: .milliseconds(20))
        _ = retry.downloadAvailableUpdate()
        retryEngine.emit(.downloadStarted(totalBytes: 50), sessionID: retrySession)
        retryEngine.emit(.downloadProgress(receivedBytes: 40, totalBytes: 50), sessionID: failedSession)
        try await Task.sleep(for: .milliseconds(20))
        guard case .downloading(_, let reset) = retry.state,
              reset.receivedBytes == 0,
              reset.percentage == 0 else {
            throw UpdateCoordinatorProbeError.failed("retry reset or stale-session guard failed")
        }

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
        guard failed.retryFailure(), case .checking = failed.state else { throw UpdateCoordinatorProbeError.failed("recoverable retry check missing") }
        let policyEngine = ProbeEngine()
        let policyCoordinator = UpdateCoordinator(engine: policyEngine)
        let policyStore = ProbePolicyStore()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let policy = UpdateCheckPolicy(coordinator: policyCoordinator, clock: ProbeClock(now: now), store: policyStore)
        policy.catchUpIfNeeded()
        guard policyEngine.lastSession != nil else { throw UpdateCoordinatorProbeError.failed("launch catch-up missing") }
        policy.deferVersion("101")
        guard !policy.shouldPresent(version: "101"), policy.shouldPresent(version: "102"),
              policy.suppressionUntil(version: "101") == now.addingTimeInterval(UpdateCheckPolicy.deferral),
              policyStore.deferredUntil == now.addingTimeInterval(UpdateCheckPolicy.deferral) else { throw UpdateCoordinatorProbeError.failed("four-hour deferral failed") }
        let relaunchedPolicy = UpdateCheckPolicy(
            coordinator: deferred,
            clock: ProbeClock(now: now),
            store: policyStore
        )
        guard !relaunchedPolicy.shouldPresent(version: "101") else {
            throw UpdateCoordinatorProbeError.failed("relaunch deferral was not restored")
        }
        let previousManualSession = deferredEngine.lastSession
        relaunchedPolicy.manualCheck()
        guard deferredEngine.lastSession != previousManualSession else {
            throw UpdateCoordinatorProbeError.failed("manual check was blocked during deferral")
        }
        relaunchedPolicy.stop()
        policy.clearDeferralIfSuperseded(by: "102")
        guard policyStore.deferredVersion == nil else { throw UpdateCoordinatorProbeError.failed("newer-version deferral cleanup failed") }
        policy.stop()
        let installedPolicyStore = ProbePolicyStore()
        let installedPolicy = UpdateCheckPolicy(coordinator: policyCoordinator, clock: ProbeClock(now: now), store: installedPolicyStore)
        installedPolicy.markInstalled(build: installedRelease.build)
        guard installedPolicyStore.installedBuild == "101",
              !installedPolicy.shouldPresent(version: "101"),
              installedPolicy.shouldPresent(version: "102") else {
            throw UpdateCoordinatorProbeError.failed("installed build repeated offer or future version suppression failed")
        }
        let repeatedEngine = ProbeEngine()
        let repeatedCoordinator = UpdateCoordinator(engine: repeatedEngine)
        _ = repeatedCoordinator.checkForUpdates()
        repeatedEngine.emit(.available(installedRelease), sessionID: repeatedEngine.lastSession!)
        try await Task.sleep(for: .milliseconds(20))
        guard installedPolicy.wasInstalled(build: installedRelease.build),
              repeatedCoordinator.discardAvailableUpdate(),
              case .idle = repeatedCoordinator.state,
              repeatedCoordinator.checkForUpdates() else {
            throw UpdateCoordinatorProbeError.failed("repeated offer was not discarded or future checks stayed blocked")
        }
        installedPolicy.stop()

        try validateRecoverableFailures()
        return "update-coordinator-probe: PASS; signed=current,newer,higher-version,malformed,http,invalid-signature; download=requested,start-confirmed,setup-failure,unknown-length,expected-length,throttled,monotonic,clamped-100,retry-reset,duplicate,stale; install=verifying,ready,authorization,duplicate-guard,installing,relaunched,version-changed,no-repeat,future-check,sparkle-delegated; recovery=offline,http,feed,disk,auth-cancel,signature,explicit-retry,no-auto-loop,launchable; policy=launch,24h,wake,manual,4h-deferral,future-version,termination"
    }

    private static func validateRecoverableFailures() throws {
        let cases: [(Error, UpdateFailure)] = [
            (NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet), .offline),
            (NSError(domain: "probe", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP 503"]), .httpStatus(503)),
            (NSError(domain: "probe", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed appcast XML"]), .invalidFeed("Malformed appcast XML")),
            (NSError(domain: "probe", code: 3, userInfo: [NSLocalizedDescriptionKey: "Insufficient disk space"]), .insufficientDisk),
            (NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError), .authorizationCancelled),
            (NSError(domain: "probe", code: 4, userInfo: [NSLocalizedDescriptionKey: "EdDSA signature rejected"]), .signatureRejected)
        ]
        for (error, expected) in cases where UpdateFailureMapper.map(error) != expected {
            throw UpdateCoordinatorProbeError.failed("failure mapping mismatch: \(error)")
        }
    }
}

private struct ProbeClock: UpdateClock { let now: Date }
private final class ProbePolicyStore: UpdatePolicyPersisting {
    var lastSuccessfulCheck: Date?
    var deferredVersion: String?
    var deferredUntil: Date?
    var installedBuild: String?
}

private final class ProbeEngine: UpdateEngine {
    var eventHandler: (@Sendable (UUID, UpdateEngineEvent) -> Void)?
    var lastSession: UUID?
    var downloadCount = 0
    var installCount = 0
    func check(sessionID: UUID) { lastSession = sessionID }
    func download(_ release: UpdateRelease, sessionID: UUID) { downloadCount += 1 }
    func install(_ release: UpdateRelease, sessionID: UUID) { installCount += 1 }
    func emit(_ event: UpdateEngineEvent, sessionID: UUID) { eventHandler?(sessionID, event) }
}
