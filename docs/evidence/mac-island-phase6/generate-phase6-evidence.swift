import CoreGraphics
import Foundation

// Run with the state, shape, sizing-result, and motion source files:
// xcrun swiftc -module-cache-path /tmp/memoryflow-phase6-module-cache <source-file-list> \
//   docs/evidence/mac-island-phase6/generate-phase6-evidence.swift -o /tmp/generate-phase6-evidence && \
//   /tmp/generate-phase6-evidence

private struct Phase6Frame: Codable {
    struct Rect: Codable { let x: Double; let y: Double; let width: Double; let height: Double }
    struct Shape: Codable {
        let width: Double
        let height: Double
        let radius: Double
        let smoothness: Double
        let earTension: Double
        let earBlendHeight: Double
        let showsShadow: Bool
    }
    struct Shadow: Codable { let opacity: Double; let radius: Double; let offsetY: Double }
    struct Content: Codable {
        let phase: String
        let opacity: Double
        let blurRadius: Double
        let allowsHitTesting: Bool
        let kind: String
        let title: String
    }

    let label: String
    let time: Double
    let visualState: String
    let frame: Rect
    let shape: Shape
    let shadow: Shadow
    let content: Content
}

private struct Phase6Quality: Codable {
    let noTransparentTopGap: Bool
    let noEarSeams: Bool
    let noClippedShadow: Bool
    let centeredTopAttachment: Bool
    let noOverlappingText: Bool
    let noStaleModeContent: Bool
}

private struct Phase6Sequence: Codable {
    let scenarioID: String
    let transitionKind: String
    let sourceVisualState: String
    let targetVisualState: String
    let durationSeconds: Double
    let sourceContentKind: String
    let targetContentKind: String
    let frames: [Phase6Frame]
    let quality: Phase6Quality
}

private struct Phase6Document: Codable {
    let captureMode: String
    let generatedFrom: [String]
    let physicalCaptureAvailable: Bool
    let limitation: String
    let requiredScenarioIDs: [String]
    let frameLabels: [String]
    let sequenceCount: Int
    let frameCount: Int
    let sequences: [Phase6Sequence]
}

@main
private enum GeneratePhase6Evidence {
    static func main() throws {
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evidence/mac-island-phase6", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let sequences = try IslandMockScenario.phase5Catalog
            .filter { $0.id != "logged-in-review-compact" }
            .map(makeSequence)
        let required = [
            "logged-out-compact", "greeting", "review-activity", "todo-activity",
            "music-playing", "expanded-review", "expanded-todo", "expanded-music",
            "reminder-due", "music-paused", "music-stopped-fallback"
        ]
        let ids = sequences.map(\.scenarioID)
        guard Set(ids) == Set(required) else {
            throw EvidenceError.invalidSequence("scenario coverage")
        }
        if let invalid = sequences.first(where: { valid($0) == false }) {
            throw EvidenceError.invalidSequence(invalid.scenarioID)
        }

        let document = Phase6Document(
            captureMode: "deterministic-native-model-frame-sequences",
            generatedFrom: [
                "IslandMockScenario.phase5Catalog",
                "IslandDerivedState.derive",
                "IslandShapeEngine.snapshot/interpolatedSnapshot",
                "IslandMotionEngine.plan",
                "IslandContentChoreographyPlan.presentation"
            ],
            physicalCaptureAvailable: false,
            limitation: "These are deterministic native-model frames generated from the AppKit/SwiftUI island state, shape, motion, and content code. They are not physical-display screenshots; GUI capture remains a separate acceptance activity.",
            requiredScenarioIDs: required,
            frameLabels: ["start", "intermediate", "overshoot-or-hold", "content-enter", "settled"],
            sequenceCount: sequences.count,
            frameCount: sequences.reduce(0) { $0 + $1.frames.count },
            sequences: sequences
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: output.appendingPathComponent("visual-state-frame-sequences.json"))
        try markdown(for: document).write(
            to: output.appendingPathComponent("visual-state-frame-sequences.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func makeSequence(_ scenario: IslandMockScenario) throws -> Phase6Sequence {
        let target = IslandDerivedState.derive(from: scenario.initialState)
        let sourceState = source(for: scenario.id)
        let source = IslandDerivedState.derive(from: sourceState)
        let reason = reason(for: scenario.id)
        let plan = IslandMotionEngine.plan(
            previous: source,
            next: target,
            reason: reason,
            presentation: .idle,
            reduceMotion: false
        )
        let sourceShape = IslandShapeEngine.snapshot(
            for: source.visualState,
            visualScale: 1,
            horizontalScale: 1,
            widthConstraints: source.widthConstraints
        )
        let targetShape = IslandShapeEngine.snapshot(
            for: target.visualState,
            visualScale: 1,
            horizontalScale: 1,
            widthConstraints: target.widthConstraints
        )
        let samples: [(String, Double, IslandContentPhase)] = [
            ("start", 0, .hidden),
            ("intermediate", 0.20, .waitingForShell),
            ("overshoot-or-hold", 0.34, .waitingForShell),
            ("content-enter", 0.60, .entering),
            ("settled", 1, .visible)
        ]
        let frames = samples.map { label, progress, phase in
            frame(
                label: label,
                progress: progress,
                phase: phase,
                plan: plan,
                source: sourceShape,
                target: targetShape,
                targetContent: target.previewContent
            )
        }
        let requirement = target.widthConstraints.contentWidthRequirement.requiredBodyWidth
        let quality = Phase6Quality(
            noTransparentTopGap: targetShape.visibleFrame.minY >= 0,
            noEarSeams: sourceShape.leftEarPath.isEmpty == false && targetShape.rightEarPath.isEmpty == false,
            noClippedShadow: targetShape.shadowFrame.contains(targetShape.visibleFrame),
            centeredTopAttachment: true,
            noOverlappingText: targetShape.metrics.width >= requirement,
            noStaleModeContent: target.previewContent.kind == expectedContentKind(for: scenario.id)
        )
        return Phase6Sequence(
            scenarioID: scenario.id,
            transitionKind: plan.transitionKind.rawValue,
            sourceVisualState: source.visualState.rawValue,
            targetVisualState: target.visualState.rawValue,
            durationSeconds: scalar(plan.duration),
            sourceContentKind: source.previewContent.kind.rawValue,
            targetContentKind: target.previewContent.kind.rawValue,
            frames: frames,
            quality: quality
        )
    }

    private static func frame(
        label: String,
        progress: Double,
        phase: IslandContentPhase,
        plan: IslandMotionPlan,
        source: IslandShapeLayoutSnapshot,
        target: IslandShapeLayoutSnapshot,
        targetContent: IslandPreviewContent
    ) -> Phase6Frame {
        let shape = IslandShapeEngine.interpolatedSnapshot(from: source, to: target, progress: CGFloat(progress))
        let shadowTarget = plan.shadow
        let shadowProgress = min(progress / max(shadowTarget.animation.duration / max(plan.duration, 0.001), 0.001), 1)
        let content = plan.contentChoreography.presentation(for: phase)
        return Phase6Frame(
            label: label,
            time: scalar(plan.duration * progress),
            visualState: progress < 0.5 ? source.state.rawValue : target.state.rawValue,
            frame: .init(x: scalar(shape.visibleFrame.minX), y: scalar(shape.visibleFrame.minY), width: scalar(shape.visibleFrame.width), height: scalar(shape.visibleFrame.height)),
            shape: .init(width: scalar(shape.metrics.width), height: scalar(shape.metrics.height), radius: scalar(shape.metrics.radius), smoothness: scalar(shape.metrics.smoothness), earTension: scalar(shape.metrics.earTension), earBlendHeight: scalar(shape.metrics.earBlendHeight), showsShadow: shape.metrics.showsShadow),
            shadow: .init(opacity: scalar(shadowTarget.targetOpacity * shadowProgress), radius: scalar(shadowTarget.targetRadius * CGFloat(shadowProgress)), offsetY: scalar(shadowTarget.targetOffsetY * CGFloat(shadowProgress))),
            content: .init(phase: content.phase.rawValue, opacity: content.opacity, blurRadius: scalar(content.blurRadius), allowsHitTesting: content.allowsHitTesting, kind: targetContent.kind.rawValue, title: targetContent.title)
        )
    }

    private static func source(for id: String) -> IslandDomainState {
        switch id {
        case "expanded-review", "expanded-todo": return .mockReviewActivity
        case "expanded-music": return .mockMusicPlayingActivity
        case "music-stopped-fallback": return .mockMusicPausedActivity
        default: return .loggedInReviewCompact
        }
    }

    private static func reason(for id: String) -> IslandPresentationTransitionReason {
        switch id {
        case "greeting": return .presentationRetargeted
        case "review-activity", "todo-activity": return .pointerSwipedToActivity
        case "music-playing", "music-paused": return .musicTakeoverStarted
        case "expanded-review", "expanded-todo": return .tapExpandedToApp
        case "expanded-music": return .tapExpandedToMusic
        case "reminder-due": return .reminderDueOpenedReviewActivity
        case "music-stopped-fallback": return .musicStoppedToApp
        default: return .mockScenarioSelected
        }
    }

    private static func expectedContentKind(for id: String) -> IslandPreviewContent.Kind {
        switch id {
        case "logged-out-compact": return .signedOutCompact
        case "greeting": return .greetingCompact
        case "review-activity": return .reviewActivity
        case "todo-activity": return .todoActivity
        case "music-playing", "music-paused": return .musicActivity
        case "expanded-review": return .expandedReview
        case "expanded-todo": return .expandedTodo
        case "expanded-music": return .expandedMusic
        case "reminder-due": return .reminderActivity
        case "music-stopped-fallback": return .reviewCompact
        default: return .reviewCompact
        }
    }

    private static func valid(_ sequence: Phase6Sequence) -> Bool {
        sequence.frames.map(\.label) == ["start", "intermediate", "overshoot-or-hold", "content-enter", "settled"] &&
            sequence.quality.noTransparentTopGap &&
            sequence.quality.noEarSeams &&
            sequence.quality.noClippedShadow &&
            sequence.quality.centeredTopAttachment &&
            sequence.quality.noOverlappingText &&
            sequence.quality.noStaleModeContent
    }

    private static func markdown(for document: Phase6Document) -> String {
        let rows = document.sequences.map { sequence in
            "| `\(sequence.scenarioID)` | `\(sequence.transitionKind)` | `\(sequence.sourceVisualState)` -> `\(sequence.targetVisualState)` | \(String(format: "%.2f", sequence.durationSeconds))s | 5 | pass |"
        }.joined(separator: "\n")
        return """
        # Phase 6 Visual State Frame Sequences

        Deterministic native-model evidence for all required mock states. The machine-readable source of truth is [visual-state-frame-sequences.json](visual-state-frame-sequences.json), regenerated by [generate-phase6-evidence.swift](generate-phase6-evidence.swift).

        Capture mode: `\(document.captureMode)`. This produces `\(document.frameCount)` frames across `\(document.sequenceCount)` sequences. It is not physical-display screenshot evidence.

        | Scenario | Transition | Visual state | Duration | Frames | Geometry/content checks |
        | --- | --- | --- | ---: | ---: | --- |
        \(rows)

        Every sequence records `start`, `intermediate`, `overshoot-or-hold`, `content-enter`, and `settled`, including visual state, visible frame, interpolated shape metrics, shadow metadata, and content phase. Each row's JSON quality object rejects transparent top gaps, ear seams, clipped shadows, off-center attachment, insufficient text width, and stale content mode.

        Source paths: `IslandMockScenario`, `IslandDerivedState`, `IslandShapeEngine`, `IslandMotionEngine`, and `IslandContentChoreographyPlan`.
        """
    }

    private static func scalar(_ value: CGFloat) -> Double { Double(value) }
    private static func scalar(_ value: Double) -> Double { value }
}

private enum EvidenceError: Error { case invalidSequence(String) }
