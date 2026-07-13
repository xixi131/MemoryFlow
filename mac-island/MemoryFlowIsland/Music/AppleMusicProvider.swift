import AppKit
import Foundation

final class AppleMusicProvider: MusicProvider {
    let sourceName = "Apple Music"

    private let scriptRunner: (String) -> String?
    private(set) var isStarted = false

    init(scriptRunner: @escaping (String) -> String? = AppleMusicProvider.runAppleScript) {
        self.scriptRunner = scriptRunner
    }

    func start() {
        isStarted = true
    }

    func stop() {
        isStarted = false
    }

    func currentSnapshot() -> MusicTrackSnapshot {
        guard isStarted else {
            return .stopped
        }

        guard Self.isAppleMusicRunning else {
            print("[MusicTakeover] AppleMusicProvider: com.apple.Music is not running")
            return stoppedSnapshot()
        }

        for target in Self.scriptTargets {
            guard let output = scriptRunner(Self.snapshotScript(for: target.reference)),
                  output.isEmpty == false,
                  output != "__MF_NOT_RUNNING__",
                  output != "__MF_NO_TRACK__" else {
                continue
            }

            let fields = output.components(separatedBy: Self.fieldSeparator)
            guard fields.count >= 7 else {
                continue
            }

            let state = normalizedStatus(fields[0])
            let title = sanitized(fields[1], fallback: "Unknown Track")
            let artist = sanitized(fields[2], fallback: "Unknown Artist")
            let album = sanitizedOptional(fields[3])
            let position = TimeInterval(Double(fields[4]) ?? 0)
            let duration = TimeInterval(Double(fields[5]) ?? 0)
            let artworkData = Data(base64Encoded: fields[6])

            return MusicTrackSnapshot(
                title: title,
                artist: artist,
                album: album,
                status: state,
                isPlaying: state == .playing,
                position: max(0, position),
                duration: duration > 0 ? duration : nil,
                artworkData: artworkData,
                themeColorHex: "#22d3ee",
                source: target.sourceName,
                updatedAt: Date(),
                capabilities: .transport
            )
        }

        print("[MusicTakeover] AppleMusicProvider: Music is running but no AppleScript target returned a track")
        return stoppedSnapshot()
    }

    func sendCommand(_ command: MusicCommand) {
        guard isStarted else { return }

        let verb: String
        switch command {
        case .previous:
            verb = "previous track"
        case .playPause:
            verb = "playpause"
        case .next:
            verb = "next track"
        }

        for target in Self.scriptTargets {
            if scriptRunner(Self.commandScript(for: target.reference, command: verb)) != nil {
                return
            }
        }
    }

    private func stoppedSnapshot() -> MusicTrackSnapshot {
        var snapshot = MusicTrackSnapshot.stopped
        snapshot.source = sourceName
        snapshot.updatedAt = Date()
        return snapshot
    }

    private func normalizedStatus(_ rawStatus: String) -> MusicPlaybackStatus {
        switch rawStatus.lowercased() {
        case "playing":
            return .playing
        case "paused":
            return .paused
        case "stopped":
            return .stopped
        default:
            return .unknown
        }
    }

    private func sanitized(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func sanitizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let fieldSeparator = "|||MF|||"

    private static let scriptTargets: [(reference: String, sourceName: String)] = [
        ("application id \"com.apple.Music\"", "Apple Music"),
        ("application \"Music\"", "Apple Music"),
        ("application \"Apple Music\"", "Apple Music"),
        ("application \"音乐\"", "Apple Music")
    ]

    private static var isAppleMusicRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty == false
    }

    private static func snapshotScript(for targetReference: String) -> String {
        """
        if \(targetReference) is not running then
            return "__MF_NOT_RUNNING__"
        end if
        tell \(targetReference)
            if player state is stopped then
                return "stopped|||MF||||||MF||||||MF|||0|||MF|||0|||MF|||"
            end if
            try
                set trackName to name of current track as text
                set artistName to artist of current track as text
                set albumName to album of current track as text
                set durationValue to duration of current track
            on error
                return "__MF_NO_TRACK__"
            end try
            set stateText to player state as text
            set positionValue to player position
            set artworkText to ""
            try
                if (count of artworks of current track) > 0 then
                    set artworkData to raw data of artwork 1 of current track
                    set tempFile to ((path to temporary items folder as text) & "memoryflow-island-artwork.bin")
                    set fileRef to open for access file tempFile with write permission
                    set eof of fileRef to 0
                    write artworkData to fileRef
                    close access fileRef
                    set artworkText to do shell script "/usr/bin/base64 < " & quoted form of POSIX path of tempFile
                end if
            on error
                try
                    close access file tempFile
                end try
                set artworkText to ""
            end try
            return stateText & "|||MF|||" & trackName & "|||MF|||" & artistName & "|||MF|||" & albumName & "|||MF|||" & (positionValue as text) & "|||MF|||" & (durationValue as text) & "|||MF|||" & artworkText
        end tell
        """
    }

    private static func commandScript(for targetReference: String, command: String) -> String {
        """
        if \(targetReference) is running then
            tell \(targetReference) to \(command)
            return "ok"
        end if
        return ""
        """
    }

    private static func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result.stringValue
    }
}
