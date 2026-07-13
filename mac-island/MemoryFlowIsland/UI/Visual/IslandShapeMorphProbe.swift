import CoreGraphics
import Foundation

enum IslandShapeMorphProbe {
    static func validateFrames() throws {
        let source = IslandShapeEngine.snapshot(for: .compactCollapsed, visualScale: 1)
        let target = IslandShapeEngine.snapshot(for: .expandedApp, visualScale: 1)
        var lastWidth = source.visibleFrame.width

        for progress in stride(from: CGFloat(0), through: 1, by: 0.05) {
            let frame = IslandShapeEngine.interpolatedSnapshot(from: source, to: target, progress: progress)
            guard frame.visibleFrame.width >= lastWidth,
                  frame.visibleFrame.width > 0,
                  frame.visibleFrame.height > 0,
                  frame.bodyPath.boundingBoxOfPath.isNull == false,
                  frame.leftCapPath.boundingBoxOfPath.isNull == false,
                  frame.rightCapPath.boundingBoxOfPath.isNull == false,
                  frame.leftEarPath.boundingBoxOfPath.isNull == false,
                  frame.rightEarPath.boundingBoxOfPath.isNull == false,
                  frame.bodyPath.boundingBoxOfPath.intersects(frame.leftEarPath.boundingBoxOfPath),
                  frame.bodyPath.boundingBoxOfPath.intersects(frame.rightEarPath.boundingBoxOfPath)
            else { throw IslandShapeMorphProbeError.invalidFrame(progress) }
            lastWidth = frame.visibleFrame.width
        }
    }
}

enum IslandShapeMorphProbeError: Error { case invalidFrame(CGFloat) }
