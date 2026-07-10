import Foundation

struct MusicTakeoverUpdate: Equatable {
    let intent: IslandInteractionIntent
    let commandToSend: MusicCommand?
}

final class MusicTakeoverController {
    var onUpdate: ((MusicTakeoverUpdate) -> Void)?

    private let provider: MusicProvider
    private let pollingInterval: TimeInterval
    private let pausedTimeout: TimeInterval
    private let driftSyncThreshold: TimeInterval
    private var pollingTimer: Timer?
    private var progressTimer: Timer?
    private var pausedTimeoutWorkItem: DispatchWorkItem?
    private var lastForwardedSnapshot: MusicTrackSnapshot?
    private var localSnapshot: MusicTrackSnapshot?
    private var isRunning = false

    init(
        provider: MusicProvider = MediaRemoteMusicProvider(),
        pollingInterval: TimeInterval = 1,
        pausedTimeout: TimeInterval = 30,
        driftSyncThreshold: TimeInterval = 2
    ) {
        self.provider = provider
        self.pollingInterval = pollingInterval
        self.pausedTimeout = pausedTimeout
        self.driftSyncThreshold = driftSyncThreshold
        if let eventProvider = provider as? MusicEventProvider {
            eventProvider.onSnapshot = { [weak self] snapshot in
                DispatchQueue.main.async {
                    self?.handleProviderSnapshot(snapshot)
                }
            }
        }
    }

    func start() {
        guard isRunning == false else { return }
        isRunning = true
        provider.start()
        print("[MusicTakeover] Started provider=\(provider.sourceName)")
        pollProvider()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.pollProvider()
        }
    }

    func stop() {
        isRunning = false
        pollingTimer?.invalidate()
        pollingTimer = nil
        stopProgressTimer()
        pausedTimeoutWorkItem?.cancel()
        pausedTimeoutWorkItem = nil
        provider.stop()
        print("[MusicTakeover] Stopped provider=\(provider.sourceName)")
    }

    func sendCommand(_ command: MusicCommand) {
        provider.sendCommand(command)
        onUpdate?(MusicTakeoverUpdate(intent: .musicCommandRequested(command.horizontalCommand), commandToSend: command))
        pollProvider()
    }

    private func pollProvider() {
        let providerSnapshot = provider.currentSnapshot()
        print("[MusicTakeover] Poll status=\(providerSnapshot.status.rawValue) title=\(providerSnapshot.title) source=\(providerSnapshot.source)")
        handleProviderSnapshot(providerSnapshot)
    }

    private func handleProviderSnapshot(_ providerSnapshot: MusicTrackSnapshot) {
        switch providerSnapshot.status {
        case .playing, .paused:
            updateLocalSnapshot(from: providerSnapshot)
            guard let localSnapshot else { return }
            forwardSnapshotIfNeeded(localSnapshot)
            handlePlaybackTimers(for: localSnapshot)
        case .stopped:
            clearMusicState()
        case .unknown:
            stopProgressTimer()
        }
    }

    private func updateLocalSnapshot(from providerSnapshot: MusicTrackSnapshot) {
        guard var current = localSnapshot else {
            localSnapshot = providerSnapshot
            return
        }

        let titleChanged = current.title != providerSnapshot.title ||
            current.artist != providerSnapshot.artist
        current.title = providerSnapshot.title
        current.artist = providerSnapshot.artist
        current.album = providerSnapshot.album
        current.status = providerSnapshot.status
        current.isPlaying = providerSnapshot.isPlaying
        current.duration = providerSnapshot.duration
        current.source = providerSnapshot.source
        current.updatedAt = providerSnapshot.updatedAt
        current.capabilities = providerSnapshot.capabilities
        current.themeColorHex = providerSnapshot.themeColorHex

        if providerSnapshot.artworkData != nil || titleChanged {
            current.artworkData = providerSnapshot.artworkData
        }

        let drift = abs(current.position - providerSnapshot.position)
        if titleChanged || drift > driftSyncThreshold || providerSnapshot.isPlaying == false {
            current.position = providerSnapshot.position
        }

        localSnapshot = current
    }

    private func handlePlaybackTimers(for snapshot: MusicTrackSnapshot) {
        if snapshot.isPlaying {
            pausedTimeoutWorkItem?.cancel()
            pausedTimeoutWorkItem = nil
            startProgressTimerIfNeeded()
        } else {
            stopProgressTimer()
            schedulePausedTimeout()
        }
    }

    private func startProgressTimerIfNeeded() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceLocalProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func advanceLocalProgress() {
        guard var snapshot = localSnapshot, snapshot.isPlaying else { return }
        let duration = snapshot.duration ?? 0
        let nextPosition = snapshot.position + 1
        snapshot.position = duration > 0 ? min(nextPosition, duration) : nextPosition
        snapshot.updatedAt = Date()
        localSnapshot = snapshot
        forwardSnapshotIfNeeded(snapshot)
    }

    private func schedulePausedTimeout() {
        guard pausedTimeoutWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.pausedTimeoutWorkItem = nil
            self?.localSnapshot = nil
            self?.lastForwardedSnapshot = nil
            self?.onUpdate?(MusicTakeoverUpdate(intent: .pausedMusicTimeout, commandToSend: nil))
        }
        pausedTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + pausedTimeout, execute: workItem)
    }

    private func clearMusicState() {
        pausedTimeoutWorkItem?.cancel()
        pausedTimeoutWorkItem = nil
        stopProgressTimer()
        localSnapshot = nil
        lastForwardedSnapshot = nil
        onUpdate?(MusicTakeoverUpdate(intent: .musicStopped, commandToSend: nil))
    }

    private func forwardSnapshotIfNeeded(_ snapshot: MusicTrackSnapshot) {
        guard shouldForward(snapshot) else { return }
        lastForwardedSnapshot = snapshot
        print("[MusicTakeover] Forward status=\(snapshot.status.rawValue) title=\(snapshot.title) artist=\(snapshot.artist)")
        onUpdate?(MusicTakeoverUpdate(intent: .musicSnapshotUpdated(snapshot), commandToSend: nil))
    }

    private func shouldForward(_ next: MusicTrackSnapshot) -> Bool {
        guard let previous = lastForwardedSnapshot else {
            return true
        }

        if next.status != previous.status { return true }
        if next.isPlaying != previous.isPlaying { return true }
        if next.title != previous.title { return true }
        if next.artist != previous.artist { return true }
        if next.artworkData != previous.artworkData { return true }
        if next.themeColorHex != previous.themeColorHex { return true }
        if next.duration != previous.duration { return true }
        if abs(next.position - previous.position) >= 1 { return true }
        return false
    }
}
