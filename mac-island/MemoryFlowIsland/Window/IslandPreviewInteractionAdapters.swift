import CoreGraphics
import Foundation

struct IslandPointerGestureAdapter: Equatable {
    static let maximumHorizontalExtensionPerEdge: Double = 12
    static let maximumDownwardExtension: Double = 8
    static let releaseEdgeTolerance: Double = 5

    private(set) var capturedPointerID: Int?
    private(set) var startLocation: CGPoint?
    private(set) var currentLocation: CGPoint?
    private(set) var interactionBounds: CGRect?

    var isTracking: Bool {
        capturedPointerID != nil && startLocation != nil && interactionBounds != nil
    }

    /// Captures one non-button pointer stream. Button controls own their gestures and must
    /// never accidentally become island swipe drags.
    @discardableResult
    mutating func pointerDown(
        pointerID: Int,
        at location: CGPoint,
        interactionBounds: CGRect,
        isButtonOrigin: Bool
    ) -> Bool {
        guard capturedPointerID == nil,
              isButtonOrigin == false,
              interactionBounds.isEmpty == false else { return false }
        capturedPointerID = pointerID
        startLocation = location
        currentLocation = location
        self.interactionBounds = interactionBounds
        return true
    }

    mutating func pointerDragged(pointerID: Int, to location: CGPoint) {
        guard capturedPointerID == pointerID, startLocation != nil else { return }
        currentLocation = location
    }

    mutating func pointerUp(pointerID: Int, at location: CGPoint) -> IslandInteractionIntent? {
        guard capturedPointerID == pointerID,
              let startLocation,
              let interactionBounds else { return nil }
        let deltaX = location.x - startLocation.x
        let deltaY = location.y - startLocation.y
        reset()

        if let swipeDirection = IslandInteractionThresholds.pointerSwipeDirection(for: deltaX),
           isEligibleSwipeRelease(
               location,
               direction: swipeDirection,
               interactionBounds: interactionBounds
           ) {
            return .pointerSwipe(swipeDirection)
        }

        if hypot(deltaX, deltaY) < IslandInteractionThresholds.tapMovementWindow {
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

    var stretchFeedback: IslandPointerStretchFeedback {
        guard let startLocation, let currentLocation else { return .zero }
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y
        return IslandPointerStretchFeedback(
            horizontalExtensionPerEdge: resistedExtension(
                for: abs(deltaX),
                maximum: Self.maximumHorizontalExtensionPerEdge
            ),
            downwardExtension: resistedExtension(
                for: max(-deltaY, 0),
                maximum: Self.maximumDownwardExtension
            )
        )
    }

    static func shouldExitHoverOnRelease(
        at location: CGPoint,
        interactionBounds: CGRect?
    ) -> Bool {
        interactionBounds.map { $0.contains(location) == false } ?? false
    }

    private mutating func reset() {
        capturedPointerID = nil
        startLocation = nil
        currentLocation = nil
        interactionBounds = nil
    }

    private func resistedExtension(for distance: Double, maximum: Double) -> Double {
        guard distance > 0 else { return 0 }
        return maximum * distance / (distance + 28)
    }

    private func releaseDistance(
        from location: CGPoint,
        to direction: IslandPointerSwipeDirection,
        edgeOf bounds: CGRect
    ) -> Double {
        let edgeX = direction == .left ? bounds.minX : bounds.maxX
        let nearestY = min(max(location.y, bounds.minY), bounds.maxY)
        return hypot(location.x - edgeX, location.y - nearestY)
    }

    private func isEligibleSwipeRelease(
        _ location: CGPoint,
        direction: IslandPointerSwipeDirection,
        interactionBounds: CGRect
    ) -> Bool {
        interactionBounds.contains(location) ||
            releaseDistance(
                from: location,
                to: direction,
                edgeOf: interactionBounds
            ) <= Self.releaseEdgeTolerance
    }
}

struct IslandPointerStretchFeedback: Equatable {
    static let zero = IslandPointerStretchFeedback(
        horizontalExtensionPerEdge: 0,
        downwardExtension: 0
    )

    let horizontalExtensionPerEdge: Double
    let downwardExtension: Double

    func interpolated(
        to target: IslandPointerStretchFeedback,
        progress: Double
    ) -> IslandPointerStretchFeedback {
        let t = min(max(progress, 0), 1)
        return IslandPointerStretchFeedback(
            horizontalExtensionPerEdge: horizontalExtensionPerEdge +
                ((target.horizontalExtensionPerEdge - horizontalExtensionPerEdge) * t),
            downwardExtension: downwardExtension +
                ((target.downwardExtension - downwardExtension) * t)
        )
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

enum IslandActivityLeadingIconHitRegion {
    private static let leadingInset: CGFloat = 14
    private static let trailingEdge: CGFloat = 58

    static func contains(
        _ screenPoint: CGPoint,
        in visibleFrame: CGRect?
    ) -> Bool {
        guard let visibleFrame,
              visibleFrame.contains(screenPoint) else { return false }
        let relativeX = screenPoint.x - visibleFrame.minX
        return relativeX >= leadingInset && relativeX <= trailingEdge
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
    let producesSymmetricHorizontalStretch: Bool
    let producesDiagonalStretch: Bool
    let preservesStableHoverBounds: Bool
    let exitsHoverDirectlyForOutsideRelease: Bool
    let resolvesInteriorSwipe: Bool
    let resolvesNearEdgeSwipe: Bool
    let rejectsFarEdgeRelease: Bool
    let cancellationReleasesCapture: Bool

    var passes: Bool {
        capturesSinglePointer &&
            ignoresButtonDrag &&
            ignoresMismatchedPointer &&
            producesSymmetricHorizontalStretch &&
            producesDiagonalStretch &&
            preservesStableHoverBounds &&
            exitsHoverDirectlyForOutsideRelease &&
            resolvesInteriorSwipe &&
            resolvesNearEdgeSwipe &&
            rejectsFarEdgeRelease &&
            cancellationReleasesCapture
    }

    static func run() -> IslandPointerGestureFeedbackProbe {
        var adapter = IslandPointerGestureAdapter()
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 40)
        let center = CGPoint(x: 50, y: 20)
        let capturesSinglePointer = adapter.pointerDown(
            pointerID: 1,
            at: center,
            interactionBounds: bounds,
            isButtonOrigin: false
        ) && adapter.pointerDown(
            pointerID: 2,
            at: center,
            interactionBounds: bounds,
            isButtonOrigin: false
        ) == false

        adapter.pointerDragged(pointerID: 2, to: CGPoint(x: 104, y: 20))
        let ignoresMismatchedPointer = adapter.stretchFeedback == .zero

        adapter.pointerDragged(pointerID: 1, to: CGPoint(x: 104, y: 20))
        let horizontalFeedback = adapter.stretchFeedback
        let producesSymmetricHorizontalStretch = horizontalFeedback.horizontalExtensionPerEdge > 0 &&
            horizontalFeedback.horizontalExtensionPerEdge < IslandPointerGestureAdapter.maximumHorizontalExtensionPerEdge &&
            horizontalFeedback.downwardExtension == 0
        adapter.pointerDragged(pointerID: 1, to: CGPoint(x: 104, y: 12))
        let diagonalFeedback = adapter.stretchFeedback
        let producesDiagonalStretch = diagonalFeedback.horizontalExtensionPerEdge > 0 &&
            diagonalFeedback.downwardExtension > 0 &&
            diagonalFeedback.downwardExtension < IslandPointerGestureAdapter.maximumDownwardExtension
        let preservesStableHoverBounds = adapter.interactionBounds == bounds
        let exitsHoverDirectlyForOutsideRelease = IslandPointerGestureAdapter.shouldExitHoverOnRelease(
            at: CGPoint(x: 104, y: 20),
            interactionBounds: adapter.interactionBounds
        )
        let swipe = adapter.pointerUp(pointerID: 1, at: CGPoint(x: 104, y: 20))
        let resolvesNearEdgeSwipe = swipe == .pointerSwipe(.right) && adapter.isTracking == false

        _ = adapter.pointerDown(
            pointerID: 6,
            at: CGPoint(x: 25, y: 20),
            interactionBounds: bounds,
            isButtonOrigin: false
        )
        adapter.pointerDragged(pointerID: 6, to: CGPoint(x: 60, y: 20))
        let resolvesInteriorSwipe = adapter.pointerUp(
            pointerID: 6,
            at: CGPoint(x: 60, y: 20)
        ) == .pointerSwipe(.right)

        let ignoresButtonDrag = adapter.pointerDown(
            pointerID: 3,
            at: center,
            interactionBounds: bounds,
            isButtonOrigin: true
        ) == false &&
            adapter.isTracking == false

        _ = adapter.pointerDown(
            pointerID: 4,
            at: center,
            interactionBounds: bounds,
            isButtonOrigin: false
        )
        adapter.pointerDragged(pointerID: 4, to: CGPoint(x: 130, y: 20))
        let rejectsFarEdgeRelease = adapter.pointerUp(
            pointerID: 4,
            at: CGPoint(x: 130, y: 20)
        ) == nil

        _ = adapter.pointerDown(
            pointerID: 5,
            at: center,
            interactionBounds: bounds,
            isButtonOrigin: false
        )
        adapter.pointerDragged(pointerID: 5, to: CGPoint(x: 68, y: 20))
        let cancellationReleasesCapture = adapter.cancel(pointerID: 5) &&
            adapter.isTracking == false &&
            adapter.stretchFeedback == .zero

        return IslandPointerGestureFeedbackProbe(
            capturesSinglePointer: capturesSinglePointer,
            ignoresButtonDrag: ignoresButtonDrag,
            ignoresMismatchedPointer: ignoresMismatchedPointer,
            producesSymmetricHorizontalStretch: producesSymmetricHorizontalStretch,
            producesDiagonalStretch: producesDiagonalStretch,
            preservesStableHoverBounds: preservesStableHoverBounds,
            exitsHoverDirectlyForOutsideRelease: exitsHoverDirectlyForOutsideRelease,
            resolvesInteriorSwipe: resolvesInteriorSwipe,
            resolvesNearEdgeSwipe: resolvesNearEdgeSwipe,
            rejectsFarEdgeRelease: rejectsFarEdgeRelease,
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
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 40)

        pointerAdapter.pointerDown(pointerID: 1, at: CGPoint(x: 50, y: 20), interactionBounds: bounds, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 1, to: CGPoint(x: 104, y: 20))
        if let intent = pointerAdapter.pointerUp(pointerID: 1, at: CGPoint(x: 104, y: 20)) {
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

        pointerAdapter.pointerDown(pointerID: 2, at: CGPoint(x: 50, y: 20), interactionBounds: bounds, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 2, to: CGPoint(x: -4, y: 20))
        if let intent = pointerAdapter.pointerUp(pointerID: 2, at: CGPoint(x: -4, y: 20)) {
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
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 40)

        pointerAdapter.pointerDown(pointerID: 1, at: CGPoint(x: 50, y: 20), interactionBounds: bounds, isButtonOrigin: false)
        pointerAdapter.pointerDragged(pointerID: 1, to: CGPoint(x: 56, y: 20))
        if let intent = pointerAdapter.pointerUp(pointerID: 1, at: CGPoint(x: 56, y: 20)) {
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
        case .loginRequiredRequested:
            return "loginRequiredRequested"
        case .loginRequiredDismissed:
            return "loginRequiredDismissed"
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
        let visibleFrame = CGRect(x: 100, y: 900, width: 240, height: 38)
        guard IslandActivityLeadingIconHitRegion.contains(
                  CGPoint(x: 125, y: 919),
                  in: visibleFrame
              ),
              IslandActivityLeadingIconHitRegion.contains(
                  CGPoint(x: 25, y: 919),
                  in: visibleFrame
              ) == false else {
            throw IslandModeSwitchProbeError.invalidLeadingIconHitRegion
        }

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
    case invalidLeadingIconHitRegion
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
