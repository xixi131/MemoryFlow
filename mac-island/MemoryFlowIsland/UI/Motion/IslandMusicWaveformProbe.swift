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

enum IslandMusicWaveformProbeError: Error {
    case invalidTokens
    case invalidPhaseOffsets
    case invalidSamples
}
