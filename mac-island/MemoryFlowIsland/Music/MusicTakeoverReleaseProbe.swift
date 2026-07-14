import Foundation

/// Deterministic release coverage for paused, resumed, and stopped mock playback.
enum MusicTakeoverReleaseProbe {
    static func validate() throws {
        try validatePausedResumeCancelsTimeout()
        try validatePausedTimeoutReleasesMusicContent()
        try validateStoppedReleasesMusicContent()
        try validateReducerReleaseKeepsAppPresentation()
        try validatePlaybackProgressStaysLocal()
        try validateTransportAndSeekRouting()
        try validateSeekIgnoresStaleProviderPosition()
        try validatePlaybackToggleDoesNotFlashToZero()
        try validateAppleMusicSeekCommand()
    }

    private static func validatePausedResumeCancelsTimeout() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(
            provider: provider,
            pollingInterval: 60,
            pausedTimeout: 0.02
        )
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
        drainMainRunLoop(for: 0.01)
        provider.emit(pausedSnapshot)
        provider.emit(playingSnapshot)
        drainMainRunLoop(for: 0.04)
        controller.stop()

        guard updates.contains(where: { update in
            if case let .musicSnapshotUpdated(snapshot) = update.intent {
                return snapshot.status == .playing
            }
            return false
        }), updates.contains(where: { $0.intent == .pausedMusicTimeout }) == false else {
            throw MusicTakeoverReleaseProbeError.pausedResumeDidNotCancelTimeout
        }
    }

    private static func validatePausedTimeoutReleasesMusicContent() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(
            provider: provider,
            pollingInterval: 60,
            pausedTimeout: 0.01
        )
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
        drainMainRunLoop(for: 0.01)
        provider.emit(pausedSnapshot)
        drainMainRunLoop(for: 0.03)
        controller.stop()

        guard updates.contains(where: { $0.intent == .pausedMusicTimeout }) else {
            throw MusicTakeoverReleaseProbeError.pausedTimeoutDidNotFire
        }
    }

    private static func validateStoppedReleasesMusicContent() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(
            provider: provider,
            pollingInterval: 60,
            pausedTimeout: 60
        )
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
        drainMainRunLoop(for: 0.01)
        provider.emit(.stopped)
        drainMainRunLoop(for: 0.01)
        controller.stop()

        guard updates.last?.intent == .musicStopped else {
            throw MusicTakeoverReleaseProbeError.stoppedDidNotReleaseImmediately
        }
    }

    private static func validateReducerReleaseKeepsAppPresentation() throws {
        var todoActivity = IslandDomainState.musicActivityWithAppFallback
        todoActivity.appDisplayMode = .todo
        todoActivity.forceCompactMode = false
        todoActivity.mockSources.review = nil
        todoActivity.mockSources.todo = .scenarioSample

        let stopped = IslandPresentationReducer.reduce(
            current: todoActivity,
            intent: .musicStopped
        )
        var compactTodo = todoActivity
        compactTodo.forceCompactMode = true
        let timedOut = IslandPresentationReducer.reduce(
            current: compactTodo,
            intent: .pausedMusicTimeout
        )
        let ignoredLoggedOut = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .musicStopped
        )

        guard stopped.state.primaryMode == .app,
              stopped.state.appDisplayMode == .todo,
              stopped.state.forceCompactMode == false,
              stopped.state.presentationState == .activity,
              stopped.derivedState.previewContent.kind == .todoActivity,
              stopped.derivedState.previewContent.music == nil,
              timedOut.state.primaryMode == .app,
              timedOut.state.forceCompactMode,
              timedOut.state.presentationState == .collapsed,
              timedOut.derivedState.previewContent.kind == .todoCompact,
              timedOut.derivedState.previewContent.music == nil,
              ignoredLoggedOut.reason == .intentIgnored else {
            throw MusicTakeoverReleaseProbeError.reducerLeftMusicContent
        }
    }

    private static func validateTransportAndSeekRouting() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(provider: provider, pollingInterval: 60)
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
        drainMainRunLoop(for: 0.01)
        controller.sendCommand(.previous)
        controller.sendCommand(.playPause)
        controller.sendCommand(.next)
        let didSeek = controller.seek(to: 90)
        controller.stop()

        guard provider.commands == [.previous, .playPause, .next],
              provider.seekPositions == [90],
              didSeek,
              updates.contains(where: { update in
                  if case let .musicSnapshotUpdated(snapshot) = update.intent {
                      return snapshot.position == 90
                  }
                  return false
              }) else {
            throw MusicTakeoverReleaseProbeError.transportOrSeekWasNotRouted
        }
    }

    private static func validatePlaybackProgressStaysLocal() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(provider: provider, pollingInterval: 60)
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
        drainMainRunLoop(for: 0.01)
        let initialUpdateCount = updates.count

        var progressOnly = playingSnapshot
        progressOnly.position += 1
        progressOnly.updatedAt = Date()
        provider.emit(progressOnly)
        drainMainRunLoop(for: 0.01)
        controller.stop()

        guard initialUpdateCount == 1, updates.count == initialUpdateCount else {
            throw MusicTakeoverReleaseProbeError.playbackProgressEscapedLocalClock
        }
    }

    private static func validateSeekIgnoresStaleProviderPosition() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        provider.updatesSnapshotWhenSeeking = false
        let controller = MusicTakeoverController(provider: provider, pollingInterval: 60)
        var positions: [TimeInterval] = []
        controller.onUpdate = { update in
            if case let .musicSnapshotUpdated(snapshot) = update.intent {
                positions.append(snapshot.position)
            }
        }
        controller.start()
        drainMainRunLoop(for: 0.01)
        _ = controller.seek(to: 90)
        provider.emit(playingSnapshot)
        drainMainRunLoop(for: 0.01)
        controller.stop()

        guard positions.last == 90, positions.dropFirst(2).contains(12) == false else {
            throw MusicTakeoverReleaseProbeError.seekReturnedToStalePosition
        }
    }

    private static func validatePlaybackToggleDoesNotFlashToZero() throws {
        let provider = ReleaseProbeProvider(snapshot: playingSnapshot)
        let controller = MusicTakeoverController(provider: provider, pollingInterval: 60)
        var positions: [TimeInterval] = []
        controller.onUpdate = { update in
            if case let .musicSnapshotUpdated(snapshot) = update.intent {
                positions.append(snapshot.position)
            }
        }
        controller.start()
        drainMainRunLoop(for: 0.01)
        let confirmedPause = pausedSnapshot
        provider.emit(confirmedPause)
        var zeroPause = confirmedPause
        zeroPause.position = 0
        provider.emit(zeroPause)
        provider.emit(confirmedPause)

        var confirmedResume = playingSnapshot
        confirmedResume.position = confirmedPause.position
        provider.emit(confirmedResume)
        var zeroResume = confirmedResume
        zeroResume.position = 0
        provider.emit(zeroResume)
        drainMainRunLoop(for: 0.01)
        controller.stop()

        guard positions.last == confirmedResume.position,
              positions.contains(0) == false else {
            throw MusicTakeoverReleaseProbeError.playbackToggleFlashedToZero
        }
    }

    private static func validateAppleMusicSeekCommand() throws {
        var scripts: [String] = []
        let provider = AppleMusicProvider { script in
            scripts.append(script)
            return script.contains("set player position to 42.500") ? "ok" : nil
        }
        provider.start()
        let didSeek = provider.seek(to: 42.5)
        provider.stop()

        guard didSeek,
              scripts.filter({ $0.contains("set player position to 42.500") }).count == 1 else {
            throw MusicTakeoverReleaseProbeError.appleMusicSeekWasNotRouted
        }
    }

    private static var playingSnapshot: MusicTrackSnapshot {
        MusicTrackSnapshot.mockPlaybackStart
    }

    private static var pausedSnapshot: MusicTrackSnapshot {
        var snapshot = MusicTrackSnapshot.mockPlaybackStart
        snapshot.status = .paused
        snapshot.isPlaying = false
        return snapshot
    }

    private static func drainMainRunLoop(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
}

private final class ReleaseProbeProvider: MusicEventProvider {
    let sourceName = "Release Probe"
    var onSnapshot: ((MusicTrackSnapshot) -> Void)?
    private var snapshot: MusicTrackSnapshot
    private(set) var commands: [MusicCommand] = []
    private(set) var seekPositions: [TimeInterval] = []
    var updatesSnapshotWhenSeeking = true

    init(snapshot: MusicTrackSnapshot) {
        self.snapshot = snapshot
    }

    func start() {}
    func stop() {}
    func currentSnapshot() -> MusicTrackSnapshot { snapshot }
    func sendCommand(_ command: MusicCommand) {
        commands.append(command)
    }

    func seek(to position: TimeInterval) -> Bool {
        seekPositions.append(position)
        if updatesSnapshotWhenSeeking {
            snapshot.position = position
        }
        return true
    }

    func emit(_ snapshot: MusicTrackSnapshot) {
        self.snapshot = snapshot
        onSnapshot?(snapshot)
    }
}

enum MusicTakeoverReleaseProbeError: Error {
    case pausedResumeDidNotCancelTimeout
    case pausedTimeoutDidNotFire
    case stoppedDidNotReleaseImmediately
    case reducerLeftMusicContent
    case playbackProgressEscapedLocalClock
    case transportOrSeekWasNotRouted
    case seekReturnedToStalePosition
    case playbackToggleFlashedToZero
    case appleMusicSeekWasNotRouted
}
