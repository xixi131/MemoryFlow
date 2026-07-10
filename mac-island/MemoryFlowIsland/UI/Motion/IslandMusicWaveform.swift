import CoreGraphics
import Foundation
import SwiftUI

/// The visual direction follows the physical horizontal trackpad movement.
enum IslandMusicTrackSwipeDirection: Equatable {
    case next
    case previous

    init(_ command: IslandHorizontalMusicCommand) {
        self = command == .nextTrack ? .next : .previous
    }

    private var outgoingOffset: CGFloat {
        self == .next ? 30 : -30
    }

    var transition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: -outgoingOffset, y: 0)),
            removal: .opacity.combined(with: .offset(x: outgoingOffset, y: 0))
        )
    }
}

extension View {
    /// Changes only track-specific content; the surrounding island shell is not part of this transition.
    func islandMusicTrackSwipe(
        trackID: String,
        direction: IslandMusicTrackSwipeDirection?
    ) -> some View {
        self.id(trackID)
            .transition(direction?.transition ?? .opacity)
            .animation(.easeOut(duration: 0.26), value: trackID)
    }
}

/// The waveform's timing model is independent from the island shell animation.
/// This allows the bar view to redraw locally without retargeting panel geometry.
enum IslandMusicWaveform {
    static let pattern: [CGFloat] = [4, 16, 8, 20, 6, 12, 4]
    static let cycleDuration: TimeInterval = 2.2
    static let phaseOffset: TimeInterval = 0.2
    static let pausedSettleDuration: TimeInterval = 0.3

    static func phase(for barIndex: Int) -> TimeInterval {
        TimeInterval(barIndex) * phaseOffset
    }

    static func height(
        at time: TimeInterval,
        barIndex: Int,
        displayScale: CGFloat,
        isPlaying: Bool
    ) -> CGFloat {
        guard isPlaying else { return pattern[0] * displayScale }

        let adjustedTime = time - phase(for: barIndex)
        let cyclePosition = adjustedTime.truncatingRemainder(dividingBy: cycleDuration)
        let normalized = cyclePosition < 0
            ? (cyclePosition + cycleDuration) / cycleDuration
            : cyclePosition / cycleDuration
        let segmentCount = pattern.count - 1
        let rawSegment = normalized * Double(segmentCount)
        let index = min(Int(rawSegment), segmentCount - 1)
        let progress = CGFloat(rawSegment - Double(index))
        let eased = progress * progress * (3 - (2 * progress))
        let start = pattern[index]
        let end = pattern[index + 1]
        return (start + ((end - start) * eased)) * displayScale
    }
}

/// A local presentation clock for mock music; it never invokes playback providers.
struct IslandMockMusicProgressClock: Equatable {
    private var hasMusic = false
    private var elapsedAtAnchor: TimeInterval = 0
    private var anchorDate: Date = .distantPast
    private var isPlaying = false
    private var duration: TimeInterval?

    mutating func reset(for music: IslandMockMusicActivity?, isPlaying: Bool, at date: Date) {
        guard let music else {
            hasMusic = false
            elapsedAtAnchor = 0
            anchorDate = date
            self.isPlaying = false
            duration = nil
            return
        }
        hasMusic = true
        elapsedAtAnchor = music.elapsedSeconds
        anchorDate = date
        self.isPlaying = isPlaying
        duration = music.durationSeconds
    }

    func elapsed(at date: Date) -> TimeInterval? {
        guard hasMusic else { return nil }
        let advanced = isPlaying ? max(0, date.timeIntervalSince(anchorDate)) : 0
        let value = max(0, elapsedAtAnchor + advanced)
        return duration.map { min(value, max(0, $0)) } ?? value
    }
}
