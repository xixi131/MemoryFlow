import Foundation

enum IslandTransitionKind: String, Equatable {
    case compactToActivity
    case activityToCompact
    case activityToExpanded
    case expandedToActivity
    case expandedToCompact
    case hoverEnter
    case hoverLeave
    case defaultProfile

    static func resolve(previous: IslandVisualState, next: IslandVisualState) -> IslandTransitionKind {
        guard previous != next else {
            return .defaultProfile
        }

        switch (previous, next) {
        case (.compactCollapsed, .activityCollapsed):
            return .compactToActivity
        case (.activityCollapsed, .compactCollapsed):
            return .activityToCompact
        case (.activityCollapsed, .expandedMusic), (.activityCollapsed, .expandedApp):
            return .activityToExpanded
        case (.expandedMusic, .activityCollapsed), (.expandedApp, .activityCollapsed):
            return .expandedToActivity
        case (.expandedMusic, .compactCollapsed),
             (.expandedMusic, .hoverCollapsed),
             (.expandedApp, .compactCollapsed),
             (.expandedApp, .hoverCollapsed):
            return .expandedToCompact
        case (.compactCollapsed, .hoverCollapsed):
            return .hoverEnter
        case (.hoverCollapsed, .compactCollapsed):
            return .hoverLeave
        default:
            return .defaultProfile
        }
    }

    var isDefaultFallback: Bool {
        self == .defaultProfile
    }

    var motionTokens: IslandMotionTokenSet {
        IslandMotionTokens.profile(for: self)
    }
}
