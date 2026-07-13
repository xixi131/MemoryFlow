import Foundation

enum IslandTransitionKind: String, CaseIterable, Equatable {
    case hoverEnter
    case hoverLeave
    case compactToActivity
    case compactToExpanded
    case activityToCompact
    case activityToExpanded
    case expandedToActivity
    case expandedToCompact
    case modeSwitch
    case reminderOpen
    case reminderRecover
    case musicTakeover
    case musicContentRetarget
    case defaultProfile

    static func resolve(
        previous: IslandDerivedState,
        next: IslandDerivedState,
        reason: IslandPresentationTransitionReason
    ) -> IslandTransitionKind {
        switch reason {
        case .hoverEntered: return .hoverEnter
        case .hoverLeft: return .hoverLeave
        case .modeSwitchedToReview, .modeSwitchedToTodo, .activitySwitchedToReview, .activitySwitchedToTodo, .activitySwitchedToMusic:
            return .modeSwitch
        case .reminderDueOpenedReviewActivity: return .reminderOpen
        case .reminderDueMarkedActive, .pointerSwipedToCompact, .outsideCollapsedToCompact, .outsideCollapsedToActivity:
            return previous.showReminder ? .reminderRecover : resolveVisualStates(previous.visualState, next.visualState)
        case .musicTakeoverStarted, .musicSnapshotAccepted, .musicStoppedToApp, .pausedMusicTimedOutToApp:
            return .musicTakeover
        case .musicSnapshotRetargeted:
            return .musicContentRetarget
        default:
            return resolveVisualStates(previous.visualState, next.visualState)
        }
    }

    private static func resolveVisualStates(_ previous: IslandVisualState, _ next: IslandVisualState) -> IslandTransitionKind {
        switch (previous, next) {
        case (.compactCollapsed, .hoverCollapsed): return .hoverEnter
        case (.hoverCollapsed, .compactCollapsed): return .hoverLeave
        case (.activityCollapsed, .activityHoverCollapsed): return .hoverEnter
        case (.activityHoverCollapsed, .activityCollapsed): return .hoverLeave
        case (.compactCollapsed, .activityCollapsed), (.hoverCollapsed, .activityCollapsed): return .compactToActivity
        case (.compactCollapsed, .expandedMusic), (.compactCollapsed, .expandedApp),
             (.compactCollapsed, .loginRequired),
             (.hoverCollapsed, .expandedMusic), (.hoverCollapsed, .expandedApp),
             (.hoverCollapsed, .loginRequired): return .compactToExpanded
        case (.activityCollapsed, .compactCollapsed), (.activityCollapsed, .hoverCollapsed),
             (.activityHoverCollapsed, .compactCollapsed), (.activityHoverCollapsed, .hoverCollapsed): return .activityToCompact
        case (.activityCollapsed, .expandedMusic), (.activityCollapsed, .expandedApp),
             (.activityHoverCollapsed, .expandedMusic), (.activityHoverCollapsed, .expandedApp): return .activityToExpanded
        case (.expandedMusic, .activityCollapsed), (.expandedApp, .activityCollapsed),
             (.expandedMusic, .activityHoverCollapsed), (.expandedApp, .activityHoverCollapsed): return .expandedToActivity
        case (.expandedMusic, .compactCollapsed), (.expandedMusic, .hoverCollapsed), (.expandedApp, .compactCollapsed), (.expandedApp, .hoverCollapsed),
             (.loginRequired, .compactCollapsed), (.loginRequired, .hoverCollapsed): return .expandedToCompact
        default: return .defaultProfile
        }
    }

    var motionTokens: IslandMotionTokenSet { IslandMotionTokens.profile(for: self) }
    var isDefaultFallback: Bool { self == .defaultProfile }
}
