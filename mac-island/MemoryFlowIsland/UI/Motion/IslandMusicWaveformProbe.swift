import CoreGraphics
import Foundation

enum IslandMusicWaveformProbe {
    static func validate() throws {
        try validateMockMusicControls()
        try validateLiveBarMapping()
        guard IslandMusicWaveform.pattern == [4, 16, 8, 20, 6, 12, 4],
              IslandMusicWaveform.cycleDuration == 2.2,
              IslandMusicWaveform.phaseOffset == 0.2,
              IslandMusicWaveform.pausedSettleDuration == 0.3,
              IslandMusicWaveform.minimumFrameInterval == 1.0 / 60.0 else {
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

    private static func validateLiveBarMapping() throws {
        let activity = (0..<4).map {
            IslandMusicWaveform.liveLevel(0.25, barIndex: $0, barCount: 4)
        }
        let expanded = (0..<5).map {
            IslandMusicWaveform.liveLevel(0.25, barIndex: $0, barCount: 5)
        }
        guard Set(activity).count == 1,
              Set(expanded).count == 1,
              IslandMusicWaveform.liveLevel(0.02, barIndex: 0, barCount: 4) == 0,
              IslandMusicWaveform.liveLevel(0.8, barIndex: 0, barCount: 4) > activity[0] else {
            throw IslandMusicWaveformProbeError.invalidLiveBarMapping
        }
    }

    static func validateMockMusicControls() throws {
        let music = IslandMockMusicActivity.scenarioPlaying
        let anchor = Date(timeIntervalSinceReferenceDate: 100)
        var clock = IslandMockMusicProgressClock()
        clock.reset(for: music, isPlaying: true, at: anchor)
        guard clock.elapsed(at: anchor.addingTimeInterval(2.5)) == music.elapsedSeconds + 2.5 else {
            throw IslandMusicWaveformProbeError.invalidMockProgressClock
        }

        clock.reset(for: music, isPlaying: false, at: anchor)
        guard clock.elapsed(at: anchor.addingTimeInterval(8)) == music.elapsedSeconds else {
            throw IslandMusicWaveformProbeError.pausedClockAdvanced
        }

        clock.reset(for: music, isPlaying: true, at: anchor)
        let pauseDate = anchor.addingTimeInterval(5)
        clock.setPlaying(false, at: pauseDate)
        guard clock.elapsed(at: pauseDate.addingTimeInterval(8)) == music.elapsedSeconds + 5 else {
            throw IslandMusicWaveformProbeError.playbackToggleChangedElapsedTime
        }
        let resumeDate = pauseDate.addingTimeInterval(8)
        clock.setPlaying(true, at: resumeDate)
        guard clock.elapsed(at: resumeDate.addingTimeInterval(3)) == music.elapsedSeconds + 8 else {
            throw IslandMusicWaveformProbeError.playbackToggleChangedElapsedTime
        }

        var seeked = music
        seeked.elapsedSeconds = seeked.durationSeconds! - 1
        clock.reset(for: seeked, isPlaying: true, at: anchor)
        guard clock.elapsed(at: anchor.addingTimeInterval(4)) == seeked.durationSeconds,
              seeked.remainingSeconds == 1 else {
            throw IslandMusicWaveformProbeError.invalidSeekClamp
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

        guard activity == IslandMusicArtworkPresentation(width: 20, height: 20, radius: 6.4, smoothness: 1.92),
              expanded == IslandMusicArtworkPresentation(width: 61.2, height: 68, radius: 13.6, smoothness: 1.85),
              midpoint == IslandMusicArtworkPresentation(width: 40.6, height: 44, radius: 10, smoothness: 1.885),
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
    case invalidMockProgressClock
    case pausedClockAdvanced
    case playbackToggleChangedElapsedTime
    case invalidSeekClamp
    case invalidLiveBarMapping
}
