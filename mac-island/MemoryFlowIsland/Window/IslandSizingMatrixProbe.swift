import AppKit
import CoreGraphics
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

struct IslandShadowEvidenceRow: Codable, Equatable {
    struct ShadowOutsets: Codable, Equatable {
        let horizontal: Double
        let bottom: Double
    }

    struct EdgeAlphaMax: Codable, Equatable {
        static let zero = EdgeAlphaMax(left: 0, right: 0, bottom: 0)

        let left: Double
        let right: Double
        let bottom: Double
    }

    let displayScenario: String
    let state: String
    let imagePath: String
    let visualScale: Double
    let horizontalScale: Double
    let visibleSize: IslandSizingMatrixRow.ScalarSize
    let shadowSize: IslandSizingMatrixRow.ScalarSize
    let shadowOutsets: ShadowOutsets
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowOffsetY: Double
    let edgeAlphaMax: EdgeAlphaMax
    let leftShadowClearsBeforeBoundary: Bool
    let rightShadowClearsBeforeBoundary: Bool
    let bottomShadowClearsBeforeBoundary: Bool
    let fadeClearsBeforeBoundary: Bool
    let captureMode: String
    let limitation: String
}

enum IslandSizingMatrixProbe {
    static func validateAnimatedAnchors() throws -> [IslandWindowSizingResult] {
        let layoutEngine = NotchLayoutEngine()
        let states: [IslandVisualState] = [.compactCollapsed, .activityCollapsed, .expandedApp]
        let fractions: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]
        let rows = syntheticDisplays().flatMap { scenario -> [IslandWindowSizingResult] in
            let attachment = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
            let results = states.map { state in
                IslandWindowSizingEngine.resolve(
                    state: state,
                    attachmentMetrics: attachment,
                    widthConstraints: IslandWidthConstraints(
                        baseBodyWidth: IslandVisualTokens.compact.previewWidth * attachment.horizontalVisualScale,
                        maximumVisibleWidth: attachment.availableTopWidth,
                        contentWidthRequirement: state.previewContentWidthRequirement
                    )
                )
            }
            return zip(results, results.dropFirst()).flatMap { source, target in
                fractions.map {
                    IslandWindowSizingEngine.resolveAnimatedSample(
                        from: source,
                        to: target,
                        progress: $0,
                        attachmentMetrics: attachment
                    )
                }
            }
        }
        guard rows.allSatisfy({ result in
            syntheticDisplays().contains { scenario in
                let attachment = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
                return abs(result.visibleFrame.midX - attachment.centerX) < 0.01 &&
                    abs(result.visibleFrame.maxY - attachment.topBandFrame.maxY) < 0.01 &&
                    result.shadowFrame.contains(result.visibleFrame) &&
                    result.shadowFrame.contains(result.hitTestFrame)
            }
        }) else {
            throw IslandSizingMatrixProbeError.invalidAnimatedAnchor
        }
        return rows
    }

    /// Covers internal-notch, flat external, narrow, and wide displays with
    /// content changes that occur while an activity presentation is visible.
    static func validateResponsiveContentProfiles() throws -> [IslandWindowSizingResult] {
        let layoutEngine = NotchLayoutEngine()
        let shortContent = IslandContentWidthRequirement(
            leadingContentWidth: 38,
            trailingContentWidth: 72,
            horizontalPadding: 16
        )
        let longContent = IslandContentWidthRequirement(
            leadingContentWidth: 38,
            trailingContentWidth: 164,
            horizontalPadding: 16
        )
        let fractions: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]
        let rows = syntheticDisplays().flatMap { scenario -> [IslandWindowSizingResult] in
            let attachment = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
            let fallbackWidth = IslandVisualTokens.activity.previewWidth * attachment.horizontalVisualScale
            let notchBodyWidth = attachment.notchFrame.map { max($0.width - 18, 1) }
            let baseBodyWidth = notchBodyWidth ?? fallbackWidth
            let maximumVisibleWidth = attachment.availableTopWidth
            let source = IslandWindowSizingEngine.resolve(
                state: .activityCollapsed,
                attachmentMetrics: attachment,
                widthConstraints: IslandWidthConstraints(
                    baseBodyWidth: baseBodyWidth,
                    maximumVisibleWidth: maximumVisibleWidth,
                    contentWidthRequirement: shortContent
                )
            )
            let target = IslandWindowSizingEngine.resolve(
                state: .activityCollapsed,
                attachmentMetrics: attachment,
                widthConstraints: IslandWidthConstraints(
                    baseBodyWidth: baseBodyWidth,
                    maximumVisibleWidth: maximumVisibleWidth,
                    contentWidthRequirement: longContent
                )
            )
            return fractions.map {
                IslandWindowSizingEngine.resolveAnimatedSample(
                    from: source,
                    to: target,
                    progress: $0,
                    attachmentMetrics: attachment
                )
            }
        }

        guard rows.count == syntheticDisplays().count * fractions.count,
              rows.allSatisfy({ result in
                  guard let scenario = syntheticDisplays().first(where: { scenario in
                      let attachment = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
                      return abs(result.visibleFrame.midX - attachment.centerX) < 0.01 &&
                          abs(result.visibleFrame.maxY - attachment.topBandFrame.maxY) < 0.01
                  }) else {
                      return false
                  }
                  let attachment = layoutEngine.topAttachmentMetrics(for: scenario.metrics)
                  return result.visibleSize.width <= attachment.availableTopWidth + 0.01 &&
                      result.shadowFrame.contains(result.visibleFrame) &&
                      result.shadowFrame.contains(result.hitTestFrame)
              }) else {
            throw IslandSizingMatrixProbeError.invalidResponsiveLayout
        }

        for index in stride(from: 0, to: rows.count, by: fractions.count) {
            let samples = Array(rows[index..<(index + fractions.count)])
            guard zip(samples, samples.dropFirst()).allSatisfy({ previous, next in
                next.visibleSize.width + 0.01 >= previous.visibleSize.width
            }) else {
                throw IslandSizingMatrixProbeError.invalidResponsiveLayout
            }
        }
        return rows
    }
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

    fileprivate static func syntheticDisplays() -> [(name: String, metrics: ScreenMetrics)] {
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
        let narrowFlatMetrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 320, height: 640),
            visibleFrame: CGRect(x: 0, y: 0, width: 320, height: 616),
            safeAreaInsets: NSEdgeInsetsZero,
            notchFrame: nil,
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 3)
        )
        let wideFlatMetrics = ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 3024, height: 1964),
            visibleFrame: CGRect(x: 0, y: 0, width: 3024, height: 1940),
            safeAreaInsets: NSEdgeInsetsZero,
            notchFrame: nil,
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 4)
        )

        return [
            (name: "notch-display", metrics: notchMetrics),
            (name: "flat-top-display", metrics: flatTopMetrics),
            (name: "narrow-flat-display", metrics: narrowFlatMetrics),
            (name: "wide-flat-display", metrics: wideFlatMetrics)
        ]
    }

    fileprivate static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    fileprivate static func scalar(_ size: CGSize) -> IslandSizingMatrixRow.ScalarSize {
        IslandSizingMatrixRow.ScalarSize(
            width: scalar(size.width),
            height: scalar(size.height)
        )
    }

    fileprivate static func scalar(_ rect: CGRect) -> IslandSizingMatrixRow.ScalarRect {
        IslandSizingMatrixRow.ScalarRect(
            x: scalar(rect.minX),
            y: scalar(rect.minY),
            width: scalar(rect.width),
            height: scalar(rect.height)
        )
    }
}

enum IslandShadowEvidenceProbe {
    private static let displayScenario = "notch-display"
    private static let boundaryAlphaThreshold = 0.01
    private static let capturePadding: CGFloat = 32
    private static let backgroundColor = NSColor(
        calibratedRed: 0.77,
        green: 0.91,
        blue: 1,
        alpha: 1
    )
    private static let syntheticLimitation =
        "Synthetic CoreGraphics capture from IslandShapeEngine and Phase 4 sizing outputs; not a physical-device AppKit window capture because the current environment has CommandLineTools-only Xcode support."

    static func generateEvidence(outputDirectory: URL) throws -> [IslandShadowEvidenceRow] {
        let layoutEngine = NotchLayoutEngine()
        let scenario = IslandSizingMatrixProbe.syntheticDisplays().first { $0.name == displayScenario }
            ?? IslandSizingMatrixProbe.syntheticDisplays().first!
        let attachmentMetrics = layoutEngine.topAttachmentMetrics(for: scenario.metrics)

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        return try expandedStates.map { state in
            let widthConstraints = IslandWidthConstraints(
                baseBodyWidth: IslandVisualTokens.compact.previewWidth * attachmentMetrics.horizontalVisualScale,
                maximumVisibleWidth: attachmentMetrics.availableTopWidth,
                contentWidthRequirement: state.previewContentWidthRequirement
            )
            let sizingResult = IslandWindowSizingEngine.resolve(
                state: state,
                attachmentMetrics: attachmentMetrics,
                widthConstraints: widthConstraints
            )
            let snapshot = IslandShapeEngine.snapshot(
                for: state,
                visualScale: attachmentMetrics.visualScale,
                horizontalScale: attachmentMetrics.horizontalVisualScale,
                widthConstraints: widthConstraints
            )
            let shadowAppearance = IslandVisualTokens.shadow.appearance(
                for: state,
                visualScale: attachmentMetrics.visualScale
            )
            let imageName = imageFileName(for: state)
            let imageURL = outputDirectory.appendingPathComponent(imageName)
            let analysis = try renderCapture(
                snapshot: snapshot,
                shadowAppearance: shadowAppearance,
                outputURL: imageURL
            )

            return IslandShadowEvidenceRow(
                displayScenario: scenario.name,
                state: state.rawValue,
                imagePath: outputDirectory
                    .appendingPathComponent(imageName)
                    .path(percentEncoded: false),
                visualScale: IslandSizingMatrixProbe.scalar(attachmentMetrics.visualScale),
                horizontalScale: IslandSizingMatrixProbe.scalar(attachmentMetrics.horizontalVisualScale),
                visibleSize: IslandSizingMatrixProbe.scalar(sizingResult.visibleSize),
                shadowSize: IslandSizingMatrixProbe.scalar(sizingResult.shadowSize),
                shadowOutsets: IslandShadowEvidenceRow.ShadowOutsets(
                    horizontal: IslandSizingMatrixProbe.scalar(sizingResult.shadowOutsets.horizontal),
                    bottom: IslandSizingMatrixProbe.scalar(sizingResult.shadowOutsets.bottom)
                ),
                shadowOpacity: shadowAppearance.opacity,
                shadowRadius: IslandSizingMatrixProbe.scalar(shadowAppearance.radius),
                shadowOffsetY: IslandSizingMatrixProbe.scalar(shadowAppearance.offsetY),
                edgeAlphaMax: IslandShadowEvidenceRow.EdgeAlphaMax(
                    left: analysis.edgeAlphaMax.left,
                    right: analysis.edgeAlphaMax.right,
                    bottom: analysis.edgeAlphaMax.bottom
                ),
                leftShadowClearsBeforeBoundary: analysis.leftShadowClearsBeforeBoundary,
                rightShadowClearsBeforeBoundary: analysis.rightShadowClearsBeforeBoundary,
                bottomShadowClearsBeforeBoundary: analysis.bottomShadowClearsBeforeBoundary,
                fadeClearsBeforeBoundary: analysis.fadeClearsBeforeBoundary,
                captureMode: "synthetic-coregraphics",
                limitation: syntheticLimitation
            )
        }
    }

    static func jsonData(outputDirectory: URL, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(generateEvidence(outputDirectory: outputDirectory))
    }

    private static var expandedStates: [IslandVisualState] {
        [.expandedMusic, .expandedApp]
    }

    private static func imageFileName(for state: IslandVisualState) -> String {
        switch state {
        case .expandedMusic:
            return "expanded-music-shadow.png"
        case .expandedApp:
            return "expanded-app-shadow.png"
        case .compactCollapsed, .hoverCollapsed, .activityCollapsed:
            return "\(state.rawValue)-shadow.png"
        }
    }

    private static func renderCapture(
        snapshot: IslandShapeLayoutSnapshot,
        shadowAppearance: IslandShadowAppearanceTokens,
        outputURL: URL
    ) throws -> ShadowRenderAnalysis {
        let canvasSize = CGSize(
            width: snapshot.contentFrame.width + (capturePadding * 2),
            height: snapshot.contentFrame.height + (capturePadding * 2)
        )
        let pixelWidth = max(Int(ceil(canvasSize.width)), 1)
        let pixelHeight = max(Int(ceil(canvasSize.height)), 1)
        let bytesPerRow = pixelWidth * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let shadowContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "IslandShadowEvidenceProbe", code: 1)
        }

        shadowContext.setAllowsAntialiasing(true)
        drawShell(
            in: shadowContext,
            snapshot: snapshot,
            shadowAppearance: shadowAppearance,
            backgroundColor: nil,
            canvasSize: canvasSize
        )

        guard let shadowImage = shadowContext.makeImage() else {
            throw NSError(domain: "IslandShadowEvidenceProbe", code: 2)
        }
        let analysis = analyzeBoundaryAlpha(image: shadowImage)

        guard let compositedContext = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "IslandShadowEvidenceProbe", code: 3)
        }

        drawShell(
            in: compositedContext,
            snapshot: snapshot,
            shadowAppearance: shadowAppearance,
            backgroundColor: backgroundColor,
            canvasSize: canvasSize
        )

        guard let compositedImage = compositedContext.makeImage() else {
            throw NSError(domain: "IslandShadowEvidenceProbe", code: 4)
        }
        try writePNG(image: compositedImage, to: outputURL)
        return analysis
    }

    private static func drawShell(
        in context: CGContext,
        snapshot: IslandShapeLayoutSnapshot,
        shadowAppearance: IslandShadowAppearanceTokens,
        backgroundColor: NSColor?,
        canvasSize: CGSize
    ) {
        if let backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(
                CGRect(
                    origin: .zero,
                    size: canvasSize
                )
            )
        } else {
            context.clear(
                CGRect(
                    origin: .zero,
                    size: canvasSize
                )
            )
        }

        let combinedPath = CGMutablePath()
        let translation = CGAffineTransform(
            translationX: capturePadding,
            y: capturePadding
        )
        combinedPath.addPath(snapshot.leftCapPath, transform: translation)
        combinedPath.addPath(snapshot.rightCapPath, transform: translation)
        combinedPath.addPath(snapshot.leftEarPath, transform: translation)
        combinedPath.addPath(snapshot.rightEarPath, transform: translation)
        combinedPath.addPath(snapshot.bodyPath, transform: translation)
        let translatedStrokePath = snapshot.strokePath.map {
            let path = CGMutablePath()
            path.addPath($0, transform: translation)
            return path.copy()!
        }

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -shadowAppearance.offsetY),
            blur: shadowAppearance.radius,
            color: NSColor.black.withAlphaComponent(shadowAppearance.opacity).cgColor
        )
        context.addPath(combinedPath)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        if let strokePath = translatedStrokePath {
            context.addPath(strokePath)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
            context.setLineWidth(1)
            context.strokePath()
        }
        context.restoreGState()

        context.addPath(combinedPath)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        if let strokePath = translatedStrokePath {
            context.addPath(strokePath)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
            context.setLineWidth(1)
            context.strokePath()
        }
    }

    private static func writePNG(image: CGImage, to outputURL: URL) throws {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IslandShadowEvidenceProbe", code: 5)
        }
        try data.write(to: outputURL)
    }

    private static func analyzeBoundaryAlpha(image: CGImage) -> ShadowRenderAnalysis {
        guard let provider = image.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return ShadowRenderAnalysis(
                edgeAlphaMax: .zero,
                leftShadowClearsBeforeBoundary: false,
                rightShadowClearsBeforeBoundary: false,
                bottomShadowClearsBeforeBoundary: false
            )
        }

        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow

        func alphaAt(x: Int, y: Int) -> Double {
            let offset = (y * bytesPerRow) + (x * 4) + 3
            return Double(bytes[offset]) / 255
        }

        var leftMax = 0.0
        var rightMax = 0.0
        var bottomMax = 0.0

        for y in 0..<height {
            leftMax = max(leftMax, alphaAt(x: 0, y: y))
            rightMax = max(rightMax, alphaAt(x: max(width - 1, 0), y: y))
        }

        for x in 0..<width {
            bottomMax = max(bottomMax, alphaAt(x: x, y: 0))
        }

        return ShadowRenderAnalysis(
            edgeAlphaMax: IslandShadowEvidenceRow.EdgeAlphaMax(
                left: rounded(leftMax),
                right: rounded(rightMax),
                bottom: rounded(bottomMax)
            ),
            leftShadowClearsBeforeBoundary: leftMax <= boundaryAlphaThreshold,
            rightShadowClearsBeforeBoundary: rightMax <= boundaryAlphaThreshold,
            bottomShadowClearsBeforeBoundary: bottomMax <= boundaryAlphaThreshold
        )
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}

private struct ShadowRenderAnalysis {
    let edgeAlphaMax: IslandShadowEvidenceRow.EdgeAlphaMax
    let leftShadowClearsBeforeBoundary: Bool
    let rightShadowClearsBeforeBoundary: Bool
    let bottomShadowClearsBeforeBoundary: Bool

    var fadeClearsBeforeBoundary: Bool {
        leftShadowClearsBeforeBoundary &&
            rightShadowClearsBeforeBoundary &&
            bottomShadowClearsBeforeBoundary
    }
}
