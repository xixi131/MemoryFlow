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
    let contentWidthBranch: IslandMockContentWidthBranch
    let contentWidthRequirement: IslandContentWidthRequirement
    let previewMarker: IslandPreviewContentMarker
    let previewContent: IslandPreviewContent

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
        let previewMarker = IslandPreviewContentMarker.derive(
            from: state,
            derivedVisualState: visualState,
            showMusicActivity: showMusicActivity,
            showReviewActivity: showReviewActivity,
            showTodoActivity: showTodoActivity,
            showReminder: showReminder
        )
        let previewContent = IslandPreviewContent.derive(
            from: state,
            derivedVisualState: visualState,
            showMusicActivity: showMusicActivity,
            showReviewActivity: showReviewActivity,
            showTodoActivity: showTodoActivity,
            showReminder: showReminder
        )
        let contentWidth = contentWidthResolution(
            for: state,
            visualState: visualState,
            showMusicActivity: showMusicActivity,
            showReviewActivity: showReviewActivity,
            showTodoActivity: showTodoActivity,
            showReminder: showReminder,
            previewMarker: previewMarker,
            previewContent: previewContent
        )

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
            contentWidthBranch: contentWidth.branch,
            contentWidthRequirement: contentWidth.requirement,
            previewMarker: previewMarker,
            previewContent: previewContent
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

    private static func contentWidthResolution(
        for state: IslandDomainState,
        visualState: IslandVisualState,
        showMusicActivity: Bool,
        showReviewActivity: Bool,
        showTodoActivity: Bool,
        showReminder: Bool,
        previewMarker: IslandPreviewContentMarker,
        previewContent: IslandPreviewContent
    ) -> IslandMockContentWidthResolution {
        if visualState != .activityCollapsed {
            return IslandMockContentWidthResolution(
                branch: compactContentWidthBranch(for: state),
                requirement: .none
            )
        }

        let branchRequirement = branchContentWidthRequirement(
            for: state,
            visualState: visualState,
            showMusicActivity: showMusicActivity,
            showReviewActivity: showReviewActivity,
            showTodoActivity: showTodoActivity,
            showReminder: showReminder
        )
        return IslandMockContentWidthResolution(
            branch: branchRequirement.branch,
            requirement: branchRequirement.requirement
        )
    }

    private static func compactContentWidthBranch(for state: IslandDomainState) -> IslandMockContentWidthBranch {
        if state.primaryMode == .music {
            return .music
        }
        if state.authState == .loggedIn,
           state.isGreetingActive,
           let greetingText = state.greetingText,
           greetingText.isEmpty == false {
            return .greeting
        }
        if state.authState == .loggedIn,
           state.appDisplayMode == .todo {
            return .todo
        }
        if state.authState == .loggedIn,
           state.appDisplayMode == .review {
            return .review
        }
        return .compact
    }

    private static func branchContentWidthRequirement(
        for state: IslandDomainState,
        visualState: IslandVisualState,
        showMusicActivity: Bool,
        showReviewActivity: Bool,
        showTodoActivity: Bool,
        showReminder: Bool
    ) -> IslandMockContentWidthResolution {
        if state.primaryMode == .music || showMusicActivity {
            return IslandMockContentWidthResolution(
                branch: .music,
                requirement: IslandContentWidthRequirement(
                    leadingContentWidth: 10,
                    trailingContentWidth: 12,
                    horizontalPadding: 4
                )
            )
        }

        if state.authState == .loggedIn,
           state.isGreetingActive,
           let greetingText = state.greetingText,
           greetingText.isEmpty == false,
           visualState.isExpanded == false {
            return IslandMockContentWidthResolution(
                branch: .greeting,
                requirement: IslandContentWidthRequirement(
                    leadingContentWidth: 28,
                    trailingContentWidth: estimatedGreetingTextWidth(greetingText),
                    horizontalPadding: 16
                )
            )
        }

        if state.authState == .loggedIn,
           state.appDisplayMode == .todo || showTodoActivity {
            return IslandMockContentWidthResolution(
                branch: .todo,
                requirement: IslandContentWidthRequirement(
                    leadingContentWidth: 8,
                    trailingContentWidth: 10,
                    horizontalPadding: 4
                )
            )
        }

        if state.authState == .loggedIn,
           state.appDisplayMode == .review || showReviewActivity || showReminder {
            return IslandMockContentWidthResolution(
                branch: .review,
                requirement: IslandContentWidthRequirement(
                    leadingContentWidth: showReminder ? 12 : 6,
                    trailingContentWidth: showReminder ? 14 : 8,
                    horizontalPadding: 4
                )
            )
        }

        return IslandMockContentWidthResolution(
            branch: .compact,
            requirement: .none
        )
    }

    private static func estimatedGreetingTextWidth(_ greetingText: String) -> CGFloat {
        min(152, max(92, CGFloat(greetingText.count * 10)))
    }
}

enum IslandMockContentWidthBranch: String, Equatable {
    case review
    case todo
    case music
    case greeting
    case compact
}

private struct IslandMockContentWidthResolution: Equatable {
    let branch: IslandMockContentWidthBranch
    let requirement: IslandContentWidthRequirement
}

struct IslandPreviewContentMarker: Equatable {
    enum Tone: String, Equatable {
        case signedOut
        case review
        case todo
        case music
        case reminder
        case gestureLock
        case expanded
    }

    static let hidden = IslandPreviewContentMarker(
        glyph: "",
        label: "",
        tone: .review,
        widthRequirement: .none
    )

    let glyph: String
    let label: String
    let tone: Tone
    let widthRequirement: IslandContentWidthRequirement

    var isVisible: Bool {
        glyph.isEmpty == false || label.isEmpty == false
    }

    var contentWidthRequirement: IslandContentWidthRequirement {
        isVisible ? widthRequirement : .none
    }

    static func derive(
        from state: IslandDomainState,
        derivedVisualState: IslandVisualState,
        showMusicActivity: Bool,
        showReviewActivity: Bool,
        showTodoActivity: Bool,
        showReminder: Bool
    ) -> IslandPreviewContentMarker {
        if state.isGestureTracking || (state.isTrackpadGestureLocked && state.primaryMode != .music) {
            return marker(glyph: "LOCK", label: "Gesture", tone: .gestureLock, textWidth: 86)
        }

        if showReminder || state.isReminderActive || state.isReminderCollapsing {
            return marker(glyph: "REM", label: "Reminder", tone: .reminder, textWidth: 96)
        }

        if showMusicActivity || state.primaryMode == .music {
            return derivedVisualState.isExpanded
                ? marker(glyph: "M+", label: "Music+", tone: .music, textWidth: 86)
                : marker(glyph: "MUS", label: "Music", tone: .music, textWidth: 78)
        }

        if showTodoActivity || state.appDisplayMode == .todo {
            return showTodoActivity
                ? marker(glyph: "TA", label: "Todo A", tone: .todo, textWidth: 78)
                : marker(glyph: "TODO", label: "Todo", tone: .todo, textWidth: 72)
        }

        if state.authState == .loggedOut {
            return marker(glyph: "OUT", label: "Login", tone: .signedOut, textWidth: 76)
        }

        if showReviewActivity || state.appDisplayMode == .review {
            if state.mockSources.review?.nextSubjectTitle == IslandMockScenarioMarkerText.pausedMusicTimeout {
                return marker(glyph: "P30", label: "Music Off", tone: .music, textWidth: 92)
            }

            if derivedVisualState.isExpanded {
                return marker(glyph: "R+", label: "Review+", tone: .expanded, textWidth: 94)
            }

            return showReviewActivity
                ? marker(glyph: "RA", label: "Review A", tone: .review, textWidth: 92)
                : marker(glyph: "REV", label: "Review", tone: .review, textWidth: 84)
        }

        return .hidden
    }

    private static func marker(
        glyph: String,
        label: String,
        tone: Tone,
        textWidth: CGFloat
    ) -> IslandPreviewContentMarker {
        IslandPreviewContentMarker(
            glyph: glyph,
            label: label,
            tone: tone,
            widthRequirement: IslandContentWidthRequirement(
                leadingContentWidth: 30,
                trailingContentWidth: textWidth,
                horizontalPadding: 14
            )
        )
    }
}

enum IslandMockScenarioMarkerText {
    static let pausedMusicTimeout = "Paused Music Timeout"
}

struct IslandPreviewContent: Equatable {
    enum Kind: String, Equatable {
        case signedOutCompact
        case reviewCompact
        case todoCompact
        case reviewActivity
        case todoActivity
        case musicActivity
        case greetingCompact
        case reminderActivity
        case expandedReview
        case expandedTodo
        case expandedMusic
        case gestureLock
    }

    let kind: Kind
    let eyebrow: String
    let title: String
    let subtitle: String
    let badge: String
    let tone: IslandPreviewContentMarker.Tone
    let review: IslandMockReviewActivity?
    let todo: IslandMockTodoActivity?
    let music: IslandMockMusicActivity?
    let contentWidthRequirement: IslandContentWidthRequirement

    static func derive(
        from state: IslandDomainState,
        derivedVisualState: IslandVisualState,
        showMusicActivity: Bool,
        showReviewActivity: Bool,
        showTodoActivity: Bool,
        showReminder: Bool
    ) -> IslandPreviewContent {
        if state.isGestureTracking || (state.isTrackpadGestureLocked && state.primaryMode != .music) {
            return IslandPreviewContent(
                kind: .gestureLock,
                eyebrow: "Gesture",
                title: "Input Lock",
                subtitle: "Cooldown",
                badge: "LOCK",
                tone: .gestureLock,
                review: nil,
                todo: nil,
                music: nil,
                contentWidthRequirement: width(leading: 36, trailing: 108, padding: 14)
            )
        }

        if showMusicActivity || state.primaryMode == .music {
            let music = state.mockSources.music ?? .sample
            return IslandPreviewContent(
                kind: derivedVisualState.isExpanded ? .expandedMusic : .musicActivity,
                eyebrow: music.isPlaying ? "Now Playing" : "Paused",
                title: music.trackTitle,
                subtitle: music.artistName,
                badge: music.isPlaying ? "PLAY" : "PAUSE",
                tone: .music,
                review: nil,
                todo: nil,
                music: music,
                contentWidthRequirement: derivedVisualState.isExpanded
                    ? width(leading: 90, trailing: 260, padding: 28)
                    : width(leading: 44, trailing: 72, padding: 18)
            )
        }

        if state.authState == .loggedOut {
            return IslandPreviewContent(
                kind: .signedOutCompact,
                eyebrow: "Signed Out",
                title: "点击登录",
                subtitle: "MemoryFlow",
                badge: "OUT",
                tone: .signedOut,
                review: nil,
                todo: nil,
                music: nil,
                contentWidthRequirement: width(leading: 28, trailing: 82, padding: 14)
            )
        }

        if state.isGreetingActive,
           let greetingText = state.greetingText,
           greetingText.isEmpty == false {
            return IslandPreviewContent(
                kind: .greetingCompact,
                eyebrow: "MemoryFlow",
                title: greetingText,
                subtitle: "Ready for your next review",
                badge: "HI",
                tone: .review,
                review: state.mockSources.review,
                todo: nil,
                music: nil,
                contentWidthRequirement: width(leading: 30, trailing: 152, padding: 16)
            )
        }

        if showTodoActivity || state.appDisplayMode == .todo {
            let todo = state.mockSources.todo ?? .empty
            return IslandPreviewContent(
                kind: derivedVisualState.isExpanded ? .expandedTodo : (showTodoActivity ? .todoActivity : .todoCompact),
                eyebrow: "Todo",
                title: todo.pendingCount > 0 ? "待办 \(todo.pendingCount) 项" : "待办模式",
                subtitle: todo.nextTaskTitle ?? "今日待办",
                badge: todo.overdueCount > 0 ? "\(todo.overdueCount) 逾期" : "\(todo.dueTodayCount) 到期",
                tone: .todo,
                review: nil,
                todo: todo,
                music: nil,
                contentWidthRequirement: derivedVisualState.isExpanded
                    ? width(leading: 120, trailing: 230, padding: 28)
                    : width(leading: 38, trailing: showTodoActivity ? 118 : 96, padding: 16)
            )
        }

        let review = state.mockSources.review ?? .empty
        let isPausedTimeout = review.nextSubjectTitle == IslandMockScenarioMarkerText.pausedMusicTimeout
        let isReminder = showReminder || state.isReminderActive || state.isReminderCollapsing
        let reminder = state.mockSources.reminder
        return IslandPreviewContent(
            kind: derivedVisualState.isExpanded
                ? .expandedReview
                : (isReminder ? .reminderActivity : (showReviewActivity ? .reviewActivity : .reviewCompact)),
            eyebrow: isReminder ? "Reminder" : (isPausedTimeout ? "Music Timeout" : "Review"),
            title: isPausedTimeout ? "音乐已收起" : "复习 \(review.pendingCount) 项",
            subtitle: isReminder ? (reminder?.timeText ?? "Now") : (review.nextSubjectTitle ?? "Review"),
            badge: isReminder ? (reminder?.isDue == true ? "DUE" : "REM") : "\(review.pendingCount)",
            tone: isReminder ? .reminder : (isPausedTimeout ? .music : .review),
            review: review,
            todo: nil,
            music: nil,
            contentWidthRequirement: derivedVisualState.isExpanded
                ? width(leading: 130, trailing: 220, padding: 28)
                : width(leading: 38, trailing: isReminder ? 132 : 104, padding: 16)
        )
    }

    private static func width(
        leading: CGFloat,
        trailing: CGFloat,
        padding: CGFloat
    ) -> IslandContentWidthRequirement {
        IslandContentWidthRequirement(
            leadingContentWidth: leading,
            trailingContentWidth: trailing,
            horizontalPadding: padding
        )
    }
}
