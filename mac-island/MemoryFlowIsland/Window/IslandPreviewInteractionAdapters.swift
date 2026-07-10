import CoreGraphics
import Foundation

struct IslandPointerGestureAdapter: Equatable {
    static let maximumInteractiveTranslation: Double = 12

    private(set) var capturedPointerID: Int?
    private(set) var startX: Double?
    private(set) var currentX: Double?

    var isTracking: Bool {
        capturedPointerID != nil && startX != nil
    }

    /// Captures one non-button pointer stream. Button controls own their gestures and must
    /// never accidentally become island swipe drags.
    @discardableResult
    mutating func pointerDown(
        pointerID: Int,
        at x: Double,
        isButtonOrigin: Bool
    ) -> Bool {
        guard capturedPointerID == nil, isButtonOrigin == false else { return false }
        capturedPointerID = pointerID
        startX = x
        currentX = x
        return true
    }

    mutating func pointerDragged(pointerID: Int, to x: Double) {
        guard capturedPointerID == pointerID, startX != nil else { return }
        currentX = x
    }

    mutating func pointerUp(pointerID: Int, at x: Double) -> IslandInteractionIntent? {
        guard capturedPointerID == pointerID, let startX else { return nil }
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

    @discardableResult
    mutating func cancel(pointerID: Int? = nil) -> Bool {
        guard pointerID == nil || capturedPointerID == pointerID else { return false }
        let wasTracking = isTracking
        reset()
        return wasTracking
    }

    var interactiveTranslationX: Double {
        guard let startX, let currentX else { return 0 }
        return min(max((currentX - startX) * 0.35, -Self.maximumInteractiveTranslation), Self.maximumInteractiveTranslation)
    }

    private mutating func reset() {
        capturedPointerID = nil
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

struct IslandTrackpadVerticalMotionProbeRow: Equatable {
    let gesture: String
    let transitionKind: IslandTransitionKind
    let visualState: IslandVisualState
    let cooldownBlockedDuplicate: Bool
}

/// Covers the vertical gesture path as a reducer-plus-motion contract. The AppKit host
/// supplies the real event timestamps; this probe keeps the direction, cooldown, and
/// motion-plan mapping deterministic when physical trackpad capture is unavailable.
enum IslandTrackpadVerticalMotionProbe {
    static func run() throws -> [IslandTrackpadVerticalMotionProbeRow] {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        var adapter = IslandTrackpadWheelAdapter()
        var rows: [IslandTrackpadVerticalMotionProbeRow] = []

        guard adapter.registerEvent(deltaX: 0, deltaY: -69, timestamp: 0) == nil else {
            throw IslandTrackpadVerticalMotionProbeError.thresholdAcceptedTooEarly
        }

        adapter.reset()
        let first = try dispatch(deltaY: -70, timestamp: 0, adapter: &adapter, container: &container)
        rows.append(first)
        releaseCooldown(adapter: &adapter, container: &container)

        let second = try dispatch(deltaY: -70, timestamp: 0.4, adapter: &adapter, container: &container)
        rows.append(second)
        releaseCooldown(adapter: &adapter, container: &container)

        let third = try dispatch(deltaY: 70, timestamp: 0.8, adapter: &adapter, container: &container)
        rows.append(third)
        _ = container.dispatch(intent: .transitionComplete("expandedCollapseRecovery"))
        guard container.derivedState.visualState == .activityCollapsed else {
            throw IslandTrackpadVerticalMotionProbeError.expandedUpDidNotRecoverActivity
        }
        releaseCooldown(adapter: &adapter, container: &container)

        let fourth = try dispatch(deltaY: 70, timestamp: 1.2, adapter: &adapter, container: &container)
        rows.append(fourth)

        var resetAdapter = IslandTrackpadWheelAdapter()
        _ = resetAdapter.registerEvent(deltaX: 0, deltaY: 45, timestamp: 2)
        guard resetAdapter.registerEvent(deltaX: 0, deltaY: 45, timestamp: 2.161) == nil else {
            throw IslandTrackpadVerticalMotionProbeError.accumulationDidNotReset
        }

        guard rows.map(\.transitionKind) == [
            .compactToActivity,
            .activityToExpanded,
            .expandedToCompact,
            .activityToCompact
        ],
        rows.map(\.visualState) == [
            .activityCollapsed,
            .expandedApp,
            .compactCollapsed,
            .compactCollapsed
        ],
        rows.allSatisfy(\.cooldownBlockedDuplicate) else {
            throw IslandTrackpadVerticalMotionProbeError.invalidVerticalSequence
        }
        return rows
    }

    private static func dispatch(
        deltaY: Double,
        timestamp: TimeInterval,
        adapter: inout IslandTrackpadWheelAdapter,
        container: inout IslandPhase5PreviewStateContainer
    ) throws -> IslandTrackpadVerticalMotionProbeRow {
        guard let intent = adapter.registerEvent(deltaX: 0, deltaY: deltaY, timestamp: timestamp),
              case .trackpadSwipe = intent else {
            throw IslandTrackpadVerticalMotionProbeError.missingVerticalIntent
        }

        let previous = container.derivedState
        let update = container.dispatch(intent: intent)
        let plan = IslandMotionEngine.plan(
            previous: previous,
            next: update.currentDerivedState,
            reason: update.reducerResult.reason,
            presentation: .idle,
            reduceMotion: false
        )
        let duplicateBlocked = adapter.registerEvent(
            deltaX: 0,
            deltaY: deltaY,
            timestamp: timestamp + 0.05
        ) == nil
        return IslandTrackpadVerticalMotionProbeRow(
            gesture: deltaY > 0 ? "up" : "down",
            transitionKind: plan.transitionKind,
            visualState: update.currentDerivedState.visualState,
            cooldownBlockedDuplicate: duplicateBlocked
        )
    }

    private static func releaseCooldown(
        adapter: inout IslandTrackpadWheelAdapter,
        container: inout IslandPhase5PreviewStateContainer
    ) {
        adapter.clearCooldown()
        _ = container.dispatch(intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown))
        _ = container.dispatch(intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition))
    }
}

enum IslandTrackpadVerticalMotionProbeError: Error, CustomStringConvertible {
    case thresholdAcceptedTooEarly
    case missingVerticalIntent
    case expandedUpDidNotRecoverActivity
    case accumulationDidNotReset
    case invalidVerticalSequence

    var description: String {
        switch self {
        case .thresholdAcceptedTooEarly: return "A vertical delta below 70 triggered a trackpad transition."
        case .missingVerticalIntent: return "A 70-point vertical gesture did not emit a vertical trackpad intent."
        case .expandedUpDidNotRecoverActivity: return "Expanded swipe-up did not recover the activity presentation."
        case .accumulationDidNotReset: return "Trackpad accumulation survived the 160ms reset window."
        case .invalidVerticalSequence: return "Vertical gestures did not map to the expected motion sequence or cooldown guards."
        }
    }
}

/// Deterministic coverage for the capture and feedback rules used by the native host.
struct IslandPointerGestureFeedbackProbe: Equatable {
    let capturesSinglePointer: Bool
    let ignoresButtonDrag: Bool
    let ignoresMismatchedPointer: Bool
    let capsInteractiveTranslation: Bool
    let resolvesSwipeAndReleasesCapture: Bool
    let cancellationReleasesCapture: Bool

    var passes: Bool {
        capturesSinglePointer &&
            ignoresButtonDrag &&
            ignoresMismatchedPointer &&
            capsInteractiveTranslation &&
            resolvesSwipeAndReleasesCapture &&
            cancellationReleasesCapture
    }

    static func run() -> IslandPointerGestureFeedbackProbe {
        var adapter = IslandPointerGestureAdapter()
        let capturesSinglePointer = adapter.pointerDown(pointerID: 1, at: 0, isButtonOrigin: false) &&
            adapter.pointerDown(pointerID: 2, at: 0, isButtonOrigin: false) == false

        adapter.pointerDragged(pointerID: 2, to: 80)
        let ignoresMismatchedPointer = adapter.interactiveTranslationX == 0

        adapter.pointerDragged(pointerID: 1, to: 80)
        let capsInteractiveTranslation = adapter.interactiveTranslationX == IslandPointerGestureAdapter.maximumInteractiveTranslation
        let swipe = adapter.pointerUp(pointerID: 1, at: 80)
        let resolvesSwipeAndReleasesCapture = swipe == .pointerSwipe(.right) && adapter.isTracking == false

        let ignoresButtonDrag = adapter.pointerDown(pointerID: 3, at: 0, isButtonOrigin: true) == false &&
            adapter.isTracking == false

        _ = adapter.pointerDown(pointerID: 4, at: 0, isButtonOrigin: false)
        adapter.pointerDragged(pointerID: 4, to: 18)
        let cancellationReleasesCapture = adapter.cancel(pointerID: 4) &&
            adapter.isTracking == false &&
            adapter.interactiveTranslationX == 0

        return IslandPointerGestureFeedbackProbe(
            capturesSinglePointer: capturesSinglePointer,
            ignoresButtonDrag: ignoresButtonDrag,
            ignoresMismatchedPointer: ignoresMismatchedPointer,
            capsInteractiveTranslation: capsInteractiveTranslation,
            resolvesSwipeAndReleasesCapture: resolvesSwipeAndReleasesCapture,
            cancellationReleasesCapture: cancellationReleasesCapture
        )
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

        pointerAdapter.pointerDown(pointerID: 1, at: 0, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 1, to: 40)
        if let intent = pointerAdapter.pointerUp(pointerID: 1, at: 40) {
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

        pointerAdapter.pointerDown(pointerID: 2, at: 40, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 2, to: 0)
        if let intent = pointerAdapter.pointerUp(pointerID: 2, at: 0) {
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

        pointerAdapter.pointerDown(pointerID: 1, at: 100, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 1, to: 106)
        if let intent = pointerAdapter.pointerUp(pointerID: 1, at: 106) {
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
        case let .mockPlaybackStarted(snapshot):
            return "mockPlaybackStarted(\(snapshot.title))"
        case .musicStopped:
            return "musicStopped"
        case let .musicCommandRequested(command):
            return "musicCommandRequested(\(command.rawValue))"
        case .modeSwitchToggle:
            return "modeSwitchToggle"
        case .modeSwitchMutate:
            return "modeSwitchMutate"
        case let .reminderDue(key):
            return "reminderDue(\(key))"
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
