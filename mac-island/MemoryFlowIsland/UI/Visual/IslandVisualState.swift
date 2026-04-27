import Foundation

enum IslandVisualState: String, CaseIterable, Identifiable {
    case compactCollapsed
    case hoverCollapsed
    case activityCollapsed
    case expandedMusic
    case expandedApp

    var id: String {
        rawValue
    }

    var isExpanded: Bool {
        switch self {
        case .expandedMusic, .expandedApp:
            return true
        case .compactCollapsed, .hoverCollapsed, .activityCollapsed:
            return false
        }
    }

    var allowsShadow: Bool {
        switch self {
        case .hoverCollapsed:
            return IslandVisualTokens.shadow.visibleInHoverCollapsed
        case .expandedMusic, .expandedApp:
            return IslandVisualTokens.shadow.visibleInExpanded
        case .compactCollapsed, .activityCollapsed:
            return false
        }
    }

    var tokenSet: IslandVisualTokenSet {
        switch self {
        case .compactCollapsed, .hoverCollapsed:
            return .compact
        case .activityCollapsed:
            return .activity
        case .expandedMusic:
            return .expandedMusic
        case .expandedApp:
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
        case .expandedMusic:
            return "Expanded Music"
        case .expandedApp:
            return "Expanded App"
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
        case .activityCollapsed:
            // Preview-only stand-in for later measured activity content:
            // symmetric left cover + right waveform/action area + shell padding.
            return IslandContentWidthRequirement(
                leadingContentWidth: 36,
                trailingContentWidth: 36,
                horizontalPadding: 18
            )
        case .compactCollapsed, .hoverCollapsed, .expandedMusic, .expandedApp:
            return .none
        }
    }
}
