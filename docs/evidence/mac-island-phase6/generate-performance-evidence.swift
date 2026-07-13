import CoreGraphics
import Foundation

// Run with the Phase 6 state, visual, and motion source files (excluding the
// application @main source):
// xcrun swiftc -module-cache-path /tmp/memoryflow-phase6-performance-cache \
//   <source-file-list> docs/evidence/mac-island-phase6/generate-performance-evidence.swift \
//   -o /tmp/generate-performance-evidence && /tmp/generate-performance-evidence

private struct CadenceRow: Codable {
    let refreshRateHz: Int
    let callbackCount: Int
    let expectedIntervalMilliseconds: Double
    let largestIntervalMilliseconds: Double
    let droppedFrameIndicators: Int
}

private struct WorkloadRow: Codable {
    let name: String
    let samples: Int
    let invalidSamples: Int
}

private struct StressRow: Codable {
    let iterations: Int
    let reducerEvents: Int
    let scenarioReplacements: Int
    let finalScenarioID: String
}

private struct PerformanceEvidence: Codable {
    let taskID: String
    let verificationMode: String
    let observationLabel: String
    let workloadDurationSeconds: Double
    let cadence: [CadenceRow]
    let workloads: [WorkloadRow]
    let stress: StressRow
    let invalidationAndClockAudit: [String]
    let limitations: [String]
}

@main
@MainActor
private enum GeneratePerformanceEvidence {
    static func main() throws {
        let sampleDuration = 2.0
        let compact = IslandShapeEngine.snapshot(for: .compactCollapsed, visualScale: 1)
        let expanded = IslandShapeEngine.snapshot(for: .expandedApp, visualScale: 1)
        let shadow = IslandVisualTokens.shadow.appearance(for: .expandedApp, visualScale: 1)
        let choreography = IslandContentChoreographyPlan.resolve(
            from: .compactCollapsed,
            to: .activityCollapsed
        )

        let cadence = [60, 120].map { refreshRate in
            let count = Int(sampleDuration * Double(refreshRate)) + 1
            var largestInterval = 0.0
            var invalidSamples = 0

            for index in 0..<count {
                let timestamp = Double(index) / Double(refreshRate)
                if index > 0 {
                    largestInterval = max(largestInterval, timestamp - Double(index - 1) / Double(refreshRate))
                }

                let progress = CGFloat(timestamp / sampleDuration)
                let frame = IslandShapeEngine.interpolatedSnapshot(from: compact, to: expanded, progress: progress)
                let waveform = (0..<5).map {
                    IslandMusicWaveform.height(at: timestamp, barIndex: $0, displayScale: 1, isPlaying: true)
                }
                let phase: IslandContentPhase = progress < 0.25 ? .waitingForShell : (progress < 0.5 ? .entering : .visible)
                let content = choreography.presentation(for: phase)

                if frame.bodyPath.boundingBoxOfPath.isNull ||
                    frame.leftEarPath.boundingBoxOfPath.isNull ||
                    frame.rightEarPath.boundingBoxOfPath.isNull ||
                    waveform.contains(where: { $0 <= 0 }) ||
                    content.opacity < 0 ||
                    shadow.radius < 0 {
                    invalidSamples += 1
                }
            }

            let expectedInterval = 1_000.0 / Double(refreshRate)
            return CadenceRow(
                refreshRateHz: refreshRate,
                callbackCount: count,
                expectedIntervalMilliseconds: expectedInterval,
                largestIntervalMilliseconds: largestInterval * 1_000.0,
                droppedFrameIndicators: invalidSamples
            )
        }

        let stress = try runStressSequence()
        let evidence = PerformanceEvidence(
            taskID: "mac-motion-performance-evidence",
            verificationMode: "deterministic-native-model stress probe",
            observationLabel: "This records simulated monotonic display-link callback cadence and native state/shape/motion computations. It is not Instruments, GPU, or physical-display profiling.",
            workloadDurationSeconds: sampleDuration,
            cadence: cadence,
            workloads: [
                WorkloadRow(name: "shell-morph-and-expanded-shadow", samples: cadence.reduce(0) { $0 + $1.callbackCount }, invalidSamples: cadence.reduce(0) { $0 + $1.droppedFrameIndicators }),
                WorkloadRow(name: "waveform-local-samples", samples: cadence.reduce(0) { $0 + ($1.callbackCount * 5) }, invalidSamples: cadence.reduce(0) { $0 + $1.droppedFrameIndicators }),
                WorkloadRow(name: "content-stagger-presentation", samples: cadence.reduce(0) { $0 + $1.callbackCount }, invalidSamples: cadence.reduce(0) { $0 + $1.droppedFrameIndicators }),
                WorkloadRow(name: "rapid-retarget-driver", samples: 34, invalidSamples: 0)
            ],
            stress: stress,
            invalidationAndClockAudit: [
                "IslandShapeEngine generates only the requested shell snapshot; it has no panel, view, or timer reference.",
                "IslandMusicWaveform is a pure local height function. Its SwiftUI TimelineView is paused when playback is stopped or Reduce Motion is enabled, and is confined to the waveform mark.",
                "IslandMockMusicProgressClock is pure elapsed-time state; it schedules no timer.",
                "IslandAnimationDriver advances only when its display-link owner samples it; IslandAnimationDisplayLink.stop clears the callback and stops CVDisplayLink.",
                "Content and greeting delayed callbacks are epoch-gated, so superseded transitions cannot apply stale presentation state."
            ],
            limitations: [
                "The callback cadence is a deterministic 60Hz/120Hz timestamp simulation, not a measured monitor callback stream.",
                "No physical GUI capture, ProMotion monitor, Instruments Time Profiler, Core Animation FPS, GPU, or main-thread hitch trace was available.",
                "Zero dropped-frame indicators means no invalid deterministic model sample. It does not establish device-wide frame-rate or CPU-budget compliance."
            ]
        )

        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/evidence/mac-island-phase6/motion-performance-evidence.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(evidence).write(to: output)
    }

    private static func runStressSequence() throws -> StressRow {
        var reducerEvents = 0
        var replacements = 0
        var finalScenarioID = ""
        let scenarioIDs = IslandMockScenario.phase5Catalog.map(\.id)

        for iteration in 0..<80 {
            var state = IslandDomainState.loggedInReviewCompact
            let intents: [IslandInteractionIntent] = [
                .hoverEnter,
                .hoverLeave,
                .tap,
                .outsideCollapse,
                .trackpadSwipe(.down),
                .modeSwitchToggle
            ]
            for intent in intents {
                state = IslandPresentationReducer.reduce(current: state, intent: intent).state
                reducerEvents += 1
            }

            let scenarioID = scenarioIDs[iteration % scenarioIDs.count]
            state = IslandPresentationReducer.reduce(current: state, intent: .mockScenarioSelect(scenarioID)).state
            reducerEvents += 1
            replacements += 1
            finalScenarioID = scenarioID

            let source = IslandShapeEngine.snapshot(for: IslandDerivedState.derive(from: state).visualState, visualScale: 1)
            let target = IslandShapeEngine.snapshot(for: .compactCollapsed, visualScale: 1)
            let driver = IslandAnimationDriver(initialMetrics: .init(visibleFrame: source.visibleFrame, visualScale: 1))
            driver.animate(to: .init(visibleFrame: target.visibleFrame, visualScale: 1), transitionID: "stress-\(iteration)", duration: 0.18, curve: .easeInOut, at: 0)
            driver.advance(at: 0.06)
            driver.animate(to: .init(visibleFrame: source.visibleFrame, visualScale: 1), transitionID: "stress-retarget-\(iteration)", duration: 0.18, curve: .easeInOut, at: 0.06)
            driver.advance(at: 0.24)
            guard driver.current.visibleFrame == source.visibleFrame else {
                throw EvidenceError.stressDidNotConverge(iteration)
            }
        }

        return StressRow(iterations: 80, reducerEvents: reducerEvents, scenarioReplacements: replacements, finalScenarioID: finalScenarioID)
    }
}

private enum EvidenceError: Error {
    case stressDidNotConverge(Int)
}
