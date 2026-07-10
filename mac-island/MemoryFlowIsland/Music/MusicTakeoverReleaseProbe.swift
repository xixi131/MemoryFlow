import Foundation

/// Deterministic release coverage for paused, resumed, and stopped mock playback.
enum MusicTakeoverReleaseProbe {
    static func validate() throws {
        try validatePausedResumeCancelsTimeout()
        try validatePausedTimeoutReleasesMusicContent()
        try validateStoppedReleasesMusicContent()
        try validateReducerReleaseKeepsAppPresentation()
    }

    private static func validatePausedResumeCancelsTimeout() throws {
        let provider = ReleaseProbeProvider(snapshot: pausedSnapshot)
        let controller = MusicTakeoverController(
            provider: provider,
            pollingInterval: 60,
            pausedTimeout: 0.02
        )
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
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
        let provider = ReleaseProbeProvider(snapshot: pausedSnapshot)
        let controller = MusicTakeoverController(
            provider: provider,
            pollingInterval: 60,
            pausedTimeout: 0.01
        )
        var updates: [MusicTakeoverUpdate] = []
        controller.onUpdate = { updates.append($0) }
        controller.start()
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

    init(snapshot: MusicTrackSnapshot) {
        self.snapshot = snapshot
    }

    func start() {}
    func stop() {}
    func currentSnapshot() -> MusicTrackSnapshot { snapshot }
    func sendCommand(_: MusicCommand) {}

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
}
