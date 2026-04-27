import Foundation

enum IslandPointerSwipeDirection: String, Codable, Equatable {
    case left
    case right
}

enum IslandTrackpadSwipeDirection: String, Codable, Equatable {
    case up
    case down
}

enum IslandHorizontalMusicCommand: String, Codable, Equatable {
    case previousTrack
    case nextTrack
}

enum IslandInteractionIntent: Codable, Equatable {
    case hoverEnter
    case hoverLeave
    case tap
    case outsideCollapse
    case pointerSwipe(IslandPointerSwipeDirection)
    case trackpadSwipe(IslandTrackpadSwipeDirection)
    case horizontalMusicCommand(IslandHorizontalMusicCommand)
    case mockScenarioSelect(String)
    case transitionComplete(String?)
}

enum IslandInteractionThresholds {
    static let tapMovementWindow: Double = 10
    static let pointerSwipeThreshold: Double = 26
    static let trackpadHorizontalThreshold: Double = 70
    static let trackpadVerticalThreshold: Double = 70
    static let trackpadGestureResetWindow: TimeInterval = 0.160
    static let trackpadGestureCooldownWindow: TimeInterval = 0.320
    static let modeSwitchLongPressWindow: TimeInterval = 0.420
    static let modeSwitchCompactPhaseWindow: TimeInterval = 0.320
    static let modeSwitchReopenDelay: TimeInterval = 0.070

    static func pointerSwipeDirection(for deltaX: Double) -> IslandPointerSwipeDirection? {
        if deltaX > pointerSwipeThreshold {
            return .right
        }
        if deltaX < -pointerSwipeThreshold {
            return .left
        }
        return nil
    }

    static func isTapMovement(deltaX: Double) -> Bool {
        abs(deltaX) < tapMovementWindow
    }

    static func dominantTrackpadIntent(
        deltaX: Double,
        deltaY: Double
    ) -> IslandInteractionIntent? {
        let absX = abs(deltaX)
        let absY = abs(deltaY)

        if absX >= absY, absX >= trackpadHorizontalThreshold {
            return .horizontalMusicCommand(deltaX > 0 ? .nextTrack : .previousTrack)
        }

        if absY > absX, absY >= trackpadVerticalThreshold {
            return .trackpadSwipe(deltaY > 0 ? .up : .down)
        }

        return nil
    }
}
