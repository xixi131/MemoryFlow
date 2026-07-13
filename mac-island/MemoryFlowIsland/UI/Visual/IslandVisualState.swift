import Foundation

enum IslandVisualState: String, CaseIterable, Identifiable {
    case compactCollapsed
    case hoverCollapsed
    case activityCollapsed
    case activityHoverCollapsed
    case expandedMusic
    case expandedApp
    case loginRequired

    var id: String {
        rawValue
    }

    var isExpanded: Bool {
        switch self {
        case .expandedMusic, .expandedApp, .loginRequired:
            return true
        case .compactCollapsed, .hoverCollapsed, .activityCollapsed, .activityHoverCollapsed:
            return false
        }
    }

    var allowsShadow: Bool {
        switch self {
        case .hoverCollapsed, .activityHoverCollapsed:
            return IslandVisualTokens.shadow.visibleInHoverCollapsed
        case .expandedMusic, .expandedApp:
            return IslandVisualTokens.shadow.visibleInExpanded
        case .compactCollapsed, .activityCollapsed, .loginRequired:
            return false
        }
    }

    var tokenSet: IslandVisualTokenSet {
        switch self {
        case .compactCollapsed, .hoverCollapsed:
            return .compact
        case .activityCollapsed, .activityHoverCollapsed:
            return .activity
        case .expandedMusic:
            return .expandedMusic
        case .expandedApp, .loginRequired:
            return .expandedApp
        }
    }

    var displayName: String {
        switch self {
        case .compactCollapsed:
            return "Compact Collapsed"
        case .hoverCollapsed:
            return "Hover Compact"
        case .activityCollapsed:
            return "Activity Compact"
        case .activityHoverCollapsed:
            return "Hover Activity Compact"
        case .expandedMusic:
            return "Expanded Music"
        case .expandedApp:
            return "Expanded App"
        case .loginRequired:
            return "Login Required"
        }
    }

    var nextPreviewState: IslandVisualState {
        let orderedStates = Self.allCases
        guard let currentIndex = orderedStates.firstIndex(of: self) else {
            return .compactCollapsed
        }

        let nextIndex = orderedStates.index(after: currentIndex)
        return nextIndex == orderedStates.endIndex
            ? orderedStates[orderedStates.startIndex]
            : orderedStates[nextIndex]
    }

    var previewContentWidthRequirement: IslandContentWidthRequirement {
        switch self {
        case .activityCollapsed, .activityHoverCollapsed:
            // Preview-only stand-in for later measured activity content:
            // symmetric left cover + right waveform/action area + shell padding.
            return IslandContentWidthRequirement(
                leadingContentWidth: 36,
                trailingContentWidth: 36,
                horizontalPadding: 18
            )
        case .compactCollapsed, .hoverCollapsed, .expandedMusic, .expandedApp, .loginRequired:
            return .none
        }
    }
}
