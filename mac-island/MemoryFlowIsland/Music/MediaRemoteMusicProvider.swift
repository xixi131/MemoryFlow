import AppKit
import Foundation

final class MediaRemoteMusicProvider: MusicEventProvider {
    let sourceName = "MediaRemote"
    var onSnapshot: ((MusicTrackSnapshot) -> Void)?

    private typealias GetNowPlayingInfoFunction = @convention(c) (
        DispatchQueue,
        @escaping @convention(block) (CFDictionary?) -> Void
    ) -> Void
    private typealias SendCommandFunction = @convention(c) (Int32, CFDictionary?) -> Void
    private typealias SetElapsedTimeFunction = @convention(c) (Double) -> Void
    private typealias RegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
    private typealias GetNowPlayingApplicationPIDFunction = @convention(c) (
        DispatchQueue,
        @escaping @convention(block) (Int32) -> Void
    ) -> Void

    private let callbackQueue = DispatchQueue(label: "com.memoryflow.island.mediaremote")
    private let eventQueue = DispatchQueue(
        label: "com.memoryflow.island.mediaremote-events",
        qos: .userInitiated
    )
    private let stateLock = NSLock()
    private let fallbackProvider: MusicProvider?
    private let getNowPlayingInfo: GetNowPlayingInfoFunction?
    private let sendCommandFunction: SendCommandFunction?
    private let setElapsedTimeFunction: SetElapsedTimeFunction?
    private let registerForNowPlayingNotifications: RegisterForNowPlayingNotificationsFunction?
    private let getNowPlayingApplicationPID: GetNowPlayingApplicationPIDFunction?
    private var notificationObserver: NSObjectProtocol?
    private var distributedNotificationObservers: [NSObjectProtocol] = []
    private var lastSnapshot = MusicTrackSnapshot.stopped
    private var lastPlayingSnapshot: MusicTrackSnapshot?
    private var isStarted = false

    init(fallbackProvider: MusicProvider? = AppleMusicProvider()) {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        )
        if let symbol = handle.flatMap({ dlsym($0, "MRMediaRemoteGetNowPlayingInfo") }) {
            getNowPlayingInfo = unsafeBitCast(symbol, to: GetNowPlayingInfoFunction.self)
        } else {
            getNowPlayingInfo = nil
        }
        if let symbol = handle.flatMap({ dlsym($0, "MRMediaRemoteSendCommand") }) {
            sendCommandFunction = unsafeBitCast(symbol, to: SendCommandFunction.self)
        } else {
            sendCommandFunction = nil
        }
        if let symbol = handle.flatMap({ dlsym($0, "MRMediaRemoteSetElapsedTime") }) {
            setElapsedTimeFunction = unsafeBitCast(symbol, to: SetElapsedTimeFunction.self)
        } else {
            setElapsedTimeFunction = nil
        }
        if let symbol = handle.flatMap({ dlsym($0, "MRMediaRemoteRegisterForNowPlayingNotifications") }) {
            registerForNowPlayingNotifications = unsafeBitCast(
                symbol,
                to: RegisterForNowPlayingNotificationsFunction.self
            )
        } else {
            registerForNowPlayingNotifications = nil
        }
        if let symbol = handle.flatMap({ dlsym($0, "MRMediaRemoteGetNowPlayingApplicationPID") }) {
            getNowPlayingApplicationPID = unsafeBitCast(
                symbol,
                to: GetNowPlayingApplicationPIDFunction.self
            )
        } else {
            getNowPlayingApplicationPID = nil
        }
        self.fallbackProvider = fallbackProvider
    }

    func start() {
        stateLock.lock()
        defer { stateLock.unlock() }
        isStarted = true
        fallbackProvider?.start()
        registerForNowPlayingNotifications?(callbackQueue)
        beginObservingNotifications()
    }

    func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        isStarted = false
        fallbackProvider?.stop()
        endObservingNotifications()
        lastSnapshot = .stopped
        lastPlayingSnapshot = nil
    }

    func currentSnapshot() -> MusicTrackSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isStarted else {
            return .stopped
        }

        if let queriedSnapshot = queryMediaRemoteSnapshot() {
            let fallbackSnapshot = queriedSnapshot.artworkData == nil
                ? fallbackProvider?.currentSnapshot()
                : nil
            let snapshot = MusicArtworkSnapshotMerger.merge(
                primary: queriedSnapshot,
                previous: lastSnapshot,
                fallback: fallbackSnapshot
            )
            lastSnapshot = snapshot
            if snapshot.status == .playing || snapshot.status == .paused {
                lastPlayingSnapshot = snapshot
            }
            return snapshot
        }

        let rawFallbackSnapshot = fallbackProvider?.currentSnapshot() ?? .stopped
        let fallbackSnapshot = MusicArtworkSnapshotMerger.merge(
            primary: rawFallbackSnapshot,
            previous: lastSnapshot
        )
        if fallbackSnapshot.status == .playing || fallbackSnapshot.status == .paused {
            print("[MusicTakeover] MediaRemote empty, fallback accepted source=\(fallbackSnapshot.source) title=\(fallbackSnapshot.title)")
        }
        if fallbackSnapshot.status == .playing || fallbackSnapshot.status == .paused {
            lastSnapshot = fallbackSnapshot
            lastPlayingSnapshot = fallbackSnapshot
            return fallbackSnapshot
        }

        lastSnapshot = fallbackSnapshot
        return fallbackSnapshot
    }

    func sendCommand(_ command: MusicCommand) {
        if let sendCommandFunction {
            sendCommandFunction(mediaRemoteCommand(for: command), nil)
        } else {
            fallbackProvider?.sendCommand(command)
        }
    }

    @discardableResult
    func seek(to position: TimeInterval) -> Bool {
        let safePosition = max(0, position)
        if let setElapsedTimeFunction {
            setElapsedTimeFunction(safePosition)
            return true
        }
        return fallbackProvider?.seek(to: safePosition) ?? false
    }

    private func beginObservingNotifications() {
        endObservingNotifications()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventQueue.async { [weak self] in
                self?.publishCurrentSnapshot()
            }
        }

        let distributedCenter = DistributedNotificationCenter.default()
        for name in [
            "com.apple.Music.playerInfo",
            "com.apple.iTunes.playerInfo"
        ] {
            let observer = distributedCenter.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.eventQueue.async { [weak self] in
                    self?.handleDistributedPlayerInfo(notification)
                }
            }
            distributedNotificationObservers.append(observer)
        }
    }

    private func endObservingNotifications() {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
            self.notificationObserver = nil
        }

        let distributedCenter = DistributedNotificationCenter.default()
        distributedNotificationObservers.forEach { distributedCenter.removeObserver($0) }
        distributedNotificationObservers.removeAll()
    }

    private func publishCurrentSnapshot() {
        let snapshot = currentSnapshot()
        guard snapshot.status == .playing || snapshot.status == .paused || snapshot.status == .stopped else {
            return
        }
        onSnapshot?(snapshot)
    }

    private func handleDistributedPlayerInfo(_ notification: Notification) {
        stateLock.lock()
        guard isStarted,
              let info = notification.userInfo,
              let rawSnapshot = snapshot(fromDistributedPlayerInfo: info) else {
            stateLock.unlock()
            return
        }

        let fallbackSnapshot = rawSnapshot.artworkData == nil
            ? fallbackProvider?.currentSnapshot()
            : nil
        let snapshot = MusicArtworkSnapshotMerger.merge(
            primary: rawSnapshot,
            previous: lastSnapshot,
            fallback: fallbackSnapshot
        )

        lastSnapshot = snapshot
        if snapshot.status == .playing || snapshot.status == .paused {
            lastPlayingSnapshot = snapshot
        }
        stateLock.unlock()
        onSnapshot?(snapshot)
    }

    private func queryMediaRemoteSnapshot() -> MusicTrackSnapshot? {
        guard let getNowPlayingInfo else { return nil }

        var receivedInfo: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)
        getNowPlayingInfo(callbackQueue) { info in
            receivedInfo = info as? [String: Any]
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 0.7) == .success,
              let info = receivedInfo,
              info.isEmpty == false else {
            return nil
        }

        guard let title = firstString(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoTitle",
                "title",
                "Title"
            ]
        ), title.isEmpty == false else {
            return nil
        }

        let artist = firstString(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoArtist",
                "artist",
                "Artist"
            ]
        ) ?? "Unknown Artist"
        let album = firstString(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoAlbum",
                "album",
                "Album"
            ]
        )
        let duration = firstNumber(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoDuration",
                "duration",
                "Duration"
            ]
        )
        let elapsed = firstNumber(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoElapsedTime",
                "elapsedTime",
                "Elapsed Time"
            ]
        ) ?? matchingLastPosition(title: title, artist: artist)
        let playbackRate = firstNumber(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoPlaybackRate",
                "playbackRate",
                "Playback Rate"
            ]
        )
        let status = normalizedStatus(info: info, playbackRate: playbackRate)
        let artworkData = firstData(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoArtworkData",
                "artworkData",
                "Artwork Data"
            ]
        )
        let sourceBundleIdentifier = firstString(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoClientBundleIdentifier",
                "kMRMediaRemoteNowPlayingInfoBundleIdentifier",
                "clientBundleIdentifier",
                "bundleIdentifier"
            ]
        ) ?? currentNowPlayingBundleIdentifier()

        return MusicTrackSnapshot(
            title: title,
            artist: artist,
            album: album,
            status: status,
            isPlaying: status == .playing,
            position: max(0, elapsed),
            duration: duration ?? matchingLastDuration(title: title, artist: artist),
            artworkData: artworkData,
            themeColorHex: "#22d3ee",
            themePalette: .fallback,
            source: sourceName,
            sourceBundleIdentifier: sourceBundleIdentifier,
            updatedAt: Date(),
            capabilities: setElapsedTimeFunction == nil ? .transport : [.transport, .seek]
        )
    }

    private func matchingLastPosition(title: String, artist: String) -> TimeInterval {
        guard lastSnapshot.title == title, lastSnapshot.artist == artist else { return 0 }
        return lastSnapshot.position
    }

    private func matchingLastDuration(title: String, artist: String) -> TimeInterval? {
        guard lastSnapshot.title == title, lastSnapshot.artist == artist else { return nil }
        return lastSnapshot.duration
    }

    private func snapshot(fromDistributedPlayerInfo info: [AnyHashable: Any]) -> MusicTrackSnapshot? {
        guard let title = firstString(
            inAnyHashable: info,
            keys: ["Name", "Title", "kMRMediaRemoteNowPlayingInfoTitle"]
        ), title.isEmpty == false else {
            return nil
        }

        let artist = firstString(
            inAnyHashable: info,
            keys: ["Artist", "artist", "kMRMediaRemoteNowPlayingInfoArtist"]
        ) ?? "Unknown Artist"
        let album = firstString(
            inAnyHashable: info,
            keys: ["Album", "album", "kMRMediaRemoteNowPlayingInfoAlbum"]
        )
        let stateText = firstString(
            inAnyHashable: info,
            keys: ["Player State", "Playback State", "kMRMediaRemoteNowPlayingInfoPlaybackState"]
        )
        let playbackRate = firstNumber(
            inAnyHashable: info,
            keys: ["Playback Rate", "playbackRate", "kMRMediaRemoteNowPlayingInfoPlaybackRate"]
        )
        let status = normalizedDistributedStatus(stateText: stateText, playbackRate: playbackRate)
        let elapsed = firstNumber(
            inAnyHashable: info,
            keys: ["Player Position", "Elapsed Time", "elapsedTime", "kMRMediaRemoteNowPlayingInfoElapsedTime"]
        ) ?? lastSnapshot.position
        let durationSeconds = firstNumber(
            inAnyHashable: info,
            keys: ["Duration", "duration", "kMRMediaRemoteNowPlayingInfoDuration"]
        )
        let totalTimeMilliseconds = firstNumber(
            inAnyHashable: info,
            keys: ["Total Time"]
        )
        let duration = Self.normalizedDistributedDuration(
            durationSeconds: durationSeconds,
            totalTimeMilliseconds: totalTimeMilliseconds
        )

        return MusicTrackSnapshot(
            title: title,
            artist: artist,
            album: album,
            status: status,
            isPlaying: status == .playing,
            position: max(0, elapsed),
            duration: duration,
            artworkData: nil,
            themeColorHex: "#22d3ee",
            themePalette: .fallback,
            source: "Apple Music",
            sourceBundleIdentifier: "com.apple.Music",
            updatedAt: Date(),
            capabilities: [.transport, .seek]
        )
    }

    static func normalizedDistributedDuration(
        durationSeconds: TimeInterval?,
        totalTimeMilliseconds: TimeInterval?
    ) -> TimeInterval? {
        if let durationSeconds, durationSeconds > 0 {
            return durationSeconds
        }
        guard let totalTimeMilliseconds, totalTimeMilliseconds > 0 else {
            return nil
        }
        return totalTimeMilliseconds / 1_000
    }

    private func normalizedStatus(
        info: [String: Any],
        playbackRate: TimeInterval?
    ) -> MusicPlaybackStatus {
        if let playbackRate {
            return playbackRate > 0 ? .playing : .paused
        }

        if let playbackState = firstString(
            in: info,
            keys: [
                "kMRMediaRemoteNowPlayingInfoPlaybackState",
                "playbackState",
                "Playback State"
            ]
        )?.lowercased() {
            if playbackState.contains("playing") {
                return .playing
            }
            if playbackState.contains("paused") {
                return .paused
            }
            if playbackState.contains("stopped") {
                return .stopped
            }
        }

        if let lastPlayingSnapshot,
           lastPlayingSnapshot.title == firstString(in: info, keys: ["kMRMediaRemoteNowPlayingInfoTitle", "title", "Title"]),
           abs(lastPlayingSnapshot.position - (firstNumber(in: info, keys: ["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime", "Elapsed Time"]) ?? 0)) < 0.5 {
            return .paused
        }

        return .playing
    }

    private func currentNowPlayingBundleIdentifier() -> String? {
        guard let getNowPlayingApplicationPID else { return nil }
        var receivedPID: Int32 = 0
        let semaphore = DispatchSemaphore(value: 0)
        getNowPlayingApplicationPID(callbackQueue) { pid in
            receivedPID = pid
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 0.3) == .success,
              receivedPID > 0 else { return nil }
        return NSRunningApplication(
            processIdentifier: pid_t(receivedPID)
        )?.bundleIdentifier
    }

    private func normalizedDistributedStatus(
        stateText: String?,
        playbackRate: TimeInterval?
    ) -> MusicPlaybackStatus {
        if let playbackRate {
            return playbackRate > 0 ? .playing : .paused
        }

        switch stateText?.lowercased() {
        case .some(let value) where value.contains("playing"):
            return .playing
        case .some(let value) where value.contains("paused"):
            return .paused
        case .some(let value) where value.contains("stopped"):
            return .stopped
        default:
            return .playing
        }
    }

    private func mediaRemoteCommand(for command: MusicCommand) -> Int32 {
        switch command {
        case .previous:
            return 5
        case .playPause:
            return 2
        case .next:
            return 4
        }
    }

    private func firstString(in info: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = info[key] as? String {
                return value
            }
            if let value = info[key] as? NSString {
                return value as String
            }
        }
        return nil
    }

    private func firstNumber(in info: [String: Any], keys: [String]) -> TimeInterval? {
        for key in keys {
            if let value = info[key] as? TimeInterval {
                return value
            }
            if let value = info[key] as? NSNumber {
                return value.doubleValue
            }
        }
        return nil
    }

    private func firstData(in info: [String: Any], keys: [String]) -> Data? {
        for key in keys {
            if let value = info[key] as? Data {
                return value
            }
            if let value = info[key] as? NSData {
                return value as Data
            }
        }
        return nil
    }

    private func firstString(inAnyHashable info: [AnyHashable: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = info[key] as? String {
                return value
            }
            if let value = info[key] as? NSString {
                return value as String
            }
        }
        return nil
    }

    private func firstNumber(inAnyHashable info: [AnyHashable: Any], keys: [String]) -> TimeInterval? {
        for key in keys {
            if let value = info[key] as? TimeInterval {
                return value
            }
            if let value = info[key] as? NSNumber {
                return value.doubleValue
            }
        }
        return nil
    }
}
