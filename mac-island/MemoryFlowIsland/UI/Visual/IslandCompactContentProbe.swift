import CoreGraphics
import Foundation

struct IslandCompactContentProbeRow: Equatable {
    let phase: String
    let contentKind: IslandPreviewContent.Kind
    let bodyWidth: CGFloat
    let visibleWidth: CGFloat
    let visibleHeight: CGFloat
    let isExpanded: Bool
    let contentFitsVisibleFrame: Bool
}

enum IslandCompactContentProbe {
    static func rows() -> [IslandCompactContentProbeRow] {
        let loggedOut = IslandDerivedState.derive(from: .loggedOutCompact)
        let loggedIn = IslandDerivedState.derive(from: .loggedInReviewCompact)
        let greeting = IslandDerivedState.derive(from: .mockGreetingCompact)

        return [
            row(phase: "logged-out", derived: loggedOut),
            row(phase: "idle", derived: loggedIn),
            row(phase: "greeting-enter", derived: greeting),
            row(phase: "greeting-visible", derived: greeting),
            row(phase: "greeting-exit", derived: loggedIn)
        ]
    }

    static func validate() throws {
        let rows = rows()
        let loggedIn = IslandDerivedState.derive(from: .loggedInReviewCompact)
        let todoCompact = IslandDerivedState.derive(from: .loggedInTodoCompact)
        let expectedPhases = [
            "logged-out", "idle", "greeting-enter", "greeting-visible", "greeting-exit"
        ]
        guard rows.map(\.phase) == expectedPhases else {
            throw IslandCompactContentProbeError.invalidCycle(rows.map(\.phase))
        }

        let expectedWidths: [String: CGFloat] = [
            "logged-out": IslandVisualTokens.compactSignedOutWidth,
            "idle": IslandVisualTokens.compact.previewWidth - 40,
            "greeting-enter": IslandVisualTokens.compactGreetingMaxWidth,
            "greeting-visible": IslandVisualTokens.compactGreetingMaxWidth,
            "greeting-exit": IslandVisualTokens.compact.previewWidth - 40
        ]
        guard rows.allSatisfy({ row in
            row.isExpanded == false &&
                row.visibleHeight > 0 &&
                row.contentFitsVisibleFrame &&
                row.bodyWidth == expectedWidths[row.phase]
        }) else {
            throw IslandCompactContentProbeError.invalidCompactContract(rows)
        }

        guard rows[0].contentKind == .signedOutCompact,
              rows[1].contentKind == .reviewCompact,
              rows[2].contentKind == .greetingCompact,
              rows[3].contentKind == .greetingCompact,
              rows[4].contentKind == .reviewCompact else {
            throw IslandCompactContentProbeError.invalidContentCycle(rows.map(\.contentKind))
        }

        guard todoCompact.visualState == .compactCollapsed,
              todoCompact.previewContent.kind == .todoCompact,
              todoCompact.collapsedWidth == loggedIn.collapsedWidth else {
            throw IslandCompactContentProbeError.todoCompactDidNotReuseStandardWidth
        }
    }

    private static func row(
        phase: String,
        derived: IslandDerivedState
    ) -> IslandCompactContentProbeRow {
        let snapshot = IslandCompactContentLayout.snapshot(
            for: derived.visualState,
            visualScale: 1,
            horizontalScale: 1,
            widthConstraints: derived.widthConstraints
        )
        let bodyWidth = snapshot.metrics.width
        let requiredWidth = derived.collapsedWidth

        return IslandCompactContentProbeRow(
            phase: phase,
            contentKind: derived.previewContent.kind,
            bodyWidth: bodyWidth,
            visibleWidth: snapshot.visibleFrame.width,
            visibleHeight: snapshot.visibleFrame.height,
            isExpanded: derived.visualState.isExpanded,
            contentFitsVisibleFrame: bodyWidth >= requiredWidth &&
                snapshot.visibleFrame.width >= bodyWidth &&
                snapshot.visibleFrame.height >= snapshot.metrics.height
        )
    }
}

enum IslandCompactContentProbeError: Error {
    case invalidCycle([String])
    case invalidCompactContract([IslandCompactContentProbeRow])
    case invalidContentCycle([IslandPreviewContent.Kind])
    case todoCompactDidNotReuseStandardWidth
}
