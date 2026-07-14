import AppKit
import Foundation

final class AppleMusicProvider: MusicProvider {
    let sourceName = "Apple Music"

    private let scriptRunner: (String) -> String?
    private let artworkResolver: AppleMusicArtworkResolver
    private(set) var isStarted = false

    init(
        scriptRunner: @escaping (String) -> String? = AppleMusicProvider.runAppleScript,
        artworkResolver: AppleMusicArtworkResolver = AppleMusicArtworkResolver()
    ) {
        self.scriptRunner = scriptRunner
        self.artworkResolver = artworkResolver
    }

    func start() {
        isStarted = true
    }

    func stop() {
        isStarted = false
        artworkResolver.cancelPendingRequests()
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
            let artworkData = Self.decodeArtworkBase64(fields[6]) ?? artworkResolver.artwork(
                title: title,
                artist: artist,
                album: album
            )

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
                themePalette: .fallback,
                source: target.sourceName,
                sourceBundleIdentifier: "com.apple.Music",
                updatedAt: Date(),
                capabilities: [.transport, .seek]
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

    @discardableResult
    func seek(to position: TimeInterval) -> Bool {
        guard isStarted else { return false }
        let safePosition = max(0, position)
        let positionText = String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            safePosition
        )

        for target in Self.scriptTargets {
            if scriptRunner(Self.seekScript(for: target.reference, position: positionText)) == "ok" {
                return true
            }
        }
        return false
    }

    private func stoppedSnapshot() -> MusicTrackSnapshot {
        var snapshot = MusicTrackSnapshot.stopped
        snapshot.source = sourceName
        snapshot.sourceBundleIdentifier = "com.apple.Music"
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

    static func decodeArtworkBase64(_ encodedArtwork: String) -> Data? {
        guard let artwork = Data(
            base64Encoded: encodedArtwork,
            options: .ignoreUnknownCharacters
        ), artwork.isEmpty == false else {
            return nil
        }
        return artwork
    }

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

    private static func seekScript(for targetReference: String, position: String) -> String {
        """
        if \(targetReference) is running then
            tell \(targetReference)
                set player position to \(position)
            end tell
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

final class AppleMusicArtworkResolver {
    private struct SearchResponse: Decodable {
        let results: [SearchResult]
    }

    private struct SearchResult: Decodable {
        let trackName: String?
        let artistName: String?
        let collectionName: String?
        let artworkUrl100: URL?
    }

    private let session: URLSession
    private let countryCode: String
    private let lock = NSLock()
    private var cachedArtwork: [String: Data] = [:]
    private var pendingKeys: Set<String> = []
    private var retryAfter: [String: Date] = [:]
    private var tasks: [String: URLSessionDataTask] = [:]

    init(
        session: URLSession = .shared,
        countryCode: String = Locale.current.region?.identifier.lowercased() ?? "us"
    ) {
        self.session = session
        self.countryCode = countryCode
    }

    func artwork(title: String, artist: String, album: String?) -> Data? {
        let key = Self.cacheKey(title: title, artist: artist, album: album)
        lock.lock()
        if let artwork = cachedArtwork[key] {
            lock.unlock()
            return artwork
        }
        if pendingKeys.contains(key) || (retryAfter[key] ?? .distantPast) > Date() {
            lock.unlock()
            return nil
        }
        pendingKeys.insert(key)
        lock.unlock()

        startLookup(key: key, title: title, artist: artist, album: album)
        return nil
    }

    func cancelPendingRequests() {
        lock.lock()
        let activeTasks = Array(tasks.values)
        tasks.removeAll()
        pendingKeys.removeAll()
        lock.unlock()
        activeTasks.forEach { $0.cancel() }
    }

    private func startLookup(key: String, title: String, artist: String, album: String?) {
        guard let searchURL = Self.searchURL(
            title: title,
            artist: artist,
            countryCode: countryCode
        ) else {
            complete(key: key, artwork: nil)
            return
        }

        let task = session.dataTask(with: searchURL) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
                  let artworkURL = Self.bestArtworkURL(
                    in: response.results,
                    title: title,
                    artist: artist,
                    album: album
                  ) else {
                self?.complete(key: key, artwork: nil)
                return
            }
            self.downloadArtwork(key: key, from: artworkURL)
        }
        lock.lock()
        tasks[key] = task
        lock.unlock()
        task.resume()
    }

    private func downloadArtwork(key: String, from url: URL) {
        let artworkURL = Self.resizedArtworkURL(url)
        let task = session.dataTask(with: artworkURL) { [weak self] data, _, _ in
            let validArtwork = data.flatMap { NSImage(data: $0) == nil ? nil : $0 }
            self?.complete(key: key, artwork: validArtwork)
        }
        lock.lock()
        tasks[key] = task
        lock.unlock()
        task.resume()
    }

    private func complete(key: String, artwork: Data?) {
        lock.lock()
        tasks.removeValue(forKey: key)
        pendingKeys.remove(key)
        if let artwork {
            cachedArtwork[key] = artwork
            retryAfter.removeValue(forKey: key)
        } else {
            retryAfter[key] = Date().addingTimeInterval(30)
        }
        lock.unlock()
    }

    private static func searchURL(
        title: String,
        artist: String,
        countryCode: String
    ) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(title)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "country", value: countryCode)
        ]
        return components?.url
    }

    private static func bestArtworkURL(
        in results: [SearchResult],
        title: String,
        artist: String,
        album: String?
    ) -> URL? {
        let matching = results.filter {
            normalized($0.trackName) == normalized(title) &&
                normalized($0.artistName) == normalized(artist)
        }
        let albumMatch = matching.first {
            guard let album else { return false }
            return normalized($0.collectionName) == normalized(album)
        }
        return (albumMatch ?? matching.first)?.artworkUrl100
    }

    private static func resizedArtworkURL(_ url: URL) -> URL {
        URL(string: url.absoluteString.replacingOccurrences(
            of: "/100x100bb.",
            with: "/600x600bb."
        )) ?? url
    }

    private static func cacheKey(title: String, artist: String, album: String?) -> String {
        [normalized(title), normalized(artist), normalized(album)].joined(separator: "|")
    }

    private static func normalized(_ value: String?) -> String {
        guard let value else { return "" }
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}
