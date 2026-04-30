import CoreGraphics
import Foundation

struct IslandDerivedStateProbeRow: Codable, Equatable {
    let scenarioID: String
    let visualState: String
    let collapsedWidth: Double
    let collapsedCornerRadius: Double
    let collapsedCornerSmoothness: Double
    let showsMusicActivity: Bool
    let showsReviewActivity: Bool
    let showsTodoActivity: Bool
    let showsReminder: Bool
    let showsAppActivity: Bool
    let showsAnyActivity: Bool
    let contentExtensionWidth: Double
}

struct IslandMockScenarioMatrixRow: Codable, Equatable {
    let scenarioID: String
    let menuTitle: String
    let expectedVisualState: String
    let visualState: String
    let primaryMode: String
    let presentationState: String
    let collapsedWidth: Double
    let showsMusicActivity: Bool
    let showsReviewActivity: Bool
    let showsTodoActivity: Bool
    let showsReminder: Bool
    let showsAppActivity: Bool
    let showsAnyActivity: Bool
}

enum IslandDerivedStateProbe {
    static func representativeRows() -> [IslandDerivedStateProbeRow] {
        representativeStates.map { scenarioID, state in
            row(for: state, scenarioID: scenarioID)
        }
    }

    static func scenarioMatrixRows() -> [IslandMockScenarioMatrixRow] {
        IslandMockScenario.phase5Catalog.map { scenario in
            let derivedState = IslandDerivedState.derive(from: scenario.initialState)
            return IslandMockScenarioMatrixRow(
                scenarioID: scenario.id,
                menuTitle: scenario.menuTitle,
                expectedVisualState: scenario.expectedDerivedVisualState.rawValue,
                visualState: derivedState.visualState.rawValue,
                primaryMode: scenario.initialState.primaryMode.rawValue,
                presentationState: scenario.initialState.presentationState.rawValue,
                collapsedWidth: scalar(derivedState.collapsedWidth),
                showsMusicActivity: derivedState.showMusicActivity,
                showsReviewActivity: derivedState.showReviewActivity,
                showsTodoActivity: derivedState.showTodoActivity,
                showsReminder: derivedState.showReminder,
                showsAppActivity: derivedState.showAppActivity,
                showsAnyActivity: derivedState.showAnyActivity
            )
        }
    }

    @discardableResult
    static func validateRepresentativeStates() throws -> [IslandDerivedStateProbeRow] {
        let rows = representativeRows()
        let expectedRows = [
            IslandDerivedStateProbeRow(
                scenarioID: "logged-out-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 180,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-review-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 160,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-review-activity",
                visualState: "activityCollapsed",
                collapsedWidth: 240,
                collapsedCornerRadius: 40,
                collapsedCornerSmoothness: 2.8,
                showsMusicActivity: false,
                showsReviewActivity: true,
                showsTodoActivity: false,
                showsReminder: true,
                showsAppActivity: true,
                showsAnyActivity: true,
                contentExtensionWidth: 108
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-todo-activity",
                visualState: "activityCollapsed",
                collapsedWidth: 240,
                collapsedCornerRadius: 40,
                collapsedCornerSmoothness: 2.8,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: true,
                showsReminder: false,
                showsAppActivity: true,
                showsAnyActivity: true,
                contentExtensionWidth: 108
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-todo-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 230,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "music-activity",
                visualState: "activityCollapsed",
                collapsedWidth: 240,
                collapsedCornerRadius: 40,
                collapsedCornerSmoothness: 2.8,
                showsMusicActivity: true,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: true,
                contentExtensionWidth: 108
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "music-compact-fallback",
                visualState: "compactCollapsed",
                collapsedWidth: 160,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            )
        ]

        guard rows == expectedRows else {
            throw ProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateScenarioMatrixRows() throws -> [IslandMockScenarioMatrixRow] {
        let rows = scenarioMatrixRows()
        let expectedIDs = IslandMockScenario.phase5Catalog.map(\.id)
        let actualIDs = rows.map(\.scenarioID)

        guard actualIDs.count == expectedIDs.count,
              Set(actualIDs) == Set(expectedIDs),
              Set(actualIDs).count == expectedIDs.count else {
            throw ProbeValidationError.unexpectedScenarioIDs(
                expected: expectedIDs,
                actual: actualIDs
            )
        }

        let supportedVisualStates = Set(IslandVisualState.allCases.map(\.rawValue))

        for row in rows {
            guard row.visualState == row.expectedVisualState else {
                throw ProbeValidationError.scenarioVisualStateMismatch(
                    scenarioID: row.scenarioID,
                    expected: row.expectedVisualState,
                    actual: row.visualState
                )
            }

            guard supportedVisualStates.contains(row.visualState) else {
                throw ProbeValidationError.unsupportedVisualState(
                    scenarioID: row.scenarioID,
                    visualState: row.visualState
                )
            }

            guard row.collapsedWidth > 0 else {
                throw ProbeValidationError.missingCollapsedWidth(
                    scenarioID: row.scenarioID,
                    collapsedWidth: row.collapsedWidth
                )
            }
        }

        return rows
    }

    static func scenarioMatrixJSONData(prettyPrinted: Bool = true) throws -> Data {
        try encode(validateScenarioMatrixRows(), prettyPrinted: prettyPrinted)
    }

    @discardableResult
    static func writeScenarioMatrixEvidence(outputDirectory: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let outputURL = outputDirectory.appendingPathComponent("scenario-matrix.json")
        try scenarioMatrixJSONData().write(to: outputURL)
        return outputURL
    }

    private static let representativeStates: [(String, IslandDomainState)] = [
        ("logged-out-compact", .loggedOutCompact),
        ("logged-in-review-compact", .loggedInReviewCompact),
        ("logged-in-review-activity", .loggedInReviewActivity),
        ("logged-in-todo-activity", .loggedInTodoActivity),
        ("logged-in-todo-compact", .loggedInTodoCompact),
        ("music-activity", .musicActivity),
        ("music-compact-fallback", .musicCompactFallback)
    ]

    private static func row(for state: IslandDomainState, scenarioID: String) -> IslandDerivedStateProbeRow {
        let derivedState = IslandDerivedState.derive(from: state)
        return IslandDerivedStateProbeRow(
            scenarioID: scenarioID,
            visualState: derivedState.visualState.rawValue,
            collapsedWidth: scalar(derivedState.collapsedWidth),
            collapsedCornerRadius: scalar(derivedState.collapsedCornerRadius),
            collapsedCornerSmoothness: scalar(derivedState.collapsedCornerSmoothness),
            showsMusicActivity: derivedState.showMusicActivity,
            showsReviewActivity: derivedState.showReviewActivity,
            showsTodoActivity: derivedState.showTodoActivity,
            showsReminder: derivedState.showReminder,
            showsAppActivity: derivedState.showAppActivity,
            showsAnyActivity: derivedState.showAnyActivity,
            contentExtensionWidth: scalar(
                derivedState.contentWidthRequirement.requiredExtensionWidth
            )
        )
    }

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private static func encode<T: Encodable>(_ value: T, prettyPrinted: Bool) throws -> Data {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(value)
    }
}

enum ProbeValidationError: Error, CustomStringConvertible {
    case unexpectedRows(expected: [IslandDerivedStateProbeRow], actual: [IslandDerivedStateProbeRow])
    case unexpectedScenarioIDs(expected: [String], actual: [String])
    case scenarioVisualStateMismatch(scenarioID: String, expected: String, actual: String)
    case unsupportedVisualState(scenarioID: String, visualState: String)
    case missingCollapsedWidth(scenarioID: String, collapsedWidth: Double)

    var description: String {
        switch self {
        case let .unexpectedRows(expected, actual):
            return """
            Unexpected derived-state probe rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        case let .unexpectedScenarioIDs(expected, actual):
            return """
            Unexpected mock scenario IDs.
            Expected: \(expected)
            Actual: \(actual)
            """
        case let .scenarioVisualStateMismatch(scenarioID, expected, actual):
            return """
            Scenario visual-state mismatch for \(scenarioID).
            Expected: \(expected)
            Actual: \(actual)
            """
        case let .unsupportedVisualState(scenarioID, visualState):
            return """
            Unsupported visual state \(visualState) in scenario \(scenarioID).
            """
        case let .missingCollapsedWidth(scenarioID, collapsedWidth):
            return """
            Missing or invalid collapsed width \(collapsedWidth) in scenario \(scenarioID).
            """
        }
    }
}
