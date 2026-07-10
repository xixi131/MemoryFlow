import Foundation

enum MusicPlaybackStatus: String, Codable, Equatable {
    case playing
    case paused
    case stopped
    case unknown

    var isPlaying: Bool {
        self == .playing
    }
}

enum MusicCommand: String, Codable, Equatable {
    case previous
    case playPause
    case next
}

struct MusicProviderCapabilities: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let previous = MusicProviderCapabilities(rawValue: 1 << 0)
    static let playPause = MusicProviderCapabilities(rawValue: 1 << 1)
    static let next = MusicProviderCapabilities(rawValue: 1 << 2)

    static let transport: MusicProviderCapabilities = [.previous, .playPause, .next]
}

struct MusicTrackSnapshot: Codable, Equatable {
    var title: String
    var artist: String
    var album: String?
    var status: MusicPlaybackStatus
    var isPlaying: Bool
    var position: TimeInterval
    var duration: TimeInterval?
    var artworkData: Data?
    var themeColorHex: String
    var source: String
    var updatedAt: Date
    var capabilities: MusicProviderCapabilities

    static let stopped = MusicTrackSnapshot(
        title: "",
        artist: "",
        album: nil,
        status: .stopped,
        isPlaying: false,
        position: 0,
        duration: 0,
        artworkData: nil,
        themeColorHex: "#22d3ee",
        source: "none",
        updatedAt: Date(),
        capabilities: []
    )

    static let mockPlaybackStart = MusicTrackSnapshot(
        title: "Night Study",
        artist: "MemoryFlow",
        album: "Focus Session",
        status: .playing,
        isPlaying: true,
        position: 12,
        duration: 240,
        artworkData: nil,
        themeColorHex: "#22d3ee",
        source: "Mock",
        updatedAt: Date(timeIntervalSince1970: 0),
        capabilities: .transport
    )
}

protocol MusicProvider: AnyObject {
    var sourceName: String { get }
    func start()
    func stop()
    func currentSnapshot() -> MusicTrackSnapshot
    func sendCommand(_ command: MusicCommand)
}

protocol MusicEventProvider: MusicProvider {
    var onSnapshot: ((MusicTrackSnapshot) -> Void)? { get set }
}

extension MusicCommand {
    var horizontalCommand: IslandHorizontalMusicCommand {
        switch self {
        case .previous:
            return .previousTrack
        case .playPause:
            return .playPause
        case .next:
            return .nextTrack
        }
    }
}

extension IslandHorizontalMusicCommand {
    var musicCommand: MusicCommand {
        switch self {
        case .previousTrack:
            return .previous
        case .playPause:
            return .playPause
        case .nextTrack:
            return .next
        }
    }
}
