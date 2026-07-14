import Foundation

struct MusicTakeoverUpdate: Equatable {
    let intent: IslandInteractionIntent
    let commandToSend: MusicCommand?
}

final class MusicTakeoverController {
    var onUpdate: ((MusicTakeoverUpdate) -> Void)?
    let waveformModel: MusicWaveformModel

    private let provider: MusicProvider
    private let audioCapture: MusicAudioCaptureProviding
    private let pollingInterval: TimeInterval
    private let pausedTimeout: TimeInterval
    private let driftSyncThreshold: TimeInterval
    private let paletteQueue = DispatchQueue(
        label: "com.memoryflow.island.music-palette",
        qos: .userInitiated
    )
    private let providerQueue = DispatchQueue(
        label: "com.memoryflow.island.music-provider",
        qos: .userInitiated
    )
    private var pollingTimer: Timer?
    private var progressTimer: Timer?
    private var pausedTimeoutWorkItem: DispatchWorkItem?
    private var postCommandRefreshWorkItems: [DispatchWorkItem] = []
    private var lastForwardedSnapshot: MusicTrackSnapshot?
    private var localSnapshot: MusicTrackSnapshot?
    private var paletteCache: [Int: MusicThemePalette] = [:]
    private var pendingPaletteKeys: Set<Int> = []
    private var isPollInFlight = false
    private var pollGeneration = 0
    private var activeAudioCaptureBundleIdentifier: String?
    private var positionHold: MusicPositionHold?
    private var isRunning = false

    init(
        provider: MusicProvider = MediaRemoteMusicProvider(),
        audioCapture: MusicAudioCaptureProviding = CoreAudioMusicCapture(),
        waveformModel: MusicWaveformModel = MusicWaveformModel(),
        pollingInterval: TimeInterval = 1,
        pausedTimeout: TimeInterval = 30,
        driftSyncThreshold: TimeInterval = 2
    ) {
        self.provider = provider
        self.audioCapture = audioCapture
        self.waveformModel = waveformModel
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
        audioCapture.onFrame = { [weak waveformModel] frame in
            DispatchQueue.main.async {
                waveformModel?.publish(frame)
            }
        }
        audioCapture.onStateChange = { [weak self, weak waveformModel] state in
            DispatchQueue.main.async {
                if state == .unavailable {
                    self?.activeAudioCaptureBundleIdentifier = nil
                }
                if state != .capturing {
                    waveformModel?.settleToRest(captureState: state)
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
        pollGeneration += 1
        isPollInFlight = false
        stopProgressTimer()
        pausedTimeoutWorkItem?.cancel()
        pausedTimeoutWorkItem = nil
        cancelPostCommandRefreshes()
        activeAudioCaptureBundleIdentifier = nil
        positionHold = nil
        audioCapture.stopCapturing()
        waveformModel.settleToRest()
        providerQueue.async { [provider] in
            provider.stop()
        }
        print("[MusicTakeover] Stopped provider=\(provider.sourceName)")
    }

    func sendCommand(_ command: MusicCommand) {
        providerQueue.async { [provider] in
            provider.sendCommand(command)
        }
        onUpdate?(MusicTakeoverUpdate(intent: .musicCommandRequested(command.horizontalCommand), commandToSend: command))
        schedulePostCommandRefreshes(for: command)
    }

    @discardableResult
    func seek(to position: TimeInterval) -> Bool {
        guard var snapshot = localSnapshot else { return false }
        let upperBound = snapshot.duration.map { max(0, $0) }
        let target = min(max(0, position), upperBound ?? max(0, position))
        guard provider.seek(to: target) else {
            pollProvider()
            return false
        }

        snapshot.position = target
        snapshot.updatedAt = Date()
        localSnapshot = snapshot
        positionHold = MusicPositionHold(
            target: target,
            trackTitle: snapshot.title,
            artist: snapshot.artist,
            expiresAt: Date().addingTimeInterval(1.5),
            kind: .seek
        )
        forwardSnapshotIfNeeded(snapshot, force: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard self?.isRunning == true else { return }
            self?.pollProvider()
        }
        return true
    }

    private func pollProvider() {
        guard isRunning, isPollInFlight == false else { return }
        isPollInFlight = true
        pollGeneration += 1
        let generation = pollGeneration

        providerQueue.async { [weak self] in
            guard let self else { return }
            let providerSnapshot = self.provider.currentSnapshot()
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.pollGeneration else { return }
                self.isPollInFlight = false
                guard self.isRunning else { return }
                print("[MusicTakeover] Poll status=\(providerSnapshot.status.rawValue) title=\(providerSnapshot.title) source=\(providerSnapshot.source)")
                self.handleProviderSnapshot(providerSnapshot)
            }
        }
    }

    private func schedulePostCommandRefreshes(for command: MusicCommand) {
        cancelPostCommandRefreshes()
        let delays: [TimeInterval] = command == .playPause
            ? [0.18, 0.65]
            : [0.18, 0.65, 1.4, 2.8]
        postCommandRefreshWorkItems = delays.map { delay in
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.isRunning else { return }
                self.pollProvider()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            return workItem
        }
    }

    private func cancelPostCommandRefreshes() {
        postCommandRefreshWorkItems.forEach { $0.cancel() }
        postCommandRefreshWorkItems.removeAll()
    }

    private func handleProviderSnapshot(_ providerSnapshot: MusicTrackSnapshot) {
        synchronizeAudioCapture(for: providerSnapshot)
        switch providerSnapshot.status {
        case .playing, .paused:
            guard localSnapshot != nil || providerSnapshot.status == .playing else {
                return
            }
            var enrichedSnapshot = providerSnapshot
            applyCachedPalette(to: &enrichedSnapshot)
            schedulePaletteExtractionIfNeeded(for: enrichedSnapshot)
            let correctedPlaybackPosition = updateLocalSnapshot(from: enrichedSnapshot)
            guard let localSnapshot else { return }
            let forwarded = forwardSnapshotIfNeeded(
                localSnapshot,
                force: correctedPlaybackPosition
            )
            handlePlaybackTimers(for: localSnapshot, resetPausedTimeout: forwarded)
        case .stopped:
            clearMusicState()
        case .unknown:
            stopProgressTimer()
        }
    }

    @discardableResult
    private func updateLocalSnapshot(from providerSnapshot: MusicTrackSnapshot) -> Bool {
        guard var current = localSnapshot else {
            localSnapshot = providerSnapshot
            return false
        }

        let titleChanged = current.title != providerSnapshot.title ||
            current.artist != providerSnapshot.artist
        let playbackStateChanged = current.isPlaying != providerSnapshot.isPlaying
        current.title = providerSnapshot.title
        current.artist = providerSnapshot.artist
        current.album = providerSnapshot.album
        current.status = providerSnapshot.status
        current.isPlaying = providerSnapshot.isPlaying
        if providerSnapshot.duration != nil || titleChanged {
            current.duration = providerSnapshot.duration
        }
        current.source = providerSnapshot.source
        current.sourceBundleIdentifier = providerSnapshot.sourceBundleIdentifier
        current.updatedAt = providerSnapshot.updatedAt
        current.capabilities = providerSnapshot.capabilities
        current.themeColorHex = providerSnapshot.themeColorHex
        current.themePalette = providerSnapshot.themePalette

        if providerSnapshot.artworkData != nil || titleChanged {
            current.artworkData = providerSnapshot.artworkData
        }

        if titleChanged {
            positionHold = nil
        } else if playbackStateChanged, current.position > 1 {
            positionHold = MusicPositionHold(
                target: providerSnapshot.position > 0.001
                    ? providerSnapshot.position
                    : current.position,
                trackTitle: current.title,
                artist: current.artist,
                expiresAt: Date().addingTimeInterval(1.5),
                kind: .playbackTransition
            )
        }

        let providerPosition = reconciledProviderPosition(
            providerSnapshot.position,
            for: current,
            titleChanged: titleChanged
        )
        let drift = abs(current.position - providerPosition)
        let correctedPlaybackPosition = titleChanged ||
            drift > driftSyncThreshold ||
            providerSnapshot.isPlaying == false
        if correctedPlaybackPosition {
            current.position = providerPosition
        }

        localSnapshot = current
        return correctedPlaybackPosition && titleChanged == false && providerSnapshot.isPlaying
    }

    private func reconciledProviderPosition(
        _ providerPosition: TimeInterval,
        for current: MusicTrackSnapshot,
        titleChanged: Bool
    ) -> TimeInterval {
        guard titleChanged == false, let hold = positionHold else {
            return providerPosition
        }
        guard hold.matches(current) else {
            positionHold = nil
            return providerPosition
        }
        if abs(providerPosition - hold.target) <= 1.5 {
            if hold.kind == .seek {
                positionHold = nil
            }
            return providerPosition
        }
        guard Date() < hold.expiresAt else {
            positionHold = nil
            return providerPosition
        }
        return hold.target
    }

    private func handlePlaybackTimers(
        for snapshot: MusicTrackSnapshot,
        resetPausedTimeout: Bool
    ) {
        if snapshot.isPlaying {
            pausedTimeoutWorkItem?.cancel()
            pausedTimeoutWorkItem = nil
            startProgressTimerIfNeeded()
        } else {
            stopProgressTimer()
            if resetPausedTimeout {
                pausedTimeoutWorkItem?.cancel()
                pausedTimeoutWorkItem = nil
            }
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
        guard localSnapshot != nil || lastForwardedSnapshot != nil else { return }
        pausedTimeoutWorkItem?.cancel()
        pausedTimeoutWorkItem = nil
        stopProgressTimer()
        activeAudioCaptureBundleIdentifier = nil
        audioCapture.stopCapturing()
        waveformModel.settleToRest()
        localSnapshot = nil
        lastForwardedSnapshot = nil
        positionHold = nil
        onUpdate?(MusicTakeoverUpdate(intent: .musicStopped, commandToSend: nil))
    }

    private func synchronizeAudioCapture(for snapshot: MusicTrackSnapshot) {
        guard snapshot.isPlaying,
              let bundleIdentifier = snapshot.sourceBundleIdentifier,
              bundleIdentifier.isEmpty == false else {
            if activeAudioCaptureBundleIdentifier != nil {
                activeAudioCaptureBundleIdentifier = nil
                audioCapture.stopCapturing()
            }
            waveformModel.settleToRest(
                captureState: snapshot.isPlaying ? .unavailable : .idle
            )
            return
        }
        activeAudioCaptureBundleIdentifier = bundleIdentifier
        audioCapture.startCapturing(bundleIdentifier: bundleIdentifier)
    }

    @discardableResult
    private func forwardSnapshotIfNeeded(
        _ snapshot: MusicTrackSnapshot,
        force: Bool = false
    ) -> Bool {
        guard force || shouldForward(snapshot) else { return false }
        lastForwardedSnapshot = snapshot
        print("[MusicTakeover] Forward status=\(snapshot.status.rawValue) title=\(snapshot.title) artist=\(snapshot.artist)")
        onUpdate?(MusicTakeoverUpdate(intent: .musicSnapshotUpdated(snapshot), commandToSend: nil))
        return true
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
        if next.themePalette != previous.themePalette { return true }
        if next.duration != previous.duration { return true }
        return false
    }

    private func applyCachedPalette(to snapshot: inout MusicTrackSnapshot) {
        guard let artworkData = snapshot.artworkData else {
            snapshot.themePalette = .fallback
            snapshot.themeColorHex = snapshot.themePalette.primaryHex
            return
        }
        let key = paletteKey(for: artworkData)
        guard let palette = paletteCache[key] else { return }
        snapshot.themePalette = palette
        snapshot.themeColorHex = palette.primaryHex
    }

    private func schedulePaletteExtractionIfNeeded(for snapshot: MusicTrackSnapshot) {
        guard let artworkData = snapshot.artworkData else { return }
        let key = paletteKey(for: artworkData)
        guard paletteCache[key] == nil, pendingPaletteKeys.contains(key) == false else { return }
        pendingPaletteKeys.insert(key)

        paletteQueue.async { [weak self] in
            let palette = MusicArtworkPaletteExtractor.extract(from: artworkData)
            DispatchQueue.main.async {
                guard let self, self.isRunning else { return }
                self.pendingPaletteKeys.remove(key)
                self.paletteCache[key] = palette
                guard var current = self.localSnapshot,
                      current.artworkData == artworkData else {
                    return
                }
                current.themePalette = palette
                current.themeColorHex = palette.primaryHex
                current.updatedAt = Date()
                self.localSnapshot = current
                self.forwardSnapshotIfNeeded(current)
            }
        }
    }

    private func paletteKey(for artworkData: Data) -> Int {
        artworkData.hashValue ^ artworkData.count
    }
}

private struct MusicPositionHold {
    let target: TimeInterval
    let trackTitle: String
    let artist: String
    let expiresAt: Date
    let kind: MusicPositionHoldKind

    func matches(_ snapshot: MusicTrackSnapshot) -> Bool {
        snapshot.title == trackTitle && snapshot.artist == artist
    }
}

private enum MusicPositionHoldKind {
    case seek
    case playbackTransition
}
