import CoreGraphics
import Foundation

struct IslandPreviewContentVisibilityInput: Equatable {
    let opacity: Double
    let blurRadius: CGFloat
    let delay: TimeInterval
    let duration: TimeInterval
    let curve: IslandMotionTimingCurve

    static let hidden = IslandPreviewContentVisibilityInput(
        opacity: 0,
        blurRadius: 0,
        delay: 0,
        duration: 0.12,
        curve: .easeOut
    )
}
