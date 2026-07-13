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
    case playPause
    case nextTrack
}

enum IslandTodoToggleScenarioOutcome: Equatable {
    case success
    case rollback
}

struct IslandTodoToggleScenarioRequest: Equatable {
    let sequence: Int
    let outcome: IslandTodoToggleScenarioOutcome
}

struct IslandPresentationRetargetTarget: Codable, Equatable {
    let presentationState: IslandPresentationState
    let forceCompactMode: Bool
    let isHovered: Bool
    let locksTrackpadGesture: Bool

    init(
        presentationState: IslandPresentationState,
        forceCompactMode: Bool,
        isHovered: Bool,
        locksTrackpadGesture: Bool = false
    ) {
        self.presentationState = presentationState
        self.forceCompactMode = forceCompactMode
        self.isHovered = isHovered
        self.locksTrackpadGesture = locksTrackpadGesture
    }
}

enum IslandInteractionIntent: Codable, Equatable {
    case hoverEnter
    case hoverLeave
    case tap
    case loginRequiredRequested
    case loginRequiredDismissed
    case updatePromptAvailable(IslandUpdatePrompt)
    case updatePromptUpdateRequested
    case updatePromptLaterRequested
    case outsideCollapse
    case pointerSwipe(IslandPointerSwipeDirection)
    case trackpadSwipe(IslandTrackpadSwipeDirection)
    case horizontalMusicCommand(IslandHorizontalMusicCommand)
    /// Starts the deterministic Phase 6 mock music takeover without contacting a media provider.
    case mockPlaybackStarted(MusicTrackSnapshot)
    case musicSnapshotUpdated(MusicTrackSnapshot)
    case musicStopped
    case musicCommandRequested(IslandHorizontalMusicCommand)
    case modeSwitchToggle
    /// Changes the app content source while the mode-switch shell is held compact.
    case modeSwitchMutate
    /// A deterministic day-scoped identifier prevents the same due event from replaying.
    case reminderDue(String)
    case pausedMusicTimeout
    case greetingLifecycleCompleted
    case greetingFastForward
    case mockScenarioSelect(String)
    case retargetPresentation(IslandPresentationRetargetTarget)
    case transitionComplete(String?)
}

enum IslandPhase5InteractionDemoControl: String, CaseIterable, Identifiable {
    case hoverEnter
    case hoverLeave
    case tap
    case pointerSwipeLeft
    case pointerSwipeRight
    case trackpadUp
    case trackpadDown
    case horizontalPrevious
    case horizontalNext
    case musicPlaybackStart
    case musicStopped
    case modeSwitchToggle
    case reminderDue
    case pausedMusicTimeout
    case greetingFastForward
    case todoToggleSimulateSuccess
    case todoToggleSimulateRollback

    var id: String {
        rawValue
    }

    var menuTitle: String {
        switch self {
        case .hoverEnter:
            return "Hover Enter"
        case .hoverLeave:
            return "Hover Leave"
        case .tap:
            return "Tap"
        case .pointerSwipeLeft:
            return "Pointer Swipe Left"
        case .pointerSwipeRight:
            return "Pointer Swipe Right"
        case .trackpadUp:
            return "Trackpad Up"
        case .trackpadDown:
            return "Trackpad Down"
        case .horizontalPrevious:
            return "Horizontal Previous"
        case .horizontalNext:
            return "Horizontal Next"
        case .musicPlaybackStart:
            return "Music Playback Start"
        case .musicStopped:
            return "Music Stopped"
        case .modeSwitchToggle:
            return "Mode Switch Toggle"
        case .reminderDue:
            return "Reminder Due"
        case .pausedMusicTimeout:
            return "Paused 30s Fast Forward"
        case .greetingFastForward:
            return "Greeting Fast Forward"
        case .todoToggleSimulateSuccess:
            return "Todo Toggle: Simulate Success"
        case .todoToggleSimulateRollback:
            return "Todo Toggle: Simulate Rollback"
        }
    }

    var intent: IslandInteractionIntent {
        switch self {
        case .hoverEnter:
            return .hoverEnter
        case .hoverLeave:
            return .hoverLeave
        case .tap:
            return .tap
        case .pointerSwipeLeft:
            return .pointerSwipe(.left)
        case .pointerSwipeRight:
            return .pointerSwipe(.right)
        case .trackpadUp:
            return .trackpadSwipe(.up)
        case .trackpadDown:
            return .trackpadSwipe(.down)
        case .horizontalPrevious:
            return .horizontalMusicCommand(.previousTrack)
        case .horizontalNext:
            return .horizontalMusicCommand(.nextTrack)
        case .musicPlaybackStart:
            return .mockPlaybackStarted(.mockPlaybackStart)
        case .musicStopped:
            return .musicStopped
        case .modeSwitchToggle:
            return .modeSwitchToggle
        case .reminderDue:
            return .reminderDue("preview-reminder-due")
        case .pausedMusicTimeout:
            return .pausedMusicTimeout
        case .greetingFastForward:
            return .greetingFastForward
        case .todoToggleSimulateSuccess, .todoToggleSimulateRollback:
            // These controls are handled by the native preview view. They are not reducer intents.
            return .tap
        }
    }
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
