import AppKit
import Foundation

struct IslandSizingMatrixRow: Codable, Equatable {
    struct ScalarSize: Codable, Equatable {
        let width: Double
        let height: Double
    }

    struct ScalarRect: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    let displayScenario: String
    let attachmentKind: String
    let state: String
    let visualScale: Double
    let horizontalScale: Double
    let visibleSize: ScalarSize
    let shadowSize: ScalarSize
    let contentSize: ScalarSize
    let visibleFrame: ScalarRect
    let shadowFrame: ScalarRect
    let contentFrame: ScalarRect
    let hitTestFrame: ScalarRect
    let diagnostics: String
}

enum IslandSizingMatrixProbe {
    static func generateMatrix() -> [IslandSizingMatrixRow] {
        let layoutEngine = NotchLayoutEngine()
        let states: [IslandVisualState] = [
            .compactCollapsed,
            .activityCollapsed,
            .expandedMusic,
            .expandedApp
        ]

        return syntheticDisplays().flatMap { scenario in
            let attachmentMetrics = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
            return states.map { state in
                let widthConstraints = IslandWidthConstraints(
                    baseBodyWidth: IslandVisualTokens.compact.previewWidth * attachmentMetrics.horizontalVisualScale,
                    maximumVisibleWidth: attachmentMetrics.availableTopWidth,
                    contentWidthRequirement: state.previewContentWidthRequirement
                )
                let result = IslandWindowSizingEngine.resolve(
                    state: state,
                    attachmentMetrics: attachmentMetrics,
                    widthConstraints: widthConstraints
                )

                return IslandSizingMatrixRow(
                    displayScenario: scenario.name,
                    attachmentKind: String(describing: attachmentMetrics.kind),
                    state: state.rawValue,
                    visualScale: scalar(result.diagnostics.visualScale),
                    horizontalScale: scalar(result.diagnostics.horizontalScale),
                    visibleSize: scalar(result.visibleSize),
                    shadowSize: scalar(result.shadowSize),
                    contentSize: scalar(result.contentSize),
                    visibleFrame: scalar(result.visibleFrame),
                    shadowFrame: scalar(result.shadowFrame),
                    contentFrame: scalar(result.contentFrame),
                    hitTestFrame: scalar(result.hitTestFrame),
                    diagnostics: result.debugSummary
                )
            }
        }
    }

    static func jsonData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(generateMatrix())
    }

    private static func syntheticDisplays() -> [(name: String, metrics: ScreenMetrics)] {
        let notchFrame = CGRect(x: 651, y: 950, width: 210, height: 32)
        let notchMetrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            notchFrame: notchFrame,
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 1)
        )
        let flatTopMetrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 876),
            safeAreaInsets: NSEdgeInsetsZero,
            notchFrame: nil,
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 2)
        )

        return [
            (name: "notch-display", metrics: notchMetrics),
            (name: "flat-top-display", metrics: flatTopMetrics)
        ]
    }

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private static func scalar(_ size: CGSize) -> IslandSizingMatrixRow.ScalarSize {
        IslandSizingMatrixRow.ScalarSize(
            width: scalar(size.width),
            height: scalar(size.height)
        )
    }

    private static func scalar(_ rect: CGRect) -> IslandSizingMatrixRow.ScalarRect {
        IslandSizingMatrixRow.ScalarRect(
            x: scalar(rect.minX),
            y: scalar(rect.minY),
            width: scalar(rect.width),
            height: scalar(rect.height)
        )
    }
}
