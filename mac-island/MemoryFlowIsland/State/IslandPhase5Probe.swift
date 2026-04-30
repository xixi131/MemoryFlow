import CoreGraphics
import Foundation

struct IslandPhase5ScenarioProbeRow: Codable, Equatable {
    let scenarioID: String
    let menuTitle: String
    let expectedVisualState: String
    let derivedVisualState: String
    let collapsedWidth: Double
    let primaryMode: String
    let presentationState: String
    let hasAnyActivitySource: Bool
    let showAnyActivity: Bool
    let showReminder: Bool
    let showTodoActivity: Bool
    let showMusicActivity: Bool
}

struct IslandPhase5InteractionProbeStep: Codable, Equatable {
    let intent: String
    let guardOutcome: String
    let primaryMode: String
    let presentationState: String
    let forceCompactMode: Bool
    let gestureState: String
    let visualState: String
}

struct IslandPhase5InteractionProbeRow: Codable, Equatable {
    let sequenceID: String
    let initialVisualState: String
    let steps: [IslandPhase5InteractionProbeStep]
}

struct IslandPhase5InteractionDemoProbeRow: Codable, Equatable {
    let controlID: String
    let menuTitle: String
    let intent: String
    let menuGuardOutcome: String
    let reducerGuardOutcome: String
    let menuFinalVisualState: String
    let reducerFinalVisualState: String
    let menuFinalPresentationState: String
    let reducerFinalPresentationState: String
    let menuFinalForceCompactMode: Bool
    let reducerFinalForceCompactMode: Bool
    let menuFinalGestureState: String
    let reducerFinalGestureState: String
    let matchesReducerSequence: Bool
}

enum IslandPhase5Probe {
    static func scenarioRows() -> [IslandPhase5ScenarioProbeRow] {
        IslandMockScenario.phase5Catalog.map { scenario in
            let derivedState = IslandDerivedState.derive(from: scenario.initialState)

            return IslandPhase5ScenarioProbeRow(
                scenarioID: scenario.id,
                menuTitle: scenario.menuTitle,
                expectedVisualState: scenario.expectedDerivedVisualState.rawValue,
                derivedVisualState: derivedState.visualState.rawValue,
                collapsedWidth: scalar(derivedState.collapsedWidth),
                primaryMode: scenario.initialState.primaryMode.rawValue,
                presentationState: scenario.initialState.presentationState.rawValue,
                hasAnyActivitySource: derivedState.hasAnyActivitySource,
                showAnyActivity: derivedState.showAnyActivity,
                showReminder: derivedState.showReminder,
                showTodoActivity: derivedState.showTodoActivity,
                showMusicActivity: derivedState.showMusicActivity
            )
        }
    }

    @discardableResult
    static func validateScenarioRows() throws -> [IslandPhase5ScenarioProbeRow] {
        let rows = scenarioRows()
        let ids = rows.map(\.scenarioID)

        guard Set(ids).count == IslandMockScenario.phase5Catalog.count else {
            throw IslandPhase5ProbeValidationError.duplicateScenarioIDs(ids)
        }

        guard rows.count == IslandMockScenario.phase5Catalog.count else {
            throw IslandPhase5ProbeValidationError.unexpectedScenarioCount(
                expected: IslandMockScenario.phase5Catalog.count,
                actual: rows.count
            )
        }

        let mismatchedVisualStates = rows.filter { $0.expectedVisualState != $0.derivedVisualState }
        guard mismatchedVisualStates.isEmpty else {
            throw IslandPhase5ProbeValidationError.unexpectedScenarioRows(mismatchedVisualStates)
        }

        let invalidWidths = rows.filter { $0.collapsedWidth <= 0 }
        guard invalidWidths.isEmpty else {
            throw IslandPhase5ProbeValidationError.invalidScenarioWidths(invalidWidths)
        }

        return rows
    }

    static func interactionRows() -> [IslandPhase5InteractionProbeRow] {
        interactionSequences.map { sequence in
            var currentState = sequence.initialState
            let initialDerivedState = IslandDerivedState.derive(from: currentState)
            let steps = sequence.intents.map { entry in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: entry.intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPhase5InteractionProbeStep(
                    intent: entry.label,
                    guardOutcome: result.reason.rawValue,
                    primaryMode: result.state.primaryMode.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    forceCompactMode: result.state.forceCompactMode,
                    gestureState: result.state.gestureState.rawValue,
                    visualState: derivedState.visualState.rawValue
                )
            }

            return IslandPhase5InteractionProbeRow(
                sequenceID: sequence.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    @discardableResult
    static func validateInteractionRows() throws -> [IslandPhase5InteractionProbeRow] {
        let rows = interactionRows()
        let ids = rows.map(\.sequenceID)

        guard Set(ids) == Set(interactionSequences.map(\.id)) else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionIDs(
                expected: interactionSequences.map(\.id),
                actual: ids
            )
        }

        let incompleteRows = rows.filter { $0.steps.isEmpty }
        guard incompleteRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.emptyInteractionRows(incompleteRows.map(\.sequenceID))
        }

        let missingVisualStates = rows.filter { row in
            row.steps.contains { $0.visualState.isEmpty }
        }
        guard missingVisualStates.isEmpty else {
            throw IslandPhase5ProbeValidationError.missingInteractionVisualState(
                missingVisualStates.map(\.sequenceID)
            )
        }

        return rows
    }

    static func interactionDemoRows() -> [IslandPhase5InteractionDemoProbeRow] {
        IslandPhase5InteractionDemoControl.allCases.map { control in
            let seedState = interactionDemoSeedState(for: control)
            var menuContainer = IslandPhase5PreviewStateContainer(initialState: seedState)
            let menuUpdate = menuContainer.dispatch(intent: control.intent)
            let reducerResult = IslandPresentationReducer.reduce(
                current: seedState,
                intent: control.intent
            )
            let reducerDerivedState = reducerResult.derivedState
            let menuCurrentState = menuUpdate.currentState
            let reducerCurrentState = reducerResult.state

            return IslandPhase5InteractionDemoProbeRow(
                controlID: control.rawValue,
                menuTitle: control.menuTitle,
                intent: describe(control.intent),
                menuGuardOutcome: menuUpdate.reducerResult.reason.rawValue,
                reducerGuardOutcome: reducerResult.reason.rawValue,
                menuFinalVisualState: menuUpdate.currentDerivedState.visualState.rawValue,
                reducerFinalVisualState: reducerDerivedState.visualState.rawValue,
                menuFinalPresentationState: menuCurrentState.presentationState.rawValue,
                reducerFinalPresentationState: reducerCurrentState.presentationState.rawValue,
                menuFinalForceCompactMode: menuCurrentState.forceCompactMode,
                reducerFinalForceCompactMode: reducerCurrentState.forceCompactMode,
                menuFinalGestureState: menuCurrentState.gestureState.rawValue,
                reducerFinalGestureState: reducerCurrentState.gestureState.rawValue,
                matchesReducerSequence: menuCurrentState == reducerCurrentState &&
                    menuUpdate.currentDerivedState == reducerDerivedState &&
                    menuUpdate.reducerResult.reason == reducerResult.reason
            )
        }
    }

    @discardableResult
    static func validateInteractionDemoRows() throws -> [IslandPhase5InteractionDemoProbeRow] {
        let rows = interactionDemoRows()
        let ids = rows.map(\.controlID)
        let expectedIDs = IslandPhase5InteractionDemoControl.allCases.map(\.rawValue)

        guard ids == expectedIDs else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionDemoIDs(
                expected: expectedIDs,
                actual: ids
            )
        }

        let mismatchedRows = rows.filter { $0.matchesReducerSequence == false }
        guard mismatchedRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionDemoRows(mismatchedRows)
        }

        return rows
    }

    private static let interactionSequences: [(id: String, initialState: IslandDomainState, intents: [(intent: IslandInteractionIntent, label: String)])] = [
        (
            id: "hover-enter-leave",
            initialState: .loggedInReviewCompact,
            intents: [
                (.hoverEnter, "hoverEnter"),
                (.hoverLeave, "hoverLeave")
            ]
        ),
        (
            id: "tap-expand-collapse",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.outsideCollapse, "outsideCollapse")
            ]
        ),
        (
            id: "pointer-compact-restore",
            initialState: .loggedInReviewActivityPlain,
            intents: [
                (.pointerSwipe(.right), "pointerSwipe(right)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.pointerSwipe(.left), "pointerSwipe(left)")
            ]
        ),
        (
            id: "trackpad-vertical-cycle",
            initialState: .loggedInReviewActivityPlain,
            intents: [
                (.trackpadSwipe(.up), "trackpadSwipe(up)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown),
                    "transitionComplete(trackpadGestureCooldown)"
                ),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.trackpadSwipe(.down), "trackpadSwipe(down)")
            ]
        ),
        (
            id: "horizontal-music-command",
            initialState: .musicActivity,
            intents: [
                (.horizontalMusicCommand(.previousTrack), "horizontalMusicCommand(previousTrack)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown),
                    "transitionComplete(trackpadGestureCooldown)"
                ),
                (.horizontalMusicCommand(.nextTrack), "horizontalMusicCommand(nextTrack)")
            ]
        ),
        (
            id: "reminder-due-open",
            initialState: .loggedInReviewCompact,
            intents: [
                (.reminderDue, "reminderDue")
            ]
        ),
        (
            id: "paused-music-timeout",
            initialState: .musicActivityWithAppFallback,
            intents: [
                (.pausedMusicTimeout, "pausedMusicTimeout")
            ]
        ),
        (
            id: "rapid-retargeting",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.outsideCollapse, "outsideCollapse"),
                (.tap, "tap")
            ]
        )
    ]

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private static func interactionDemoSeedState(
        for control: IslandPhase5InteractionDemoControl
    ) -> IslandDomainState {
        switch control {
        case .hoverEnter:
            return .loggedInReviewCompact
        case .hoverLeave:
            var state = IslandDomainState.loggedInReviewCompact
            state.isHovered = true
            return state
        case .tap:
            return .loggedInReviewCompact
        case .pointerSwipeLeft:
            return .loggedInReviewCompact
        case .pointerSwipeRight:
            return .loggedInReviewActivityPlain
        case .trackpadUp:
            return .loggedInReviewActivityPlain
        case .trackpadDown:
            return .loggedInReviewCompact
        case .horizontalPrevious, .horizontalNext:
            return .musicActivity
        }
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
        case .reminderDue:
            return "reminderDue"
        case .pausedMusicTimeout:
            return "pausedMusicTimeout"
        case let .mockScenarioSelect(scenarioID):
            return "mockScenarioSelect(\(scenarioID))"
        case let .transitionComplete(identifier):
            return "transitionComplete(\(identifier ?? "none"))"
        }
    }
}

enum IslandPhase5ProbeValidationError: Error, CustomStringConvertible {
    case duplicateScenarioIDs([String])
    case unexpectedScenarioCount(expected: Int, actual: Int)
    case unexpectedScenarioRows([IslandPhase5ScenarioProbeRow])
    case invalidScenarioWidths([IslandPhase5ScenarioProbeRow])
    case unexpectedInteractionIDs(expected: [String], actual: [String])
    case emptyInteractionRows([String])
    case missingInteractionVisualState([String])
    case unexpectedInteractionDemoIDs(expected: [String], actual: [String])
    case unexpectedInteractionDemoRows([IslandPhase5InteractionDemoProbeRow])

    var description: String {
        switch self {
        case let .duplicateScenarioIDs(ids):
            return "Duplicate Phase 5 scenario IDs: \(ids)"
        case let .unexpectedScenarioCount(expected, actual):
            return "Unexpected Phase 5 scenario count. Expected \(expected), actual \(actual)."
        case let .unexpectedScenarioRows(rows):
            return "Unexpected Phase 5 scenario rows: \(rows)"
        case let .invalidScenarioWidths(rows):
            return "Invalid Phase 5 scenario widths: \(rows)"
        case let .unexpectedInteractionIDs(expected, actual):
            return "Unexpected Phase 5 interaction IDs. Expected \(expected), actual \(actual)."
        case let .emptyInteractionRows(ids):
            return "Interaction rows must contain at least one step: \(ids)"
        case let .missingInteractionVisualState(ids):
            return "Interaction rows contain empty visual states: \(ids)"
        case let .unexpectedInteractionDemoIDs(expected, actual):
            return "Unexpected Phase 5 interaction demo IDs. Expected \(expected), actual \(actual)."
        case let .unexpectedInteractionDemoRows(rows):
            return "Unexpected Phase 5 interaction demo rows: \(rows)"
        }
    }
}
