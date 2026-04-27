import CoreGraphics
import Foundation

struct IslandPresentationReducerProbeRow: Codable, Equatable {
    let scenarioID: String
    let intent: String
    let reason: String
    let stateChanged: Bool
    let visualStateBefore: String
    let visualStateAfter: String
    let collapsedWidthBefore: Double
    let collapsedWidthAfter: Double
}

enum IslandPresentationReducerProbe {
    static func noOpRows() -> [IslandPresentationReducerProbeRow] {
        representativeCases.map { entry in
            let beforeDerivedState = IslandDerivedState.derive(from: entry.state)
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let afterDerivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: beforeDerivedState.visualState.rawValue,
                visualStateAfter: afterDerivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(beforeDerivedState.collapsedWidth),
                collapsedWidthAfter: scalar(afterDerivedState.collapsedWidth)
            )
        }
    }

    static func compactDerivationRows() -> [IslandPresentationReducerProbeRow] {
        compactRepresentativeCases.map { entry in
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let derivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: derivedState.visualState.rawValue,
                visualStateAfter: derivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(derivedState.collapsedWidth),
                collapsedWidthAfter: scalar(derivedState.collapsedWidth)
            )
        }
    }

    @discardableResult
    static func validateNoOpRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = noOpRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-outside-collapse",
                intent: "outsideCollapse",
                reason: "intentIgnored",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-pointer-restore",
                intent: "pointerSwipe(left)",
                reason: "intentIgnored",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "app-mode-horizontal-music-command",
                intent: "horizontalMusicCommand(nextTrack)",
                reason: "intentIgnored",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "unknown-mock-scenario",
                intent: "mockScenarioSelect(missing-scenario)",
                reason: "intentIgnored",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 230,
                collapsedWidthAfter: 230
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "idle-transition-complete",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                stateChanged: false,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateCompactDerivationRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = compactDerivationRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-compact-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-in-review-compact-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    private static let representativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "logged-out-outside-collapse",
            state: .loggedOutCompact,
            intent: .outsideCollapse,
            intentDescription: "outsideCollapse"
        ),
        (
            id: "logged-out-pointer-restore",
            state: .loggedOutCompact,
            intent: .pointerSwipe(.left),
            intentDescription: "pointerSwipe(left)"
        ),
        (
            id: "app-mode-horizontal-music-command",
            state: .loggedInReviewCompact,
            intent: .horizontalMusicCommand(.nextTrack),
            intentDescription: "horizontalMusicCommand(nextTrack)"
        ),
        (
            id: "unknown-mock-scenario",
            state: .loggedInTodoCompact,
            intent: .mockScenarioSelect("missing-scenario"),
            intentDescription: "mockScenarioSelect(missing-scenario)"
        ),
        (
            id: "idle-transition-complete",
            state: .musicActivity,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static let compactRepresentativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "logged-out-compact-derivation",
            state: .loggedOutCompact,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        ),
        (
            id: "logged-in-review-compact-derivation",
            state: .loggedInReviewCompact,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}

enum IslandPresentationReducerProbeValidationError: Error, CustomStringConvertible {
    case unexpectedRows(
        expected: [IslandPresentationReducerProbeRow],
        actual: [IslandPresentationReducerProbeRow]
    )

    var description: String {
        switch self {
        case let .unexpectedRows(expected, actual):
            return """
            Unexpected presentation-reducer probe rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        }
    }
}
