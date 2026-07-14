import AppKit
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
    static let seek = MusicProviderCapabilities(rawValue: 1 << 3)

    static let transport: MusicProviderCapabilities = [.previous, .playPause, .next]
}

struct MusicThemePalette: Codable, Equatable {
    static let fallbackHex = "#22d3ee"
    static let fallback = MusicThemePalette(colorsHex: [fallbackHex])

    let colorsHex: [String]

    init(colorsHex: [String]) {
        let normalized = colorsHex
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        self.colorsHex = Array(normalized.prefix(3)).isEmpty
            ? [Self.fallbackHex]
            : Array(normalized.prefix(3))
    }

    var primaryHex: String {
        colorsHex.first ?? Self.fallbackHex
    }
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
    var themePalette: MusicThemePalette
    var source: String
    var sourceBundleIdentifier: String? = nil
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
        themePalette: .fallback,
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
        themePalette: .fallback,
        source: "Mock",
        updatedAt: Date(timeIntervalSince1970: 0),
        capabilities: .transport
    )
}

enum MusicArtworkSnapshotMerger {
    static func merge(
        primary: MusicTrackSnapshot,
        previous: MusicTrackSnapshot?,
        fallback: MusicTrackSnapshot? = nil
    ) -> MusicTrackSnapshot {
        guard primary.artworkData == nil else { return primary }
        var merged = primary

        if let previous,
           isSameTrack(primary, previous),
           let artworkData = previous.artworkData {
            merged.artworkData = artworkData
            return merged
        }

        if let fallback,
           isSameTrack(primary, fallback),
           let artworkData = fallback.artworkData {
            merged.artworkData = artworkData
            if merged.sourceBundleIdentifier == nil {
                merged.sourceBundleIdentifier = fallback.sourceBundleIdentifier
            }
        }
        return merged
    }

    private static func isSameTrack(
        _ lhs: MusicTrackSnapshot,
        _ rhs: MusicTrackSnapshot
    ) -> Bool {
        normalized(lhs.title) == normalized(rhs.title) &&
            normalized(lhs.artist) == normalized(rhs.artist)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

protocol MusicProvider: AnyObject {
    var sourceName: String { get }
    func start()
    func stop()
    func currentSnapshot() -> MusicTrackSnapshot
    func sendCommand(_ command: MusicCommand)
    @discardableResult
    func seek(to position: TimeInterval) -> Bool
}

extension MusicProvider {
    @discardableResult
    func seek(to position: TimeInterval) -> Bool {
        false
    }
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

enum MusicArtworkPaletteExtractor {
    static func extract(from artworkData: Data) -> MusicThemePalette {
        guard let image = NSImage(data: artworkData),
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let pixels = resizedPixels(from: source, width: 24, height: 24) else {
            return .fallback
        }

        var buckets: [Int: (count: Int, red: Int, green: Int, blue: Int)] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let alpha = Int(pixels[offset + 3])
            guard alpha > 40 else { continue }

            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum - minimum
            let brightness = (red + green + blue) / 3
            guard brightness > 28, brightness < 238, saturation > 18 else { continue }

            let key = ((red / 32) << 10) | ((green / 32) << 5) | (blue / 32)
            let current = buckets[key] ?? (0, 0, 0, 0)
            buckets[key] = (
                current.count + 1,
                current.red + red,
                current.green + green,
                current.blue + blue
            )
        }

        let candidates = buckets.values
            .sorted { lhs, rhs in
                let lhsScore = lhs.count * colorRange(red: lhs.red / lhs.count, green: lhs.green / lhs.count, blue: lhs.blue / lhs.count)
                let rhsScore = rhs.count * colorRange(red: rhs.red / rhs.count, green: rhs.green / rhs.count, blue: rhs.blue / rhs.count)
                return lhsScore > rhsScore
            }
            .compactMap { bucket -> (Int, Int, Int)? in
                guard bucket.count > 0 else { return nil }
                return (
                    bucket.red / bucket.count,
                    bucket.green / bucket.count,
                    bucket.blue / bucket.count
                )
            }

        var selected: [(Int, Int, Int)] = []
        for candidate in candidates {
            guard selected.allSatisfy({ colorDistance($0, candidate) > 70 }) else { continue }
            selected.append(candidate)
            if selected.count == 3 { break }
        }

        guard selected.isEmpty == false else { return .fallback }
        return MusicThemePalette(colorsHex: selected.map(hexString))
    }

    private static func resizedPixels(
        from image: CGImage,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func colorRange(red: Int, green: Int, blue: Int) -> Int {
        max(red, green, blue) - min(red, green, blue)
    }

    private static func colorDistance(
        _ lhs: (Int, Int, Int),
        _ rhs: (Int, Int, Int)
    ) -> Double {
        let red = Double(lhs.0 - rhs.0)
        let green = Double(lhs.1 - rhs.1)
        let blue = Double(lhs.2 - rhs.2)
        return (red * red + green * green + blue * blue).squareRoot()
    }

    private static func hexString(_ color: (Int, Int, Int)) -> String {
        String(format: "#%02x%02x%02x", color.0, color.1, color.2)
    }
}
