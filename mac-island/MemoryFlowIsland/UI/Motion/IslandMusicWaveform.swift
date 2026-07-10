import CoreGraphics
import Foundation

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
