import Foundation

struct IslandPhase5ScenarioSelectionProbeRow: Codable, Equatable {
    let scenarioID: String
    let visualState: String
    let presentationState: String
}

@main
struct GenerateIslandPhase5Evidence {
    static func main() throws {
        let outputDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evidence/mac-island-phase5", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )

        let scenarioRows = try IslandPhase5Probe.validateScenarioRows()
        let interactionRows = try IslandPhase5Probe.validateInteractionRows()
        let interactionDemoRows = try IslandPhase5Probe.validateInteractionDemoRows()
        let previewInteractionRows = IslandPreviewInteractionProbe.generateRows()
        let scenarioSelectionRows = try validateScenarioSelectionRows()

        try writeJSON(
            scenarioRows,
            to: outputDirectoryURL.appendingPathComponent("scenario-matrix.json")
        )
        try writeJSON(
            interactionRows,
            to: outputDirectoryURL.appendingPathComponent("interaction-sequences.json")
        )
        try writeJSON(
            interactionDemoRows,
            to: outputDirectoryURL.appendingPathComponent("interaction-demo-menu-probe.json")
        )
        try writeJSON(
            previewInteractionRows,
            to: outputDirectoryURL.appendingPathComponent("preview-interaction-probe.json")
        )
        try writeJSON(
            scenarioSelectionRows,
            to: outputDirectoryURL.appendingPathComponent("scenario-selection-probe.json")
        )
    }

    private static func validateScenarioSelectionRows() throws -> [IslandPhase5ScenarioSelectionProbeRow] {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        let requiredScenarioIDs = [
            "logged-out-compact",
            "review-activity",
            "todo-activity",
            "music-activity",
            "expanded-music",
            "expanded-app"
        ]

        let rows = requiredScenarioIDs.map { scenarioID in
            let update = container.dispatch(intent: .mockScenarioSelect(scenarioID))
            return IslandPhase5ScenarioSelectionProbeRow(
                scenarioID: scenarioID,
                visualState: update.currentDerivedState.visualState.rawValue,
                presentationState: update.currentState.presentationState.rawValue
            )
        }

        let expectedVisualStates = [
            "logged-out-compact": "compactCollapsed",
            "review-activity": "activityCollapsed",
            "todo-activity": "activityCollapsed",
            "music-activity": "activityCollapsed",
            "expanded-music": "expandedMusic",
            "expanded-app": "expandedApp"
        ]

        guard rows.allSatisfy({ expectedVisualStates[$0.scenarioID] == $0.visualState }) else {
            throw ScenarioSelectionProbeError.unexpectedRows(rows)
        }

        return rows
    }

    private static func writeJSON<T: Encodable>(
        _ value: T,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

enum ScenarioSelectionProbeError: Error, CustomStringConvertible {
    case unexpectedRows([IslandPhase5ScenarioSelectionProbeRow])

    var description: String {
        switch self {
        case let .unexpectedRows(rows):
            return "Unexpected Phase 5 scenario-selection rows: \(rows)"
        }
    }
}
