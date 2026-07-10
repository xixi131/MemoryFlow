import CoreGraphics
import Foundation

enum IslandMusicWaveformProbe {
    static func validate() throws {
        guard IslandMusicWaveform.pattern == [4, 16, 8, 20, 6, 12, 4],
              IslandMusicWaveform.cycleDuration == 2.2,
              IslandMusicWaveform.phaseOffset == 0.2,
              IslandMusicWaveform.pausedSettleDuration == 0.3 else {
            throw IslandMusicWaveformProbeError.invalidTokens
        }

        let activityOffsets = (0..<4).map(IslandMusicWaveform.phase(for:))
        let expandedOffsets = (0..<5).map(IslandMusicWaveform.phase(for:))
        guard matches(activityOffsets, expected: [0, 0.2, 0.4, 0.6]),
              matches(expandedOffsets, expected: [0, 0.2, 0.4, 0.6, 0.8]) else {
            throw IslandMusicWaveformProbeError.invalidPhaseOffsets
        }

        let scale: CGFloat = 1.5
        let cycleStart = IslandMusicWaveform.height(at: 0, barIndex: 0, displayScale: scale, isPlaying: true)
        let firstPeak = IslandMusicWaveform.height(
            at: IslandMusicWaveform.cycleDuration / 6,
            barIndex: 0,
            displayScale: scale,
            isPlaying: true
        )
        let phaseShiftedStart = IslandMusicWaveform.height(
            at: IslandMusicWaveform.phaseOffset,
            barIndex: 1,
            displayScale: scale,
            isPlaying: true
        )
        let paused = IslandMusicWaveform.height(at: 1, barIndex: 3, displayScale: scale, isPlaying: false)
        guard approximatelyEqual(cycleStart, 4 * scale),
              approximatelyEqual(firstPeak, 16 * scale),
              approximatelyEqual(phaseShiftedStart, 4 * scale),
              approximatelyEqual(paused, 4 * scale) else {
            throw IslandMusicWaveformProbeError.invalidSamples
        }
    }

    private static func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }

    private static func matches(_ actual: [TimeInterval], expected: [TimeInterval]) -> Bool {
        actual.count == expected.count && zip(actual, expected).allSatisfy { lhs, rhs in
            abs(lhs - rhs) < 0.001
        }
    }
}

struct IslandMusicArtworkProbeRow: Equatable {
    let scenario: String
    let presentation: IslandMusicArtworkPresentation
    let usesPlaceholder: Bool
}

enum IslandMusicArtworkProbe {
    static func validateTransitions() throws -> [IslandMusicArtworkProbeRow] {
        let activity = IslandVisualTokens.activityMusicArtwork
        let expanded = IslandVisualTokens.expandedMusicArtwork
        let midpoint = IslandMusicArtworkPresentation.interpolated(
            from: activity,
            to: expanded,
            progress: 0.5
        )
        let collapsed = IslandMusicArtworkPresentation.interpolated(
            from: expanded,
            to: activity,
            progress: 1
        )
        let rows = [
            IslandMusicArtworkProbeRow(scenario: "expand", presentation: activity, usesPlaceholder: false),
            IslandMusicArtworkProbeRow(scenario: "expand-midpoint", presentation: midpoint, usesPlaceholder: false),
            IslandMusicArtworkProbeRow(scenario: "track-change", presentation: expanded, usesPlaceholder: false),
            IslandMusicArtworkProbeRow(scenario: "missing-artwork", presentation: expanded, usesPlaceholder: true),
            IslandMusicArtworkProbeRow(scenario: "collapse", presentation: collapsed, usesPlaceholder: true)
        ]

        guard activity == IslandMusicArtworkPresentation(width: 24, height: 27, radius: 6.4, smoothness: 1.92),
              expanded == IslandMusicArtworkPresentation(width: 72, height: 80, radius: 16, smoothness: 1.85),
              midpoint == IslandMusicArtworkPresentation(width: 48, height: 53.5, radius: 11.2, smoothness: 1.885),
              collapsed == activity,
              rows.map(\.scenario) == ["expand", "expand-midpoint", "track-change", "missing-artwork", "collapse"],
              rows.filter(\.usesPlaceholder).count == 2 else {
            throw IslandMusicArtworkProbeError.invalidTransitionPresentation
        }
        return rows
    }
}

enum IslandMusicArtworkProbeError: Error, CustomStringConvertible {
    case invalidTransitionPresentation

    var description: String {
        switch self {
        case .invalidTransitionPresentation:
            return "Music artwork does not preserve its expected expand, collapse, track-change, and placeholder presentations."
        }
    }
}

enum IslandMusicWaveformProbeError: Error {
    case invalidTokens
    case invalidPhaseOffsets
    case invalidSamples
}
