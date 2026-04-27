import CoreGraphics
import Foundation

struct IslandDerivedState: Equatable {
    let hasMusicActivitySource: Bool
    let hasAppActivitySource: Bool
    let hasAnyActivitySource: Bool
    let showMusicActivity: Bool
    let showReviewActivity: Bool
    let showTodoActivity: Bool
    let showReminder: Bool
    let showAppActivity: Bool
    let showAnyActivity: Bool
    let isActivityVisualState: Bool
    let collapsedWidth: CGFloat
    let collapsedCornerRadius: CGFloat
    let collapsedCornerSmoothness: CGFloat
    let visualState: IslandVisualState
    let contentWidthRequirement: IslandContentWidthRequirement

    static func derive(from state: IslandDomainState) -> IslandDerivedState {
        let hasMusicActivitySource = state.primaryMode == .music && state.mockSources.music != nil
        let hasAppActivitySource = state.primaryMode == .app && state.authState == .loggedIn
        let hasAnyActivitySource = hasMusicActivitySource || hasAppActivitySource
        let canShowActivityContent = state.presentationState == .activity && state.forceCompactMode == false
        let showMusicActivity = hasMusicActivitySource && canShowActivityContent
        let showReviewActivity = canShowActivityContent &&
            hasAppActivitySource &&
            state.appDisplayMode == .review &&
            state.mockSources.review != nil
        let showTodoActivity = canShowActivityContent &&
            hasAppActivitySource &&
            state.appDisplayMode == .todo &&
            state.mockSources.todo != nil
        let showReminder = showReviewActivity && state.isReminderActive
        let showAppActivity = showReviewActivity || showTodoActivity
        let showAnyActivity = showMusicActivity || showAppActivity
        let visualState = resolveVisualState(
            for: state,
            showAnyActivity: showAnyActivity
        )
        let collapsedWidth = resolveCollapsedWidth(
            for: state,
            visualState: visualState
        )
        let shellTokens = IslandVisualTokens.shell(for: visualState.tokenSet)

        return IslandDerivedState(
            hasMusicActivitySource: hasMusicActivitySource,
            hasAppActivitySource: hasAppActivitySource,
            hasAnyActivitySource: hasAnyActivitySource,
            showMusicActivity: showMusicActivity,
            showReviewActivity: showReviewActivity,
            showTodoActivity: showTodoActivity,
            showReminder: showReminder,
            showAppActivity: showAppActivity,
            showAnyActivity: showAnyActivity,
            isActivityVisualState: visualState == .activityCollapsed,
            collapsedWidth: collapsedWidth,
            collapsedCornerRadius: shellTokens.radius,
            collapsedCornerSmoothness: shellTokens.smoothness,
            visualState: visualState,
            contentWidthRequirement: contentWidthRequirement(
                for: visualState,
                showMusicActivity: showMusicActivity,
                showAppActivity: showAppActivity
            )
        )
    }

    var widthConstraints: IslandWidthConstraints {
        IslandWidthConstraints(
            baseBodyWidth: collapsedWidth,
            maximumVisibleWidth: nil,
            contentWidthRequirement: contentWidthRequirement
        )
    }

    private static func resolveVisualState(
        for state: IslandDomainState,
        showAnyActivity: Bool
    ) -> IslandVisualState {
        switch state.presentationState {
        case .expanded:
            return state.primaryMode == .music ? .expandedMusic : .expandedApp
        case .activity:
            if showAnyActivity {
                return .activityCollapsed
            }
            if state.isHovered {
                return .hoverCollapsed
            }
            return .compactCollapsed
        case .collapsed:
            return state.isHovered ? .hoverCollapsed : .compactCollapsed
        }
    }

    private static func resolveCollapsedWidth(
        for state: IslandDomainState,
        visualState: IslandVisualState
    ) -> CGFloat {
        if visualState == .activityCollapsed {
            return IslandVisualTokens.activity.previewWidth
        }

        if state.primaryMode == .app,
           state.authState == .loggedIn,
           state.isGreetingActive,
           let greetingText = state.greetingText,
           greetingText.isEmpty == false {
            let estimatedWidth = CGFloat((greetingText.count * 14) + 40)
            return min(
                IslandVisualTokens.compactGreetingMaxWidth,
                max(IslandVisualTokens.compactGreetingMinWidth, estimatedWidth)
            )
        }

        if state.primaryMode == .app,
           state.authState == .loggedIn,
           state.appDisplayMode == .todo {
            return IslandVisualTokens.compactTodoNoActivityWidth
        }

        return state.authState == .loggedIn
            ? IslandVisualTokens.compact.previewWidth - 40
            : IslandVisualTokens.compactSignedOutWidth
    }

    private static func contentWidthRequirement(
        for visualState: IslandVisualState,
        showMusicActivity: Bool,
        showAppActivity: Bool
    ) -> IslandContentWidthRequirement {
        guard visualState == .activityCollapsed, showMusicActivity || showAppActivity else {
            return .none
        }

        return visualState.previewContentWidthRequirement
    }
}
