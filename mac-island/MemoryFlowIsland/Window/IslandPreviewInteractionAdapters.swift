import CoreGraphics
import Foundation

struct IslandPointerGestureAdapter: Equatable {
    private(set) var startX: Double?
    private(set) var currentX: Double?

    var isTracking: Bool {
        startX != nil
    }

    mutating func pointerDown(at x: Double) {
        startX = x
        currentX = x
    }

    mutating func pointerDragged(to x: Double) {
        guard startX != nil else { return }
        currentX = x
    }

    mutating func pointerUp(at x: Double) -> IslandInteractionIntent? {
        guard let startX else { return nil }
        let resolvedCurrentX = currentX ?? x
        let deltaX = resolvedCurrentX - startX
        reset()

        if let swipeDirection = IslandInteractionThresholds.pointerSwipeDirection(for: deltaX) {
            return .pointerSwipe(swipeDirection)
        }

        if IslandInteractionThresholds.isTapMovement(deltaX: deltaX) {
            return .tap
        }

        return nil
    }

    mutating func cancel() {
        reset()
    }

    private mutating func reset() {
        startX = nil
        currentX = nil
    }
}

/// Pure long-press classification for the activity's leading icon. Scheduling remains
/// controller-owned so scenario replacement can cancel outstanding work items.
struct IslandModeSwitchHoldAdapter: Equatable {
    private(set) var beganAt: TimeInterval?
    private(set) var isLeadingIconHold = false
    private(set) var hasTriggered = false

    var isHolding: Bool { beganAt != nil }

    mutating func pointerDown(onLeadingIcon: Bool, at timestamp: TimeInterval) {
        reset()
        guard onLeadingIcon else { return }
        beganAt = timestamp
        isLeadingIconHold = true
    }

    mutating func triggerIfEligible(at timestamp: TimeInterval) -> Bool {
        guard let beganAt,
              isLeadingIconHold,
              hasTriggered == false,
              timestamp - beganAt >= IslandInteractionThresholds.modeSwitchLongPressWindow else {
            return false
        }
        hasTriggered = true
        return true
    }

    mutating func pointerLeftLeadingIcon() {
        guard hasTriggered == false else { return }
        reset()
    }

    mutating func pointerReleased() {
        guard hasTriggered == false else { return }
        reset()
    }

    mutating func cancel() { reset() }

    private mutating func reset() {
        beganAt = nil
        isLeadingIconHold = false
        hasTriggered = false
    }
}

struct IslandTrackpadWheelAdapter: Equatable {
    private(set) var accumulatedDeltaX: Double = 0
    private(set) var accumulatedDeltaY: Double = 0
    private(set) var lastEventTimestamp: TimeInterval?
    private(set) var cooldownUntil: TimeInterval?

    mutating func registerEvent(
        deltaX: Double,
        deltaY: Double,
        timestamp: TimeInterval
    ) -> IslandInteractionIntent? {
        if let cooldownUntil, timestamp < cooldownUntil {
            return nil
        }

        if let lastEventTimestamp,
           timestamp - lastEventTimestamp > IslandInteractionThresholds.trackpadGestureResetWindow {
            resetAccumulation()
        }

        accumulatedDeltaX += deltaX
        accumulatedDeltaY += deltaY
        lastEventTimestamp = timestamp

        guard let intent = IslandInteractionThresholds.dominantTrackpadIntent(
            deltaX: accumulatedDeltaX,
            deltaY: accumulatedDeltaY
        ) else {
            return nil
        }

        cooldownUntil = timestamp + IslandInteractionThresholds.trackpadGestureCooldownWindow
        resetAccumulation()
        return intent
    }

    mutating func clearCooldown() {
        cooldownUntil = nil
    }

    mutating func reset() {
        resetAccumulation()
        clearCooldown()
        lastEventTimestamp = nil
    }

    private mutating func resetAccumulation() {
        accumulatedDeltaX = 0
        accumulatedDeltaY = 0
    }
}

struct IslandPreviewInteractionProbeRow: Codable, Equatable {
    let scenarioID: String
    let emittedIntents: [String]
    let finalVisualState: String
    let finalPresentationState: String
    let isHovered: Bool
    let isForceCompactMode: Bool
}

enum IslandPreviewInteractionProbe {
    static func generateRows() -> [IslandPreviewInteractionProbeRow] {
        [
            tapExpandCollapseRow(),
            hoverEnterLeaveRow(),
            pointerTapClassificationRow(),
            pointerCollapseRestoreRow(),
            expandedAppCollapseRecoveryRow(),
            expandedMusicCollapseRecoveryRow(),
            expandedLoggedOutCollapseRecoveryRow(),
            expandedCompactOnlyCollapseRecoveryRow(),
            trackpadHorizontalMusicRow(),
            trackpadCooldownRow()
        ]
    }

    private static func tapExpandCollapseRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        var intents: [String] = []

        intents.append(record(container.dispatch(intent: .tap).reducerResult))
        intents.append(record(container.dispatch(intent: .tap).reducerResult))

        return row(
            scenarioID: "tap-expand-collapse",
            intents: intents,
            container: container
        )
    }

    private static func hoverEnterLeaveRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        var intents: [String] = []

        intents.append(record(container.dispatch(intent: .hoverEnter).reducerResult))
        intents.append(record(container.dispatch(intent: .hoverLeave).reducerResult))

        return row(
            scenarioID: "hover-enter-leave",
            intents: intents,
            container: container
        )
    }

    private static func pointerCollapseRestoreRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewActivity)
        var pointerAdapter = IslandPointerGestureAdapter()
        var intents: [String] = []

        pointerAdapter.pointerDown(at: 0)
        pointerAdapter.pointerDragged(to: 40)
        if let intent = pointerAdapter.pointerUp(at: 40) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }
        intents.append(
            record(
                container.dispatch(
                    intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
                ).reducerResult
            )
        )

        pointerAdapter.pointerDown(at: 40)
        pointerAdapter.pointerDragged(to: 0)
        if let intent = pointerAdapter.pointerUp(at: 0) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }

        return row(
            scenarioID: "pointer-collapse-restore",
            intents: intents,
            container: container
        )
    }

    private static func pointerTapClassificationRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        var pointerAdapter = IslandPointerGestureAdapter()
        var intents: [String] = []

        pointerAdapter.pointerDown(at: 100)
        pointerAdapter.pointerDragged(to: 106)
        if let intent = pointerAdapter.pointerUp(at: 106) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }

        return row(
            scenarioID: "pointer-tap-classification",
            intents: intents,
            container: container
        )
    }

    private static func expandedAppCollapseRecoveryRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .expandedAppReview)
        let intents = [
            record(container.dispatch(intent: .outsideCollapse).reducerResult)
        ]

        return row(
            scenarioID: "expanded-app-source-collapse-recovery",
            intents: intents,
            container: container
        )
    }

    private static func expandedMusicCollapseRecoveryRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .expandedMusic)
        let intents = [
            record(container.dispatch(intent: .outsideCollapse).reducerResult)
        ]

        return row(
            scenarioID: "expanded-music-source-collapse-recovery",
            intents: intents,
            container: container
        )
    }

    private static func expandedLoggedOutCollapseRecoveryRow() -> IslandPreviewInteractionProbeRow {
        var state = IslandDomainState.loggedOutCompact
        state.presentationState = .expanded
        var container = IslandPhase5PreviewStateContainer(initialState: state)
        let intents = [
            record(container.dispatch(intent: .outsideCollapse).reducerResult)
        ]

        return row(
            scenarioID: "expanded-logged-out-collapse-recovery",
            intents: intents,
            container: container
        )
    }

    private static func expandedCompactOnlyCollapseRecoveryRow() -> IslandPreviewInteractionProbeRow {
        var state = IslandDomainState.loggedInReviewCompact
        state.presentationState = .expanded
        state.mockSources = .none
        var container = IslandPhase5PreviewStateContainer(initialState: state)
        let intents = [
            record(container.dispatch(intent: .outsideCollapse).reducerResult)
        ]

        return row(
            scenarioID: "expanded-compact-only-collapse-recovery",
            intents: intents,
            container: container
        )
    }

    private static func trackpadCooldownRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewActivity)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        var intents: [String] = []
        let t0: TimeInterval = 0

        if let intent = wheelAdapter.registerEvent(deltaX: 0, deltaY: 75, timestamp: t0) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }

        let suppressedIntent = wheelAdapter.registerEvent(
            deltaX: 0,
            deltaY: -90,
            timestamp: t0 + 0.050
        )
        intents.append(suppressedIntent.map(describe) ?? "suppressedDuringCooldown")

        intents.append(
            record(
                container.dispatch(
                    intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown)
                ).reducerResult
            )
        )
        intents.append(
            record(
                container.dispatch(
                    intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
                ).reducerResult
            )
        )

        wheelAdapter.clearCooldown()
        if let intent = wheelAdapter.registerEvent(
            deltaX: 0,
            deltaY: -90,
            timestamp: t0 + 0.400
        ) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }

        return row(
            scenarioID: "trackpad-cooldown-lock",
            intents: intents,
            container: container
        )
    }

    private static func trackpadHorizontalMusicRow() -> IslandPreviewInteractionProbeRow {
        var container = IslandPhase5PreviewStateContainer(initialState: .musicActivity)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        var intents: [String] = []

        if let intent = wheelAdapter.registerEvent(deltaX: 78, deltaY: 8, timestamp: 0) {
            intents.append(describe(intent))
            intents.append(record(container.dispatch(intent: intent).reducerResult))
        }

        return row(
            scenarioID: "trackpad-horizontal-music",
            intents: intents,
            container: container
        )
    }

    private static func row(
        scenarioID: String,
        intents: [String],
        container: IslandPhase5PreviewStateContainer
    ) -> IslandPreviewInteractionProbeRow {
        let derivedState = container.derivedState
        return IslandPreviewInteractionProbeRow(
            scenarioID: scenarioID,
            emittedIntents: intents,
            finalVisualState: derivedState.visualState.rawValue,
            finalPresentationState: container.domainState.presentationState.rawValue,
            isHovered: container.domainState.isHovered,
            isForceCompactMode: container.domainState.forceCompactMode
        )
    }

    private static func record(_ result: IslandPresentationReducerResult) -> String {
        "\(result.reason.rawValue)->\(result.derivedState.visualState.rawValue)"
    }

    private static func describe(_ intent: IslandInteractionIntent) -> String {
        switch intent {
        case .hoverEnter:
            return "hoverEnter"
        case .hoverLeave:
            return "hoverLeave"
        case .tap:
            return "tap"
        case .outsideCollapse:
            return "outsideCollapse"
        case let .pointerSwipe(direction):
            return "pointerSwipe(\(direction.rawValue))"
        case let .trackpadSwipe(direction):
            return "trackpadSwipe(\(direction.rawValue))"
        case let .horizontalMusicCommand(command):
            return "horizontalMusicCommand(\(command.rawValue))"
        case let .musicSnapshotUpdated(snapshot):
            return "musicSnapshotUpdated(\(snapshot.title))"
        case .musicStopped:
            return "musicStopped"
        case let .musicCommandRequested(command):
            return "musicCommandRequested(\(command.rawValue))"
        case .modeSwitchToggle:
            return "modeSwitchToggle"
        case .modeSwitchMutate:
            return "modeSwitchMutate"
        case .reminderDue:
            return "reminderDue"
        case .pausedMusicTimeout:
            return "pausedMusicTimeout"
        case .greetingLifecycleCompleted:
            return "greetingLifecycleCompleted"
        case .greetingFastForward:
            return "greetingFastForward"
        case let .mockScenarioSelect(identifier):
            return "mockScenarioSelect(\(identifier))"
        case .retargetPresentation:
            return "retargetPresentation"
        case let .transitionComplete(identifier):
            return "transitionComplete(\(identifier ?? "nil"))"
        }
    }
}

enum IslandModeSwitchProbe {
    static func validate() throws {
        var hold = IslandModeSwitchHoldAdapter()
        hold.pointerDown(onLeadingIcon: true, at: 0)
        guard hold.triggerIfEligible(at: 0.419) == false else {
            throw IslandModeSwitchProbeError.earlyHoldTriggered
        }
        hold.pointerReleased()
        guard hold.triggerIfEligible(at: 1) == false else {
            throw IslandModeSwitchProbeError.releaseDidNotCancel
        }

        hold.pointerDown(onLeadingIcon: true, at: 2)
        hold.pointerLeftLeadingIcon()
        guard hold.triggerIfEligible(at: 3) == false else {
            throw IslandModeSwitchProbeError.leaveDidNotCancel
        }

        hold.pointerDown(onLeadingIcon: true, at: 4)
        guard hold.triggerIfEligible(at: 4.421) else {
            throw IslandModeSwitchProbeError.qualifiedHoldDidNotTrigger
        }

        let compactTarget = IslandPresentationRetargetTarget(
            presentationState: .activity,
            forceCompactMode: true,
            isHovered: false
        )
        let activityTarget = IslandPresentationRetargetTarget(
            presentationState: .activity,
            forceCompactMode: false,
            isHovered: false
        )
        try validateSequence(
            initial: .loggedInReviewActivity,
            expectedMode: .todo,
            compactTarget: compactTarget,
            activityTarget: activityTarget
        )
        try validateSequence(
            initial: .loggedInTodoActivity,
            expectedMode: .review,
            compactTarget: compactTarget,
            activityTarget: activityTarget
        )
    }

    private static func validateSequence(
        initial: IslandDomainState,
        expectedMode: IslandAppDisplayMode,
        compactTarget: IslandPresentationRetargetTarget,
        activityTarget: IslandPresentationRetargetTarget
    ) throws {
        let compact = IslandPresentationReducer.reduce(
            current: initial,
            intent: .retargetPresentation(compactTarget)
        )
        guard compact.derivedState.visualState == .compactCollapsed else {
            throw IslandModeSwitchProbeError.compactPhaseWasNotCompact
        }

        let mutated = IslandPresentationReducer.reduce(current: compact.state, intent: .modeSwitchMutate)
        guard mutated.state.appDisplayMode == expectedMode,
              mutated.derivedState.visualState == .compactCollapsed,
              mutated.state.isModeSwitchLocked else {
            throw IslandModeSwitchProbeError.mutationLeakedActivityContent
        }

        let duplicate = IslandPresentationReducer.reduce(current: mutated.state, intent: .modeSwitchToggle)
        guard duplicate.reason == .modeSwitchLocked else {
            throw IslandModeSwitchProbeError.duplicateWasAccepted
        }

        let reopened = IslandPresentationReducer.reduce(current: mutated.state, intent: .retargetPresentation(activityTarget))
        guard reopened.state.appDisplayMode == expectedMode,
              reopened.derivedState.visualState == .activityCollapsed,
              reopened.derivedState.previewContent.kind == (expectedMode == .todo ? .todoActivity : .reviewActivity),
              reopened.state.isModeSwitchLocked else {
            throw IslandModeSwitchProbeError.reopenContainedStaleContent
        }

        let finished = IslandPresentationReducer.reduce(
            current: reopened.state,
            intent: .transitionComplete(IslandTransitionLockIdentifier.modeSwitchLock)
        )
        guard finished.state.isModeSwitchLocked == false else {
            throw IslandModeSwitchProbeError.lockDidNotRelease
        }
    }
}

enum IslandModeSwitchProbeError: Error {
    case earlyHoldTriggered
    case releaseDidNotCancel
    case leaveDidNotCancel
    case qualifiedHoldDidNotTrigger
    case compactPhaseWasNotCompact
    case mutationLeakedActivityContent
    case duplicateWasAccepted
    case reopenContainedStaleContent
    case lockDidNotRelease
}
