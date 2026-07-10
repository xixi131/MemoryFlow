import Foundation

enum IslandMotionProbe {
    static func validateReminderAutoOpen() throws {
        let key = "2026-07-10"
        let first = IslandPresentationReducer.reduce(
            current: .loggedInReviewCompact,
            intent: .reminderDue(key)
        )
        let repeated = IslandPresentationReducer.reduce(
            current: first.state,
            intent: .reminderDue(key)
        )
        let unlocked = IslandPresentationReducer.reduce(
            current: first.state,
            intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
        )
        let returnedCompact = IslandPresentationReducer.reduce(
            current: unlocked.state,
            intent: .pointerSwipe(.right)
        )
        let closeCompleted = IslandPresentationReducer.reduce(
            current: returnedCompact.state,
            intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
        )
        let nextKey = IslandPresentationReducer.reduce(
            current: closeCompleted.state,
            intent: .reminderDue("2026-07-11")
        )
        let expanded = IslandPresentationReducer.reduce(
            current: .expandedAppReview,
            intent: .reminderDue("2026-07-12")
        )
        let reminderPlan = IslandMotionEngine.plan(
            previous: IslandDerivedState.derive(from: .loggedInReviewCompact),
            next: first.derivedState,
            reason: first.reason,
            presentation: .idle,
            reduceMotion: false
        )
        let collapsePlan = IslandMotionEngine.plan(
            previous: first.derivedState,
            next: returnedCompact.derivedState,
            reason: returnedCompact.reason,
            presentation: .idle,
            reduceMotion: false
        )

        guard first.reason == .reminderDueOpenedReviewActivity,
              first.derivedState.visualState == .activityCollapsed,
              first.state.lastReminderDueKey == key,
              repeated.reason == .intentIgnored,
              repeated.state == first.state,
              unlocked.reason == .noChange,
              returnedCompact.reason == .pointerSwipedToCompact,
              returnedCompact.derivedState.visualState == .compactCollapsed,
              closeCompleted.reason == .noChange,
              nextKey.reason == .reminderDueOpenedReviewActivity,
              nextKey.state.lastReminderDueKey == "2026-07-11",
              expanded.reason == .intentIgnored,
              reminderPlan.transitionKind == .reminderOpen,
              reminderPlan.shellFrame.keyframes == IslandMotionTokens.profile(for: .compactToActivity).shellKeyframes,
              reminderPlan.content.enter == IslandMotionTokens.profile(for: .compactToActivity).contentEnter,
              reminderPlan.content.exit == IslandMotionTokens.profile(for: .compactToActivity).contentExit,
              collapsePlan.transitionKind == .reminderRecover,
              collapsePlan.shellFrame.keyframes.duration == IslandMotionTokens.activityCollapseDuration else {
            throw IslandMotionProbeError.invalidReminderAutoOpen
        }
    }

    static func validateExpandedCollapseRecovery() throws {
        let sources: [IslandDomainState] = [.mockExpandedReview, .mockExpandedTodo, .mockExpandedMusic]
        let tapResults = sources.map { IslandPresentationReducer.reduce(current: $0, intent: .tap) }
        let outsideResults = sources.map { IslandPresentationReducer.reduce(current: $0, intent: .outsideCollapse) }
        var forced = IslandDomainState.mockExpandedReview
        forced.forceCompactMode = true
        let forcedResult = IslandPresentationReducer.reduce(current: forced, intent: .outsideCollapse)
        guard tapResults.allSatisfy({ $0.derivedState.visualState == .activityCollapsed || $0.derivedState.visualState == .compactCollapsed }),
              outsideResults.allSatisfy({ $0.derivedState.visualState == .activityCollapsed || $0.derivedState.visualState == .compactCollapsed }),
              forcedResult.derivedState.visualState == .compactCollapsed || forcedResult.state.forceCompactMode,
              IslandVisualTokens.expandedContentExit.exitDuration == 0.15,
              IslandVisualTokens.expandedContentExit.exitBlurRadius == 5 else {
            throw IslandMotionProbeError.invalidExpandedCollapseRecovery
        }
    }
    static func validateExpandedMusicOpenPlans() throws -> [ExpandedAppOpenRow] {
        let cases: [(String, IslandPresentationTransitionReason)] = [
            ("tap", .tapExpandedToMusic),
            ("trackpad", .trackpadSwipedDownToExpandedMusic)
        ]
        let previous = IslandDerivedState.derive(from: .musicActivity)
        let next = IslandDerivedState.derive(from: .expandedMusic)
        let snapshot = IslandShapeEngine.snapshot(for: next.visualState, visualScale: 1)
        let rows = cases.map { input, reason in
            let plan = IslandMotionEngine.plan(previous: previous, next: next, reason: reason, presentation: .idle, reduceMotion: false)
            return ExpandedAppOpenRow(mode: "music", input: input, contentKind: next.previewContent.kind, shellDuration: plan.shellFrame.keyframes.duration, width: snapshot.metrics.width, height: snapshot.metrics.height)
        }
        guard rows.allSatisfy({ $0.shellDuration == IslandMotionTokens.activityOpenDuration }),
              rows.allSatisfy({ $0.width == 460 && $0.height == 210 }),
              rows[0].contentKind == rows[1].contentKind,
              rows[0].contentKind == .expandedMusic else {
            throw IslandMotionProbeError.invalidExpandedMusicOpenPlan
        }
        return rows
    }
    struct ExpandedAppOpenRow: Equatable {
        let mode: String
        let input: String
        let contentKind: IslandPreviewContent.Kind
        let shellDuration: TimeInterval
        let width: CGFloat
        let height: CGFloat
    }

    static func validateExpandedAppOpenPlans() throws -> [ExpandedAppOpenRow] {
        let cases: [(String, IslandDomainState, IslandDomainState, IslandPresentationTransitionReason)] = [
            ("review", .loggedInReviewActivity, .expandedAppReview, .tapExpandedToApp),
            ("review", .loggedInReviewActivity, .expandedAppReview, .trackpadSwipedDownToExpandedApp),
            ("todo", .loggedInTodoActivity, .mockExpandedTodo, .tapExpandedToApp),
            ("todo", .loggedInTodoActivity, .mockExpandedTodo, .trackpadSwipedDownToExpandedApp)
        ]
        let rows = cases.map { mode, source, destination, reason in
            let previous = IslandDerivedState.derive(from: source)
            let next = IslandDerivedState.derive(from: destination)
            let plan = IslandMotionEngine.plan(previous: previous, next: next, reason: reason, presentation: .idle, reduceMotion: false)
            let snapshot = IslandShapeEngine.snapshot(for: next.visualState, visualScale: 1)
            return ExpandedAppOpenRow(
                mode: mode,
                input: reason.rawValue,
                contentKind: next.previewContent.kind,
                shellDuration: plan.shellFrame.keyframes.duration,
                width: snapshot.metrics.width,
                height: snapshot.metrics.height
            )
        }
        guard rows.allSatisfy({ $0.shellDuration == IslandMotionTokens.activityOpenDuration }),
              rows.allSatisfy({ $0.width == IslandVisualTokens.expandedApp.previewWidth && $0.height == IslandVisualTokens.expandedApp.height }),
              rows[0].contentKind == rows[1].contentKind,
              rows[2].contentKind == rows[3].contentKind,
              rows[0].contentKind != rows[2].contentKind else {
            throw IslandMotionProbeError.invalidExpandedAppOpenPlan
        }
        return rows
    }
    struct ActivityCollapseRow: Equatable {
        let route: String
        let transitionKind: IslandTransitionKind
        let shellDuration: TimeInterval
        let frames: [IslandShellWidthKeyframe]
        let contentExit: IslandContentMotionToken
    }

    static func validateActivityCollapsePlans() throws -> [ActivityCollapseRow] {
        let cases: [(String, IslandDomainState, IslandDomainState, IslandPresentationTransitionReason)] = [
            ("review", .loggedInReviewActivity, .loggedInReviewCompact, .pointerSwipedToCompact),
            ("todo", .loggedInTodoActivity, .loggedInTodoCompact, .pointerSwipedToCompact),
            ("music", .musicActivity, .musicCompactFallback, .pointerSwipedToCompact),
            ("reminder", .mockReminderDue, .loggedInReviewCompact, .outsideCollapsedToCompact),
            ("expanded", .expandedAppReview, .loggedInReviewCompact, .outsideCollapsedToCompact)
        ]
        let rows = cases.map { route, source, destination, reason in
            let previous = IslandDerivedState.derive(from: source)
            let next = IslandDerivedState.derive(from: destination)
            let plan = IslandMotionEngine.plan(
                previous: previous,
                next: next,
                reason: reason,
                presentation: .idle,
                reduceMotion: false
            )
            let sourceSnapshot = IslandCompactContentLayout.snapshot(
                for: previous.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: previous.widthConstraints
            )
            let targetSnapshot = IslandCompactContentLayout.snapshot(
                for: next.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: next.widthConstraints
            )
            return ActivityCollapseRow(
                route: route,
                transitionKind: plan.transitionKind,
                shellDuration: plan.shellFrame.keyframes.duration,
                frames: IslandMotionTokens.activityCollapseFrames(
                    fromWidth: sourceSnapshot.metrics.width,
                    compactWidth: targetSnapshot.metrics.width
                ),
                contentExit: plan.content.exit
            )
        }

        guard rows.allSatisfy({ $0.shellDuration == IslandMotionTokens.activityCollapseDuration }),
              rows.allSatisfy({ $0.frames.map(\.time) == IslandMotionTokens.activityCollapseTimes }),
              rows.allSatisfy({ $0.frames[1].width == $0.frames[2].width }),
              rows.allSatisfy({ $0.contentExit.duration == IslandVisualTokens.activityCollapseContent.exitDuration }),
              rows.allSatisfy({ $0.contentExit.blurRadius == IslandVisualTokens.activityCollapseContent.exitBlurRadius }),
              rows[0...2].allSatisfy({ $0.transitionKind == .activityToCompact }),
              rows[3].transitionKind == .reminderRecover,
              rows[4].transitionKind == .expandedToCompact else {
            throw IslandMotionProbeError.invalidActivityCollapsePlan
        }
        return rows
    }
    struct ActivityOpenRow: Equatable {
        let mode: String
        let contentKind: IslandPreviewContent.Kind
        let transitionKind: IslandTransitionKind
        let shellDuration: TimeInterval
        let contentDelay: TimeInterval
        let contentDuration: TimeInterval
        let contentBlur: CGFloat
        let compactWidth: CGFloat
        let activityWidth: CGFloat
        let compactRadius: CGFloat
        let activityRadius: CGFloat
        let compactSmoothness: CGFloat
        let activitySmoothness: CGFloat
    }

    static func validateActivityOpenPlans() throws -> [ActivityOpenRow] {
        let compactStates: [IslandDomainState] = [
            .loggedInReviewCompact,
            .loggedInTodoCompact,
            .musicCompactFallback
        ]
        let activityStates: [IslandDomainState] = [
            .loggedInReviewActivity,
            .loggedInTodoActivity,
            .musicActivity
        ]
        let modes = ["review", "todo", "music"]
        let rows = zip(zip(modes, compactStates), activityStates).map { entry in
            let compact = IslandDerivedState.derive(from: entry.0.1)
            let activity = IslandDerivedState.derive(from: entry.1)
            let plan = IslandMotionEngine.plan(
                previous: compact,
                next: activity,
                reason: .tapCollapsedToActivity,
                presentation: .idle,
                reduceMotion: false
            )
            let compactSnapshot = IslandCompactContentLayout.snapshot(
                for: compact.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: compact.widthConstraints
            )
            let activitySnapshot = IslandCompactContentLayout.snapshot(
                for: activity.visualState,
                visualScale: 1,
                horizontalScale: 1,
                widthConstraints: activity.widthConstraints
            )
            return ActivityOpenRow(
                mode: entry.0.0,
                contentKind: activity.previewContent.kind,
                transitionKind: plan.transitionKind,
                shellDuration: plan.shellFrame.keyframes.duration,
                contentDelay: plan.content.enter.delay,
                contentDuration: plan.content.enter.duration,
                contentBlur: plan.content.enter.blurRadius,
                compactWidth: compactSnapshot.metrics.width,
                activityWidth: activitySnapshot.metrics.width,
                compactRadius: compactSnapshot.metrics.radius,
                activityRadius: activitySnapshot.metrics.radius,
                compactSmoothness: compactSnapshot.metrics.smoothness,
                activitySmoothness: activitySnapshot.metrics.smoothness
            )
        }

        guard rows.map(\.transitionKind).allSatisfy({ $0 == .compactToActivity }),
              rows.map(\.shellDuration).allSatisfy({ $0 == IslandMotionTokens.activityOpenDuration }),
              rows.map(\.contentDelay).allSatisfy({ $0 == IslandMotionTokens.activityContentEnterDelay }),
              rows.map(\.contentDuration).allSatisfy({ $0 == IslandMotionTokens.activityContentEnterDuration }),
              rows.map(\.contentBlur).allSatisfy({ $0 == IslandMotionTokens.activityContentEnterBlur }),
              rows.allSatisfy({ $0.activityWidth > $0.compactWidth }),
              rows.allSatisfy({ $0.activityRadius != $0.compactRadius }),
              rows.allSatisfy({ $0.activitySmoothness != $0.compactSmoothness }),
              Set(rows.map(\.contentKind)).count == 3 else {
            throw IslandMotionProbeError.invalidActivityOpenPlan
        }
        return rows
    }

    static func validateNonDefaultPlans() throws -> [IslandTransitionKind] {
        let previous = IslandDerivedState.derive(from: .loggedInReviewCompact)
        let activity = IslandDerivedState.derive(from: .loggedInReviewActivity)
        let expanded = IslandDerivedState.derive(from: .expandedAppReview)
        var hoverDomainState = IslandDomainState.loggedInReviewCompact
        hoverDomainState.isHovered = true
        let hover = IslandDerivedState.derive(from: hoverDomainState)
        let music = IslandDerivedState.derive(from: .musicActivity)
        let pairs: [(IslandDerivedState, IslandDerivedState, IslandPresentationTransitionReason)] = [
            (previous, activity, .tapCollapsedToActivity), (activity, previous, .pointerSwipedToCompact),
            (activity, expanded, .tapExpandedToApp), (expanded, activity, .tapCollapsedToActivity),
            (expanded, previous, .outsideCollapsedToCompact), (previous, previous, .modeSwitchedToTodo),
            (previous, activity, .reminderDueOpenedReviewActivity), (activity, previous, .outsideCollapsedToCompact),
            (previous, music, .musicSnapshotAccepted), (previous, hover, .hoverEntered),
            (hover, previous, .hoverLeft)
        ]
        let kinds = pairs.map { pair in
            IslandMotionEngine.plan(previous: pair.0, next: pair.1, reason: pair.2, presentation: .idle, reduceMotion: false).transitionKind
        }
        let expected = Set(IslandTransitionKind.allCases.filter { $0 != .defaultProfile })
        guard Set(kinds) == expected else { throw IslandMotionProbeError.missingPlans(expected.subtracting(kinds)) }
        guard kinds.allSatisfy({ IslandMotionTokens.profile(for: $0).shellKeyframes.duration > 0 }) else { throw IslandMotionProbeError.defaultPlan }
        return kinds
    }
}

enum IslandMotionProbeError: Error, CustomStringConvertible {
    case missingPlans(Set<IslandTransitionKind>)
    case defaultPlan
    case invalidActivityOpenPlan
    case invalidActivityCollapsePlan
    case invalidExpandedAppOpenPlan
    case invalidExpandedMusicOpenPlan
    case invalidExpandedCollapseRecovery
    case invalidReminderAutoOpen
    var description: String {
        switch self {
        case let .missingPlans(kinds): return "Missing motion plans: \(kinds.map(\.rawValue).sorted())"
        case .defaultPlan: return "A non-default motion plan has no duration"
        case .invalidActivityOpenPlan: return "Review, todo, and music do not share the activity-open shell timeline with distinct content."
        case .invalidActivityCollapsePlan: return "Collapse routes do not share the segmented shell hold and content-exit contract."
        case .invalidExpandedAppOpenPlan: return "Tap and trackpad app expansion do not share the 460 by 320 shell while keeping review and todo content distinct."
        case .invalidExpandedMusicOpenPlan: return "Tap and trackpad music expansion do not share the 460 by 210 mock music shell."
        case .invalidExpandedCollapseRecovery: return "Expanded content did not recover activity sources or respect force-compact collapse."
        case .invalidReminderAutoOpen: return "Reminder due did not use keyed compact-to-review activity opening and segmented recovery."
        }
    }
}
