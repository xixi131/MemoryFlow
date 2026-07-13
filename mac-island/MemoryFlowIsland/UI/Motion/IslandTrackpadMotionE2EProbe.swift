import Foundation

/// Deterministic fallback evidence for the native trackpad path. The AppKit host owns
/// real `NSEvent` delivery; this probe connects the same adapter, reducer, motion plan,
/// and animation driver when a physical trackpad recording is unavailable.
struct IslandTrackpadMotionE2ERow: Codable, Equatable {
    let sequenceID: String
    let event: String
    let accepted: Bool
    let emittedIntent: String?
    let reducerReason: String?
    let transitionKind: String?
    let animationTransitionID: String?
    let finalVisualState: String
    let finalPrimaryMode: String
    let mockCommand: String?
    let notes: String
}

enum IslandTrackpadMotionE2EProbe {
    static func run() throws -> [IslandTrackpadMotionE2ERow] {
        var rows: [IslandTrackpadMotionE2ERow] = []
        try appendVerticalRoundTrip(to: &rows)
        try appendHorizontalMusicCommands(to: &rows)
        try appendIgnoredInputCases(to: &rows)

        guard rows.contains(where: { $0.sequenceID == "vertical-round-trip" && $0.transitionKind == "compactToActivity" }),
              rows.contains(where: { $0.sequenceID == "vertical-round-trip" && $0.transitionKind == "activityToExpanded" }),
              rows.contains(where: { $0.sequenceID == "vertical-round-trip" && $0.transitionKind == "expandedToCompact" }),
              rows.contains(where: { $0.sequenceID == "vertical-round-trip" && $0.transitionKind == "activityToCompact" }),
              rows.contains(where: { $0.sequenceID == "horizontal-music" && $0.mockCommand == "previousTrack" }),
              rows.contains(where: { $0.sequenceID == "horizontal-music" && $0.mockCommand == "nextTrack" }),
              rows.contains(where: { $0.sequenceID == "ignored-input" && $0.event == "equal-axis 70,70" && $0.emittedIntent == "horizontalMusicCommand(nextTrack)" }),
              rows.contains(where: { $0.sequenceID == "ignored-input" && $0.event == "cooldown duplicate" && $0.accepted == false }),
              rows.contains(where: { $0.sequenceID == "ignored-input" && $0.event == "reset gap 161ms" && $0.accepted == false }),
              rows.contains(where: { $0.sequenceID == "ignored-input" && $0.event == "app horizontal next" && $0.reducerReason == "intentIgnored" }) else {
            throw IslandTrackpadMotionE2EProbeError.missingCoverage(rows)
        }
        return rows
    }

    private static func appendVerticalRoundTrip(to rows: inout [IslandTrackpadMotionE2ERow]) throws {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        var adapter = IslandTrackpadWheelAdapter()
        try appendAcceptedEvent(
            sequenceID: "vertical-round-trip", event: "down 70 compact -> activity",
            deltaX: 0, deltaY: -70, timestamp: 0, transitionID: "trackpad-01-open",
            adapter: &adapter, container: &container, rows: &rows
        )
        releaseCooldown(adapter: &adapter, container: &container)
        try appendAcceptedEvent(
            sequenceID: "vertical-round-trip", event: "down 70 activity -> expanded",
            deltaX: 0, deltaY: -70, timestamp: 0.4, transitionID: "trackpad-02-expand",
            adapter: &adapter, container: &container, rows: &rows
        )
        releaseCooldown(adapter: &adapter, container: &container)
        try appendAcceptedEvent(
            sequenceID: "vertical-round-trip", event: "up 70 expanded -> activity",
            deltaX: 0, deltaY: 70, timestamp: 0.8, transitionID: "trackpad-03-recover",
            adapter: &adapter, container: &container, rows: &rows
        )
        _ = container.dispatch(intent: .transitionComplete("expandedCollapseRecovery"))
        releaseCooldown(adapter: &adapter, container: &container)
        try appendAcceptedEvent(
            sequenceID: "vertical-round-trip", event: "up 70 activity -> compact",
            deltaX: 0, deltaY: 70, timestamp: 1.2, transitionID: "trackpad-04-compact",
            adapter: &adapter, container: &container, rows: &rows
        )

        guard container.derivedState.visualState == .compactCollapsed else {
            throw IslandTrackpadMotionE2EProbeError.unexpectedFinalState("vertical", container.derivedState.visualState.rawValue)
        }
    }

    private static func appendHorizontalMusicCommands(to rows: inout [IslandTrackpadMotionE2ERow]) throws {
        var container = IslandPhase5PreviewStateContainer(initialState: .musicActivity)
        var adapter = IslandTrackpadWheelAdapter()
        try appendAcceptedEvent(
            sequenceID: "horizontal-music", event: "left 70 previous",
            deltaX: -70, deltaY: 0, timestamp: 0, transitionID: "trackpad-05-previous",
            adapter: &adapter, container: &container, rows: &rows
        )
        releaseCooldown(adapter: &adapter, container: &container)
        try appendAcceptedEvent(
            sequenceID: "horizontal-music", event: "right 70 next",
            deltaX: 70, deltaY: 0, timestamp: 0.4, transitionID: "trackpad-06-next",
            adapter: &adapter, container: &container, rows: &rows
        )

        guard container.derivedState.visualState == .activityCollapsed,
              container.domainState.primaryMode == .music else {
            throw IslandTrackpadMotionE2EProbeError.unexpectedFinalState("music", container.derivedState.visualState.rawValue)
        }
    }

    private static func appendIgnoredInputCases(to rows: inout [IslandTrackpadMotionE2ERow]) throws {
        var adapter = IslandTrackpadWheelAdapter()
        var container = IslandPhase5PreviewStateContainer(initialState: .musicActivity)
        appendEvent(
            sequenceID: "ignored-input", event: "below threshold 69", deltaX: 0, deltaY: 69,
            timestamp: 0, transitionID: "ignored-threshold", adapter: &adapter, container: &container,
            rows: &rows, note: "The 70-point threshold rejects this event."
        )
        adapter.reset()
        appendEvent(
            sequenceID: "ignored-input", event: "equal-axis 70,70", deltaX: 70, deltaY: 70,
            timestamp: 0.2, transitionID: "axis-horizontal", adapter: &adapter, container: &container,
            rows: &rows, note: "Equal axes select horizontal handling by contract."
        )
        releaseCooldown(adapter: &adapter, container: &container)
        appendEvent(
            sequenceID: "ignored-input", event: "vertical dominance 20,70", deltaX: 20, deltaY: 70,
            timestamp: 0.6, transitionID: "axis-vertical", adapter: &adapter, container: &container,
            rows: &rows, note: "The larger vertical axis controls presentation."
        )

        var cooldownAdapter = IslandTrackpadWheelAdapter()
        var cooldownContainer = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        appendEvent(
            sequenceID: "ignored-input", event: "cooldown first", deltaX: 0, deltaY: -70,
            timestamp: 1, transitionID: "cooldown-first", adapter: &cooldownAdapter, container: &cooldownContainer,
            rows: &rows, note: "Starts the 320ms gesture cooldown."
        )
        appendEvent(
            sequenceID: "ignored-input", event: "cooldown duplicate", deltaX: 0, deltaY: -70,
            timestamp: 1.05, transitionID: "cooldown-duplicate", adapter: &cooldownAdapter, container: &cooldownContainer,
            rows: &rows, note: "Rejected during the active cooldown."
        )

        var resetAdapter = IslandTrackpadWheelAdapter()
        var resetContainer = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        appendEvent(
            sequenceID: "ignored-input", event: "reset seed 45", deltaX: 0, deltaY: 45,
            timestamp: 2, transitionID: "reset-seed", adapter: &resetAdapter, container: &resetContainer,
            rows: &rows, note: "Below threshold accumulation starts."
        )
        appendEvent(
            sequenceID: "ignored-input", event: "reset gap 161ms", deltaX: 0, deltaY: 45,
            timestamp: 2.161, transitionID: "reset-gap", adapter: &resetAdapter, container: &resetContainer,
            rows: &rows, note: "The 160ms reset clears the preceding accumulation."
        )

        var appAdapter = IslandTrackpadWheelAdapter()
        var appContainer = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewActivity)
        appendEvent(
            sequenceID: "ignored-input", event: "app horizontal next", deltaX: 70, deltaY: 0,
            timestamp: 3, transitionID: "app-horizontal", adapter: &appAdapter, container: &appContainer,
            rows: &rows, note: "Horizontal mock commands are accepted only in music mode."
        )
    }

    private static func appendAcceptedEvent(
        sequenceID: String, event: String, deltaX: Double, deltaY: Double, timestamp: TimeInterval,
        transitionID: String, adapter: inout IslandTrackpadWheelAdapter,
        container: inout IslandPhase5PreviewStateContainer,
        rows: inout [IslandTrackpadMotionE2ERow]
    ) throws {
        appendEvent(sequenceID: sequenceID, event: event, deltaX: deltaX, deltaY: deltaY, timestamp: timestamp,
                    transitionID: transitionID, adapter: &adapter, container: &container,
                    rows: &rows, note: "Accepted trackpad gesture through adapter, reducer, motion plan, and driver.")
        guard rows.last?.accepted == true else {
            throw IslandTrackpadMotionE2EProbeError.missingAcceptedGesture(event)
        }
    }

    private static func appendEvent(
        sequenceID: String, event: String, deltaX: Double, deltaY: Double, timestamp: TimeInterval,
        transitionID: String, adapter: inout IslandTrackpadWheelAdapter,
        container: inout IslandPhase5PreviewStateContainer,
        rows: inout [IslandTrackpadMotionE2ERow], note: String
    ) {
        guard let intent = adapter.registerEvent(deltaX: deltaX, deltaY: deltaY, timestamp: timestamp) else {
            rows.append(.init(sequenceID: sequenceID, event: event, accepted: false, emittedIntent: nil,
                              reducerReason: nil, transitionKind: nil, animationTransitionID: nil,
                              finalVisualState: container.derivedState.visualState.rawValue,
                              finalPrimaryMode: container.domainState.primaryMode.rawValue, mockCommand: nil, notes: note))
            return
        }

        let update = container.dispatch(intent: intent)
        let plan = IslandMotionEngine.plan(previous: update.previousDerivedState, next: update.currentDerivedState,
                                           reason: update.reducerResult.reason, presentation: .idle, reduceMotion: false)
        let command = update.reducerResult.metadata.mockMusicCommand
        if let command { container.advanceMockMusicTrack(command) }
        rows.append(.init(sequenceID: sequenceID, event: event, accepted: true, emittedIntent: describe(intent),
                          reducerReason: update.reducerResult.reason.rawValue, transitionKind: plan.transitionKind.rawValue,
                          animationTransitionID: transitionID, finalVisualState: container.derivedState.visualState.rawValue,
                          finalPrimaryMode: container.domainState.primaryMode.rawValue, mockCommand: command?.rawValue, notes: note))
    }

    private static func releaseCooldown(adapter: inout IslandTrackpadWheelAdapter, container: inout IslandPhase5PreviewStateContainer) {
        adapter.clearCooldown()
        _ = container.dispatch(intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown))
        _ = container.dispatch(intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition))
    }

    private static func describe(_ intent: IslandInteractionIntent) -> String {
        switch intent {
        case let .trackpadSwipe(direction): return "trackpadSwipe(\(direction.rawValue))"
        case let .horizontalMusicCommand(command): return "horizontalMusicCommand(\(command.rawValue))"
        default: return "other"
        }
    }
}

enum IslandTrackpadMotionE2EProbeError: Error, CustomStringConvertible {
    case missingAcceptedGesture(String)
    case unexpectedFinalState(String, String)
    case missingCoverage([IslandTrackpadMotionE2ERow])

    var description: String {
        switch self {
        case let .missingAcceptedGesture(event): return "Expected trackpad event was not accepted: \(event)."
        case let .unexpectedFinalState(sequence, state): return "Unexpected final state for \(sequence): \(state)."
        case let .missingCoverage(rows):
            let events = rows.map { row in
                "\(row.event)=\(row.emittedIntent ?? "nil")/\(row.reducerReason ?? "nil")/\(row.transitionKind ?? "nil")"
            }.joined(separator: ", ")
            return "Trackpad E2E probe did not cover all required accepted and ignored paths: \(events)"
        }
    }
}
