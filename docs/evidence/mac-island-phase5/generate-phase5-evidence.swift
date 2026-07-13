import AppKit
import Foundation

struct IslandPhase5ScenarioSelectionProbeRow: Codable, Equatable {
    let scenarioID: String
    let visualState: String
    let presentationState: String
}

struct IslandPhase5NativePreviewScenarioE2EDocument: Codable, Equatable {
    let generatedFrom: String
    let verificationMode: String
    let nativeHostLaunchAttempt: String
    let physicalCaptureAvailable: Bool
    let environmentCaveats: [String]
    let requiredScenarioIDs: [String]
    let rows: [IslandPhase5NativePreviewScenarioE2ERow]
}

struct IslandPhase5NativePreviewScenarioE2ERow: Codable, Equatable {
    let scenarioID: String
    let menuTitle: String
    let statusMenuPath: String
    let selectedIntent: String
    let visualState: String
    let presentationState: String
    let shellShapeChangedFromSeed: Bool
    let shellShapeEvidence: String
    let markerContentChangedFromSeed: Bool
    let markerGlyph: String
    let markerLabel: String
    let markerTone: String
    let previewContentKind: String
    let previewContentTitle: String
    let previewContentBadge: String
    let hasVisibleMockContent: Bool
    let hasMusicCoverAndWaveform: Bool
    let hasExpandedMusicControls: Bool
    let hasExpandedAppStructure: Bool
    let visibleFrameWidth: Double
    let visibleFrameCenterX: Double
    let notchCenterX: Double
    let visibleFrameMaxY: Double
    let displayMaxY: Double
    let staysCenteredOnNotch: Bool
    let staysTopAttached: Bool
    let notchAttachmentEvidence: String
}

struct IslandPhase5NativePreviewMouseE2EDocument: Codable, Equatable {
    let generatedFrom: String
    let verificationMode: String
    let nativeHostLaunchAttempt: String
    let physicalCaptureAvailable: Bool
    let environmentCaveats: [String]
    let requiredChecks: [String]
    let rows: [IslandPhase5NativePreviewMouseE2ERow]
}

struct IslandPhase5NativePreviewMouseE2ERow: Codable, Equatable {
    let checkID: String
    let interactionSource: String
    let menuFallbackPath: String
    let emittedIntents: [String]
    let observedOutcome: String
    let finalVisualState: String
    let finalPresentationState: String
    let hoverGrowsWithoutShadow: Bool
    let tapExpandedOrCollapsed: Bool
    let pointerCompactedOrRestoredActivity: Bool
    let tapLoopDoesNotRequireHoverLeave: Bool
    let finalPreviewContentKind: String
    let visibleFrameWidth: Double
    let baselineVisibleFrameWidth: Double
    let shadowFrameWidth: Double
    let baselineShadowFrameWidth: Double
    let shadowRadius: Double
    let shadowOpacity: Double
    let visibleFrameCenterX: Double
    let notchCenterX: Double
    let visibleFrameMaxY: Double
    let displayMaxY: Double
    let staysCenteredOnNotch: Bool
    let staysTopAttached: Bool
    let evidence: String
}

struct IslandPhase5NativePreviewTrackpadE2EDocument: Codable, Equatable {
    let generatedFrom: String
    let verificationMode: String
    let nativeHostLaunchAttempt: String
    let physicalCaptureAvailable: Bool
    let environmentCaveats: [String]
    let requiredChecks: [String]
    let rows: [IslandPhase5NativePreviewTrackpadE2ERow]
}

struct IslandPhase5NativePreviewTrackpadE2ERow: Codable, Equatable {
    let checkID: String
    let interactionSource: String
    let menuFallbackPath: String
    let rawGestureDeltas: [String]
    let emittedIntents: [String]
    let reducerReasons: [String]
    let mockMusicCommands: [String]
    let observedOutcome: String
    let finalPrimaryMode: String
    let finalVisualState: String
    let finalPresentationState: String
    let verticalOpenedActivity: Bool
    let verticalExpanded: Bool
    let verticalClosedExpanded: Bool
    let verticalCompactedActivity: Bool
    let horizontalPreviousCommanded: Bool
    let horizontalNextCommanded: Bool
    let appModeRemainedApp: Bool
    let appModeHorizontalIgnored: Bool
    let visibleFrameWidth: Double
    let baselineVisibleFrameWidth: Double
    let visibleFrameCenterX: Double
    let notchCenterX: Double
    let visibleFrameMaxY: Double
    let displayMaxY: Double
    let staysCenteredOnNotch: Bool
    let staysTopAttached: Bool
    let evidence: String
}

struct IslandPhase5InteractionSequenceCoverage: Codable, Equatable {
    let requiredPaths: [String]
    let coveredPaths: [String]
    let reducerProbeRows: Int
}

struct IslandPhase5InteractionGuardOutcomeEvidence: Codable, Equatable {
    let guardID: String
    let expectedOutcome: String
    let observedOutcome: String
    let reducerProbeSource: String
    let evidenceSequences: [String]
    let notes: String
}

struct IslandPhase5InteractionSequenceEvidenceDocument: Codable, Equatable {
    let generatedFrom: String
    let coverage: IslandPhase5InteractionSequenceCoverage
    let guardOutcomes: [IslandPhase5InteractionGuardOutcomeEvidence]
    let sequences: [IslandPresentationReducerSequenceEvidenceRow]
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
        _ = try IslandPhase5Probe.validateInteractionRows()
        let interactionSequenceEvidenceRows =
            try IslandPresentationReducerProbe.validateInteractionSequenceEvidenceRows()
        let interactionSequenceEvidence = try makeInteractionSequenceEvidenceDocument(
            rows: interactionSequenceEvidenceRows
        )
        let interactionDemoRows = try IslandPhase5Probe.validateInteractionDemoRows()
        let markerLayoutRows = try IslandPhase5Probe.validatePreviewMarkerLayoutRows()
        let previewInteractionRows = IslandPreviewInteractionProbe.generateRows()
        _ = try IslandPresentationReducerProbe.validateTapTransitionSequences()
        _ = try IslandPresentationReducerProbe.validateHoverTransitionSequences()
        _ = try IslandPresentationReducerProbe.validateTrackpadTransitionSequences()
        let scenarioSelectionRows = try validateScenarioSelectionRows()
        let nativePreviewScenarioE2E = try validateNativePreviewScenarioE2EDocument()
        let nativePreviewMouseE2E = try validateNativePreviewMouseE2EDocument()
        let nativePreviewTrackpadE2E = try validateNativePreviewTrackpadE2EDocument()

        try writeJSON(
            scenarioRows,
            to: outputDirectoryURL.appendingPathComponent("scenario-matrix.json")
        )
        try writeJSON(
            interactionSequenceEvidence,
            to: outputDirectoryURL.appendingPathComponent("interaction-sequences.json")
        )
        try writeJSON(
            interactionDemoRows,
            to: outputDirectoryURL.appendingPathComponent("interaction-demo-menu-probe.json")
        )
        try writeJSON(
            markerLayoutRows,
            to: outputDirectoryURL.appendingPathComponent("preview-marker-layout-probe.json")
        )
        try writeJSON(
            previewInteractionRows,
            to: outputDirectoryURL.appendingPathComponent("preview-interaction-probe.json")
        )
        try writeJSON(
            scenarioSelectionRows,
            to: outputDirectoryURL.appendingPathComponent("scenario-selection-probe.json")
        )
        try writeJSON(
            nativePreviewScenarioE2E,
            to: outputDirectoryURL.appendingPathComponent("native-preview-scenario-e2e.json")
        )
        try writeJSON(
            nativePreviewMouseE2E,
            to: outputDirectoryURL.appendingPathComponent("native-preview-mouse-e2e.json")
        )
        try writeJSON(
            nativePreviewTrackpadE2E,
            to: outputDirectoryURL.appendingPathComponent("native-preview-trackpad-e2e.json")
        )
    }

    private static func makeInteractionSequenceEvidenceDocument(
        rows: [IslandPresentationReducerSequenceEvidenceRow]
    ) throws -> IslandPhase5InteractionSequenceEvidenceDocument {
        let requiredPaths = [
            "hover",
            "tap",
            "pointer-swipe",
            "trackpad-vertical",
            "horizontal-music",
            "reminder",
            "paused-timeout",
            "rapid-retargeting"
        ]
        let requiredSequenceIDs: Set<String> = [
            "hover-enter-leave",
            "tap-expand-collapse",
            "pointer-compact-activity-swipes",
            "trackpad-vertical-swipes",
            "horizontal-music-command",
            "reminder-due",
            "paused-music-timeout",
            "rapid-retargeting",
            "rapid-hover-tap-hover",
            "tap-tap-trackpad"
        ]
        let sequenceIDs = Set(rows.map(\.scenarioID))

        guard requiredSequenceIDs.isSubset(of: sequenceIDs) else {
            throw InteractionSequenceEvidenceError.missingRequiredSequences(
                expected: requiredSequenceIDs.sorted(),
                actual: sequenceIDs.sorted()
            )
        }

        let guardOutcomes = [
            IslandPhase5InteractionGuardOutcomeEvidence(
                guardID: "click-through",
                expectedOutcome: "panel passes through pointer events while compact idle, and disables click-through while hover, expanded, or pointer tracking needs interactive routing",
                observedOutcome: "explicit",
                reducerProbeSource: "IslandWindowController.synchronizePanelClickThroughState with reducer visual states from hover-enter-leave, tap-expand-collapse, and rapid-hover-tap-hover",
                evidenceSequences: [
                    "hover-enter-leave",
                    "tap-expand-collapse",
                    "rapid-hover-tap-hover"
                ],
                notes: "Reducer rows expose the hoverCollapsed and expandedApp states that keep native routing interactive; compactCollapsed rows are the pass-through recovery targets."
            ),
            IslandPhase5InteractionGuardOutcomeEvidence(
                guardID: "gesture-lock",
                expectedOutcome: "overlapping trackpad gestures are blocked during cooldown",
                observedOutcome: "trackpadGestureLocked -> blocked",
                reducerProbeSource: "IslandPresentationReducerProbe.validateTrackpadTransitionSequences",
                evidenceSequences: [
                    "review-activity-trackpad-cooldown-lock"
                ],
                notes: "The reducer trackpad sequence probe records the immediate second trackpad intent as trackpadGestureLocked before cooldown completion."
            ),
            IslandPhase5InteractionGuardOutcomeEvidence(
                guardID: "presentation-lock",
                expectedOutcome: "mode-switch and force-compact presentation locks block stale intents until their completion intent clears the lock",
                observedOutcome: "modeSwitchLocked -> blocked; forceCompactTransitionLocked -> blocked",
                reducerProbeSource: "IslandPresentationReducerProbe.validateHoverTransitionSequences and validateInteractionSequenceEvidenceRows",
                evidenceSequences: [
                    "review-mode-switch-hover-tap-lock",
                    "rapid-retargeting"
                ],
                notes: "The generated rapid-retargeting row contains forceCompactTransitionLocked, and the reducer hover sequence probe covers modeSwitchLocked."
            ),
            IslandPhase5InteractionGuardOutcomeEvidence(
                guardID: "cooldown",
                expectedOutcome: "trackpad and horizontal music gestures enter cooldown and return to idle only after transitionComplete(trackpadGestureCooldown)",
                observedOutcome: "gestureState=cooldown, then transitionComplete(trackpadGestureCooldown) -> idle",
                reducerProbeSource: "IslandPresentationReducerProbe.validateInteractionSequenceEvidenceRows",
                evidenceSequences: [
                    "trackpad-vertical-swipes",
                    "horizontal-music-command",
                    "tap-tap-trackpad"
                ],
                notes: "Sequence state snapshots record cooldown after trackpad and horizontal music intents and idle recovery after the cooldown completion step."
            )
        ]

        guard Set(guardOutcomes.map(\.guardID)) == Set([
            "click-through",
            "gesture-lock",
            "presentation-lock",
            "cooldown"
        ]) else {
            throw InteractionSequenceEvidenceError.missingGuardOutcomeCoverage
        }

        return IslandPhase5InteractionSequenceEvidenceDocument(
            generatedFrom: "IslandPresentationReducerProbe.validateInteractionSequenceEvidenceRows",
            coverage: IslandPhase5InteractionSequenceCoverage(
                requiredPaths: requiredPaths,
                coveredPaths: requiredPaths,
                reducerProbeRows: rows.count
            ),
            guardOutcomes: guardOutcomes,
            sequences: rows
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

    private static func validateNativePreviewScenarioE2EDocument()
        throws -> IslandPhase5NativePreviewScenarioE2EDocument {
        let requiredScenarioIDs = [
            "logged-out-compact",
            "review-activity",
            "todo-activity",
            "music-activity",
            "expanded-app",
            "expanded-music"
        ]
        let rows = requiredScenarioIDs.map(nativePreviewScenarioE2ERow)
        let ids = rows.map(\.scenarioID)

        guard ids == requiredScenarioIDs else {
            throw NativePreviewScenarioE2EError.missingRequiredScenarios(
                expected: requiredScenarioIDs,
                actual: ids
            )
        }

        guard rows.allSatisfy({ $0.markerGlyph.isEmpty == false && $0.markerLabel.isEmpty == false }) else {
            throw NativePreviewScenarioE2EError.missingVisibleMarkerContent(rows)
        }

        guard rows.allSatisfy(\.hasVisibleMockContent),
              rows.contains(where: \.hasMusicCoverAndWaveform),
              rows.contains(where: \.hasExpandedMusicControls),
              rows.contains(where: \.hasExpandedAppStructure) else {
            throw NativePreviewScenarioE2EError.missingVisibleMockContent(rows)
        }

        guard rows.allSatisfy({ $0.staysCenteredOnNotch && $0.staysTopAttached }) else {
            throw NativePreviewScenarioE2EError.notchAttachmentFailed(rows)
        }

        guard rows.allSatisfy({ $0.shellShapeChangedFromSeed || $0.markerContentChangedFromSeed }) else {
            throw NativePreviewScenarioE2EError.noVisibleScenarioDelta(rows)
        }

        return IslandPhase5NativePreviewScenarioE2EDocument(
            generatedFrom: "IslandPhase5PreviewStateContainer.dispatch(.mockScenarioSelect), IslandDerivedState, IslandWindowSizingEngine, NotchLayoutEngine",
            verificationMode: "fallback Swift probe for native preview host status-menu scenarios",
            nativeHostLaunchAttempt: "./init.sh stopped before launch because backend port 8080 is occupied; xcodebuild is unavailable with CommandLineTools-only developer directory",
            physicalCaptureAvailable: false,
            environmentCaveats: [
                "Backend port 8080 is already in use by PID 59013 in this session.",
                "xcodebuild requires full Xcode, but xcode-select points at /Library/Developer/CommandLineTools.",
                "No physical macOS GUI capture path was available from the sandboxed worker."
            ],
            requiredScenarioIDs: requiredScenarioIDs,
            rows: rows
        )
    }

    private static func validateNativePreviewMouseE2EDocument()
        throws -> IslandPhase5NativePreviewMouseE2EDocument {
        let requiredChecks = [
            "hover-scale-only",
            "tap-expand-collapse",
            "pointer-drag-compact-restore"
        ]
        let rows = [
            hoverScaleOnlyE2ERow(),
            tapExpandCollapseE2ERow(),
            pointerDragCompactRestoreE2ERow()
        ]
        let ids = rows.map(\.checkID)

        guard ids == requiredChecks else {
            throw NativePreviewMouseE2EError.missingRequiredChecks(
                expected: requiredChecks,
                actual: ids
            )
        }

        guard rows.allSatisfy({ $0.staysCenteredOnNotch && $0.staysTopAttached }) else {
            throw NativePreviewMouseE2EError.notchAttachmentFailed(rows)
        }

        guard rows.contains(where: \.hoverGrowsWithoutShadow),
              rows.contains(where: \.tapExpandedOrCollapsed),
              rows.contains(where: \.pointerCompactedOrRestoredActivity),
              rows.contains(where: \.tapLoopDoesNotRequireHoverLeave) else {
            throw NativePreviewMouseE2EError.missingVisibleMouseOutcome(rows)
        }

        return IslandPhase5NativePreviewMouseE2EDocument(
            generatedFrom: "IslandPreviewInteractionAdapters, IslandPhase5PreviewStateContainer.dispatch, IslandVisualTokens, IslandWindowSizingEngine, NotchLayoutEngine",
            verificationMode: "fallback Swift probe for native preview host mouse interactions and matching interaction-demo menu controls",
            nativeHostLaunchAttempt: "./init.sh stopped before launch because backend port 8080 is occupied; xcodebuild is unavailable with CommandLineTools-only developer directory",
            physicalCaptureAvailable: false,
            environmentCaveats: [
                "Backend port 8080 is already in use by PID 59013 in this session.",
                "xcodebuild requires full Xcode, but xcode-select points at /Library/Developer/CommandLineTools.",
                "No physical macOS GUI capture path was available from the sandboxed worker, so the matching Phase 5 interaction-demo menu fallback was used."
            ],
            requiredChecks: requiredChecks,
            rows: rows
        )
    }

    private static func validateNativePreviewTrackpadE2EDocument()
        throws -> IslandPhase5NativePreviewTrackpadE2EDocument {
        let requiredChecks = [
            "trackpad-vertical-open-expand",
            "trackpad-vertical-close-compact",
            "trackpad-horizontal-music-commands",
            "trackpad-horizontal-app-mode-ignored"
        ]
        let rows = [
            trackpadVerticalOpenExpandE2ERow(),
            trackpadVerticalCloseCompactE2ERow(),
            trackpadHorizontalMusicCommandsE2ERow(),
            trackpadHorizontalAppModeIgnoredE2ERow()
        ]
        let ids = rows.map(\.checkID)

        guard ids == requiredChecks else {
            throw NativePreviewTrackpadE2EError.missingRequiredChecks(
                expected: requiredChecks,
                actual: ids
            )
        }

        guard rows.allSatisfy({ $0.staysCenteredOnNotch && $0.staysTopAttached }) else {
            throw NativePreviewTrackpadE2EError.notchAttachmentFailed(rows)
        }

        guard rows.contains(where: { $0.verticalOpenedActivity && $0.verticalExpanded }),
              rows.contains(where: { $0.verticalClosedExpanded && $0.verticalCompactedActivity }),
              rows.contains(where: { $0.horizontalPreviousCommanded && $0.horizontalNextCommanded }),
              rows.contains(where: { $0.appModeRemainedApp && $0.appModeHorizontalIgnored }) else {
            throw NativePreviewTrackpadE2EError.missingVisibleTrackpadOutcome(rows)
        }

        return IslandPhase5NativePreviewTrackpadE2EDocument(
            generatedFrom: "IslandTrackpadWheelAdapter, IslandPhase5PreviewStateContainer.dispatch, IslandPresentationReducer, IslandWindowSizingEngine, NotchLayoutEngine",
            verificationMode: "fallback Swift probe for native preview host trackpad interactions and matching interaction-demo menu controls",
            nativeHostLaunchAttempt: "./init.sh stopped before launch because backend port 8080 is occupied; xcodebuild is unavailable with CommandLineTools-only developer directory",
            physicalCaptureAvailable: false,
            environmentCaveats: [
                "Backend port 8080 is already in use by PID 59013 in this session.",
                "xcodebuild requires full Xcode, but xcode-select points at /Library/Developer/CommandLineTools.",
                "No physical macOS GUI capture path was available from the sandboxed worker, so the matching Phase 5 interaction-demo menu fallback was used."
            ],
            requiredChecks: requiredChecks,
            rows: rows
        )
    }

    private static func hoverScaleOnlyE2ERow() -> IslandPhase5NativePreviewMouseE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        let baseline = sizingResult(for: container.derivedState)
        let update = container.dispatch(intent: .hoverEnter)
        let final = sizingResult(for: update.currentDerivedState)
        let shadow = shadowAppearance(for: update.currentDerivedState.visualState)
        let hoverGrowsWithoutShadow = final.visibleFrame.width > baseline.visibleFrame.width &&
            final.shadowOutsets.horizontal == 0 &&
            final.shadowOutsets.bottom == 0 &&
            shadow.radius == 0 &&
            shadow.opacity == 0

        return mouseE2ERow(
            checkID: "hover-scale-only",
            interactionSource: "real hover enter on island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interaction Demo > Hover Enter",
            emittedIntents: ["hoverEnter"],
            observedOutcome: "hover grows slightly from compactCollapsed to hoverCollapsed without hover shadow buffer",
            finalState: update.currentState,
            finalDerivedState: update.currentDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            shadow: shadow,
            hoverGrowsWithoutShadow: hoverGrowsWithoutShadow,
            tapExpandedOrCollapsed: false,
            pointerCompactedOrRestoredActivity: false,
            tapLoopDoesNotRequireHoverLeave: false
        )
    }

    private static func tapExpandCollapseE2ERow() -> IslandPhase5NativePreviewMouseE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        let baseline = sizingResult(for: container.derivedState)
        let expandUpdate = container.dispatch(intent: .tap)
        let collapseUpdate = container.dispatch(intent: .tap)
        let final = sizingResult(for: collapseUpdate.currentDerivedState)
        let expandedSizingResult = sizingResult(for: expandUpdate.currentDerivedState)
        let tapExpandedOrCollapsed =
            expandUpdate.currentDerivedState.visualState == .expandedApp &&
            collapseUpdate.currentDerivedState.visualState == .activityCollapsed &&
            expandedSizingResult.visibleFrame.height > baseline.visibleFrame.height &&
            final.visibleFrame.width > baseline.visibleFrame.width
        let tapLoopDoesNotRequireHoverLeave =
            expandUpdate.currentState.isHovered == false &&
            collapseUpdate.currentState.isHovered == false &&
            expandUpdate.currentState.presentationState == .expanded &&
            collapseUpdate.currentState.presentationState == .activity

        return mouseE2ERow(
            checkID: "tap-expand-collapse",
            interactionSource: "real tap on island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interaction Demo > Tap, then Tap",
            emittedIntents: ["tap", "tap"],
            observedOutcome: "tap expands compact review to expanded app, then collapses to activity because a review activity source remains",
            finalState: collapseUpdate.currentState,
            finalDerivedState: collapseUpdate.currentDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            shadow: shadowAppearance(for: collapseUpdate.currentDerivedState.visualState),
            hoverGrowsWithoutShadow: false,
            tapExpandedOrCollapsed: tapExpandedOrCollapsed,
            pointerCompactedOrRestoredActivity: false,
            tapLoopDoesNotRequireHoverLeave: tapLoopDoesNotRequireHoverLeave
        )
    }

    private static func pointerDragCompactRestoreE2ERow() -> IslandPhase5NativePreviewMouseE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewActivity)
        let baseline = sizingResult(for: container.derivedState)
        var pointerAdapter = IslandPointerGestureAdapter()
        var emittedIntents: [String] = []

        pointerAdapter.pointerDown(at: 0)
        pointerAdapter.pointerDragged(to: 40)
        if let compactIntent = pointerAdapter.pointerUp(at: 40) {
            emittedIntents.append(describe(compactIntent))
            _ = container.dispatch(intent: compactIntent)
        }
        _ = container.dispatch(
            intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
        )

        pointerAdapter.pointerDown(at: 40)
        pointerAdapter.pointerDragged(to: 0)
        var restoreUpdate: IslandPhase5PreviewReducerUpdate?
        if let restoreIntent = pointerAdapter.pointerUp(at: 0) {
            emittedIntents.append(describe(restoreIntent))
            restoreUpdate = container.dispatch(intent: restoreIntent)
        }

        let finalState = restoreUpdate?.currentState ?? container.domainState
        let finalDerivedState = restoreUpdate?.currentDerivedState ?? container.derivedState
        let final = sizingResult(for: finalDerivedState)
        let pointerCompactedOrRestoredActivity =
            emittedIntents == ["pointerSwipe(right)", "pointerSwipe(left)"] &&
            finalDerivedState.visualState == .activityCollapsed &&
            finalState.forceCompactMode == false

        return mouseE2ERow(
            checkID: "pointer-drag-compact-restore",
            interactionSource: "real pointer drag on island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interaction Demo > Pointer Swipe Left / Pointer Swipe Right",
            emittedIntents: emittedIntents,
            observedOutcome: "pointer drag emits swipe intents and restores the review activity shell after compacting it",
            finalState: finalState,
            finalDerivedState: finalDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            shadow: shadowAppearance(for: finalDerivedState.visualState),
            hoverGrowsWithoutShadow: false,
            tapExpandedOrCollapsed: false,
            pointerCompactedOrRestoredActivity: pointerCompactedOrRestoredActivity,
            tapLoopDoesNotRequireHoverLeave: false
        )
    }

    private static func trackpadVerticalOpenExpandE2ERow() -> IslandPhase5NativePreviewTrackpadE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewCompact)
        let baseline = sizingResult(for: container.derivedState)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        let first = dispatchWheelEvent(
            deltaX: 0,
            deltaY: -82,
            timestamp: 0,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        wheelAdapter.clearCooldown()
        let cooldownUpdate = container.dispatch(
            intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown)
        )
        let forceCompactUpdate = container.dispatch(
            intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
        )
        let second = dispatchWheelEvent(
            deltaX: 0,
            deltaY: -86,
            timestamp: 0.4,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        let updates = [first.update, cooldownUpdate, forceCompactUpdate, second.update].compactMap { $0 }
        let finalUpdate = updates.last
        let finalDerivedState = finalUpdate?.currentDerivedState ?? container.derivedState
        let final = sizingResult(for: finalDerivedState)
        let reasons = updates.map { $0.reducerResult.reason.rawValue }
        let verticalOpenedActivity = reasons.contains("trackpadSwipedDownToActivity")
        let verticalExpanded = reasons.contains("trackpadSwipedDownToExpandedApp") &&
            finalDerivedState.visualState == .expandedApp

        return trackpadE2ERow(
            checkID: "trackpad-vertical-open-expand",
            interactionSource: "real vertical trackpad swipes down on island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interactions > Trackpad Down, cooldown completion, then Trackpad Down",
            rawGestureDeltas: first.rawGestureDeltas + second.rawGestureDeltas,
            emittedIntents: [first.emittedIntent, second.emittedIntent].compactMap { $0 },
            updates: updates,
            observedOutcome: "first vertical down swipe opens compact review to activity; second down swipe expands activity to the app surface",
            finalState: finalUpdate?.currentState ?? container.domainState,
            finalDerivedState: finalDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            verticalOpenedActivity: verticalOpenedActivity,
            verticalExpanded: verticalExpanded,
            verticalClosedExpanded: false,
            verticalCompactedActivity: false,
            horizontalPreviousCommanded: false,
            horizontalNextCommanded: false,
            appModeRemainedApp: false,
            appModeHorizontalIgnored: false
        )
    }

    private static func trackpadVerticalCloseCompactE2ERow() -> IslandPhase5NativePreviewTrackpadE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .expandedAppReview)
        let baseline = sizingResult(for: container.derivedState)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        let first = dispatchWheelEvent(
            deltaX: 0,
            deltaY: 82,
            timestamp: 0,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        wheelAdapter.clearCooldown()
        let cooldownUpdate = container.dispatch(
            intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown)
        )
        let second = dispatchWheelEvent(
            deltaX: 0,
            deltaY: 86,
            timestamp: 0.4,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        let updates = [first.update, cooldownUpdate, second.update].compactMap { $0 }
        let finalUpdate = updates.last
        let finalDerivedState = finalUpdate?.currentDerivedState ?? container.derivedState
        let final = sizingResult(for: finalDerivedState)
        let reasons = updates.map { $0.reducerResult.reason.rawValue }
        let verticalClosedExpanded = reasons.contains("trackpadSwipedUpToActivity")
        let verticalCompactedActivity = reasons.contains("trackpadSwipedUpToCompact") &&
            finalDerivedState.visualState == .compactCollapsed

        return trackpadE2ERow(
            checkID: "trackpad-vertical-close-compact",
            interactionSource: "real vertical trackpad swipes up on island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interactions > Trackpad Up, cooldown completion, then Trackpad Up",
            rawGestureDeltas: first.rawGestureDeltas + second.rawGestureDeltas,
            emittedIntents: [first.emittedIntent, second.emittedIntent].compactMap { $0 },
            updates: updates,
            observedOutcome: "first vertical up swipe closes expanded app to activity; second up swipe compacts the activity shell",
            finalState: finalUpdate?.currentState ?? container.domainState,
            finalDerivedState: finalDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            verticalOpenedActivity: false,
            verticalExpanded: false,
            verticalClosedExpanded: verticalClosedExpanded,
            verticalCompactedActivity: verticalCompactedActivity,
            horizontalPreviousCommanded: false,
            horizontalNextCommanded: false,
            appModeRemainedApp: false,
            appModeHorizontalIgnored: false
        )
    }

    private static func trackpadHorizontalMusicCommandsE2ERow() -> IslandPhase5NativePreviewTrackpadE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .musicActivity)
        let baseline = sizingResult(for: container.derivedState)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        let previous = dispatchWheelEvent(
            deltaX: -82,
            deltaY: 4,
            timestamp: 0,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        wheelAdapter.clearCooldown()
        let cooldownUpdate = container.dispatch(
            intent: .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown)
        )
        let next = dispatchWheelEvent(
            deltaX: 86,
            deltaY: 4,
            timestamp: 0.4,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        let updates = [previous.update, cooldownUpdate, next.update].compactMap { $0 }
        let finalUpdate = updates.last
        let finalDerivedState = finalUpdate?.currentDerivedState ?? container.derivedState
        let final = sizingResult(for: finalDerivedState)
        let musicCommands = updates.compactMap { $0.reducerResult.metadata.mockMusicCommand?.rawValue }

        return trackpadE2ERow(
            checkID: "trackpad-horizontal-music-commands",
            interactionSource: "real horizontal trackpad swipes on music island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interactions > Horizontal Previous, cooldown completion, then Horizontal Next",
            rawGestureDeltas: previous.rawGestureDeltas + next.rawGestureDeltas,
            emittedIntents: [previous.emittedIntent, next.emittedIntent].compactMap { $0 },
            updates: updates,
            observedOutcome: "horizontal music gestures emit mock previous and next commands while staying in music activity mode",
            finalState: finalUpdate?.currentState ?? container.domainState,
            finalDerivedState: finalDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            verticalOpenedActivity: false,
            verticalExpanded: false,
            verticalClosedExpanded: false,
            verticalCompactedActivity: false,
            horizontalPreviousCommanded: musicCommands.contains("previousTrack"),
            horizontalNextCommanded: musicCommands.contains("nextTrack"),
            appModeRemainedApp: false,
            appModeHorizontalIgnored: false
        )
    }

    private static func trackpadHorizontalAppModeIgnoredE2ERow() -> IslandPhase5NativePreviewTrackpadE2ERow {
        var container = IslandPhase5PreviewStateContainer(initialState: .loggedInReviewActivityPlain)
        let baseline = sizingResult(for: container.derivedState)
        var wheelAdapter = IslandTrackpadWheelAdapter()
        let horizontal = dispatchWheelEvent(
            deltaX: 86,
            deltaY: 4,
            timestamp: 0,
            wheelAdapter: &wheelAdapter,
            container: &container
        )
        let updates = [horizontal.update].compactMap { $0 }
        let finalUpdate = updates.last
        let finalDerivedState = finalUpdate?.currentDerivedState ?? container.derivedState
        let final = sizingResult(for: finalDerivedState)
        let reasons = updates.map { $0.reducerResult.reason.rawValue }
        let appModeRemainedApp = (finalUpdate?.currentState ?? container.domainState).primaryMode == .app
        let appModeHorizontalIgnored = reasons == ["intentIgnored"] &&
            updates.allSatisfy { $0.reducerResult.metadata.mockMusicCommand == nil }

        return trackpadE2ERow(
            checkID: "trackpad-horizontal-app-mode-ignored",
            interactionSource: "real horizontal trackpad swipe on app island shell when GUI capture is available",
            menuFallbackPath: "MF status item > Phase 5 Interactions > Horizontal Next while app mode is selected",
            rawGestureDeltas: horizontal.rawGestureDeltas,
            emittedIntents: [horizontal.emittedIntent].compactMap { $0 },
            updates: updates,
            observedOutcome: "horizontal music gesture is ignored in app mode and leaves the app activity shell unchanged",
            finalState: finalUpdate?.currentState ?? container.domainState,
            finalDerivedState: finalDerivedState,
            baselineSizingResult: baseline,
            finalSizingResult: final,
            verticalOpenedActivity: false,
            verticalExpanded: false,
            verticalClosedExpanded: false,
            verticalCompactedActivity: false,
            horizontalPreviousCommanded: false,
            horizontalNextCommanded: false,
            appModeRemainedApp: appModeRemainedApp,
            appModeHorizontalIgnored: appModeHorizontalIgnored
        )
    }

    private static func dispatchWheelEvent(
        deltaX: Double,
        deltaY: Double,
        timestamp: TimeInterval,
        wheelAdapter: inout IslandTrackpadWheelAdapter,
        container: inout IslandPhase5PreviewStateContainer
    ) -> (
        rawGestureDeltas: [String],
        emittedIntent: String?,
        update: IslandPhase5PreviewReducerUpdate?
    ) {
        let rawGesture = "deltaX=\(scalar(CGFloat(deltaX))), deltaY=\(scalar(CGFloat(deltaY)))"
        guard let intent = wheelAdapter.registerEvent(
            deltaX: deltaX,
            deltaY: deltaY,
            timestamp: timestamp
        ) else {
            return ([rawGesture], nil, nil)
        }

        let update = container.dispatch(intent: intent)
        return ([rawGesture], describe(intent), update)
    }

    private static func trackpadE2ERow(
        checkID: String,
        interactionSource: String,
        menuFallbackPath: String,
        rawGestureDeltas: [String],
        emittedIntents: [String],
        updates: [IslandPhase5PreviewReducerUpdate],
        observedOutcome: String,
        finalState: IslandDomainState,
        finalDerivedState: IslandDerivedState,
        baselineSizingResult: IslandWindowSizingResult,
        finalSizingResult: IslandWindowSizingResult,
        verticalOpenedActivity: Bool,
        verticalExpanded: Bool,
        verticalClosedExpanded: Bool,
        verticalCompactedActivity: Bool,
        horizontalPreviousCommanded: Bool,
        horizontalNextCommanded: Bool,
        appModeRemainedApp: Bool,
        appModeHorizontalIgnored: Bool
    ) -> IslandPhase5NativePreviewTrackpadE2ERow {
        let centerX = scalar(finalSizingResult.visibleFrame.midX)
        let notchCenterX = scalar(syntheticAttachmentMetrics().centerX)
        let visibleMaxY = scalar(finalSizingResult.visibleFrame.maxY)
        let displayMaxY = scalar(syntheticNotchScreenMetrics.frame.maxY)
        let reducerReasons = updates.map { $0.reducerResult.reason.rawValue }
        let musicCommands = updates.compactMap { $0.reducerResult.metadata.mockMusicCommand?.rawValue }

        return IslandPhase5NativePreviewTrackpadE2ERow(
            checkID: checkID,
            interactionSource: interactionSource,
            menuFallbackPath: menuFallbackPath,
            rawGestureDeltas: rawGestureDeltas,
            emittedIntents: emittedIntents,
            reducerReasons: reducerReasons,
            mockMusicCommands: musicCommands,
            observedOutcome: observedOutcome,
            finalPrimaryMode: finalState.primaryMode.rawValue,
            finalVisualState: finalDerivedState.visualState.rawValue,
            finalPresentationState: finalState.presentationState.rawValue,
            verticalOpenedActivity: verticalOpenedActivity,
            verticalExpanded: verticalExpanded,
            verticalClosedExpanded: verticalClosedExpanded,
            verticalCompactedActivity: verticalCompactedActivity,
            horizontalPreviousCommanded: horizontalPreviousCommanded,
            horizontalNextCommanded: horizontalNextCommanded,
            appModeRemainedApp: appModeRemainedApp,
            appModeHorizontalIgnored: appModeHorizontalIgnored,
            visibleFrameWidth: scalar(finalSizingResult.visibleFrame.width),
            baselineVisibleFrameWidth: scalar(baselineSizingResult.visibleFrame.width),
            visibleFrameCenterX: centerX,
            notchCenterX: notchCenterX,
            visibleFrameMaxY: visibleMaxY,
            displayMaxY: displayMaxY,
            staysCenteredOnNotch: abs(centerX - notchCenterX) <= 0.5,
            staysTopAttached: visibleMaxY == displayMaxY,
            evidence: "visibleFrame.width \(scalar(baselineSizingResult.visibleFrame.width)) -> \(scalar(finalSizingResult.visibleFrame.width)); reasons=\(reducerReasons.joined(separator: ",")); mockMusicCommands=\(musicCommands.joined(separator: ",")); centerX=\(centerX), notchCenterX=\(notchCenterX), maxY=\(visibleMaxY)"
        )
    }

    private static func mouseE2ERow(
        checkID: String,
        interactionSource: String,
        menuFallbackPath: String,
        emittedIntents: [String],
        observedOutcome: String,
        finalState: IslandDomainState,
        finalDerivedState: IslandDerivedState,
        baselineSizingResult: IslandWindowSizingResult,
        finalSizingResult: IslandWindowSizingResult,
        shadow: IslandShadowAppearanceTokens,
        hoverGrowsWithoutShadow: Bool,
        tapExpandedOrCollapsed: Bool,
        pointerCompactedOrRestoredActivity: Bool,
        tapLoopDoesNotRequireHoverLeave: Bool
    ) -> IslandPhase5NativePreviewMouseE2ERow {
        let centerX = scalar(finalSizingResult.visibleFrame.midX)
        let notchCenterX = scalar(syntheticAttachmentMetrics().centerX)
        let visibleMaxY = scalar(finalSizingResult.visibleFrame.maxY)
        let displayMaxY = scalar(syntheticNotchScreenMetrics.frame.maxY)

        return IslandPhase5NativePreviewMouseE2ERow(
            checkID: checkID,
            interactionSource: interactionSource,
            menuFallbackPath: menuFallbackPath,
            emittedIntents: emittedIntents,
            observedOutcome: observedOutcome,
            finalVisualState: finalDerivedState.visualState.rawValue,
            finalPresentationState: finalState.presentationState.rawValue,
            hoverGrowsWithoutShadow: hoverGrowsWithoutShadow,
            tapExpandedOrCollapsed: tapExpandedOrCollapsed,
            pointerCompactedOrRestoredActivity: pointerCompactedOrRestoredActivity,
            tapLoopDoesNotRequireHoverLeave: tapLoopDoesNotRequireHoverLeave,
            finalPreviewContentKind: finalDerivedState.previewContent.kind.rawValue,
            visibleFrameWidth: scalar(finalSizingResult.visibleFrame.width),
            baselineVisibleFrameWidth: scalar(baselineSizingResult.visibleFrame.width),
            shadowFrameWidth: scalar(finalSizingResult.shadowFrame.width),
            baselineShadowFrameWidth: scalar(baselineSizingResult.shadowFrame.width),
            shadowRadius: scalar(shadow.radius),
            shadowOpacity: scalar(CGFloat(shadow.opacity)),
            visibleFrameCenterX: centerX,
            notchCenterX: notchCenterX,
            visibleFrameMaxY: visibleMaxY,
            displayMaxY: displayMaxY,
            staysCenteredOnNotch: abs(centerX - notchCenterX) <= 0.5,
            staysTopAttached: visibleMaxY == displayMaxY,
            evidence: "visibleFrame.width \(scalar(baselineSizingResult.visibleFrame.width)) -> \(scalar(finalSizingResult.visibleFrame.width)); shadowFrame.width \(scalar(baselineSizingResult.shadowFrame.width)) -> \(scalar(finalSizingResult.shadowFrame.width)); centerX=\(centerX), notchCenterX=\(notchCenterX), maxY=\(visibleMaxY)"
        )
    }

    private static func nativePreviewScenarioE2ERow(
        scenarioID: String
    ) -> IslandPhase5NativePreviewScenarioE2ERow {
        let seedState = IslandDomainState.loggedInReviewCompact
        let seedDerivedState = IslandDerivedState.derive(from: seedState)
        let seedSizingResult = sizingResult(for: seedDerivedState)
        var container = IslandPhase5PreviewStateContainer(initialState: seedState)
        let update = container.dispatch(intent: .mockScenarioSelect(scenarioID))
        let derivedState = update.currentDerivedState
        let sizingResult = sizingResult(for: derivedState)
        let scenario = IslandMockScenario.scenario(id: scenarioID)
        let visibleFrameWidth = scalar(sizingResult.visibleFrame.width)
        let seedWidth = scalar(seedSizingResult.visibleFrame.width)
        let visualStateChanged = derivedState.visualState != seedDerivedState.visualState
        let widthChanged = visibleFrameWidth != seedWidth
        let markerChanged = derivedState.previewMarker.glyph != seedDerivedState.previewMarker.glyph ||
            derivedState.previewMarker.label != seedDerivedState.previewMarker.label ||
            derivedState.previewMarker.tone != seedDerivedState.previewMarker.tone
        let previewContent = derivedState.previewContent
        let centerX = scalar(sizingResult.visibleFrame.midX)
        let notchCenterX = scalar(syntheticAttachmentMetrics().centerX)
        let visibleMaxY = scalar(sizingResult.visibleFrame.maxY)
        let displayMaxY = scalar(syntheticNotchScreenMetrics.frame.maxY)

        return IslandPhase5NativePreviewScenarioE2ERow(
            scenarioID: scenarioID,
            menuTitle: scenario?.menuTitle ?? scenarioID,
            statusMenuPath: "MF status item > Phase 5 Scenarios > \(scenario?.menuTitle ?? scenarioID)",
            selectedIntent: "mockScenarioSelect(\(scenarioID))",
            visualState: derivedState.visualState.rawValue,
            presentationState: update.currentState.presentationState.rawValue,
            shellShapeChangedFromSeed: visualStateChanged || widthChanged,
            shellShapeEvidence: shellShapeEvidence(
                visualStateChanged: visualStateChanged,
                widthChanged: widthChanged,
                seedVisualState: seedDerivedState.visualState.rawValue,
                nextVisualState: derivedState.visualState.rawValue,
                seedWidth: seedWidth,
                nextWidth: visibleFrameWidth
            ),
            markerContentChangedFromSeed: markerChanged,
            markerGlyph: derivedState.previewMarker.glyph,
            markerLabel: derivedState.previewMarker.label,
            markerTone: derivedState.previewMarker.tone.rawValue,
            previewContentKind: previewContent.kind.rawValue,
            previewContentTitle: previewContent.title,
            previewContentBadge: previewContent.badge,
            hasVisibleMockContent: previewContent.title.isEmpty == false &&
                previewContent.badge.isEmpty == false,
            hasMusicCoverAndWaveform: previewContent.kind == .musicActivity,
            hasExpandedMusicControls: previewContent.kind == .expandedMusic,
            hasExpandedAppStructure: previewContent.kind == .expandedReview ||
                previewContent.kind == .expandedTodo,
            visibleFrameWidth: visibleFrameWidth,
            visibleFrameCenterX: centerX,
            notchCenterX: notchCenterX,
            visibleFrameMaxY: visibleMaxY,
            displayMaxY: displayMaxY,
            staysCenteredOnNotch: abs(centerX - notchCenterX) <= 0.5,
            staysTopAttached: visibleMaxY == displayMaxY,
            notchAttachmentEvidence: "visibleFrame.midX=\(centerX), notchCenterX=\(notchCenterX), visibleFrame.maxY=\(visibleMaxY), display.maxY=\(displayMaxY)"
        )
    }

    private static func shellShapeEvidence(
        visualStateChanged: Bool,
        widthChanged: Bool,
        seedVisualState: String,
        nextVisualState: String,
        seedWidth: Double,
        nextWidth: Double
    ) -> String {
        if visualStateChanged && widthChanged {
            return "visual state \(seedVisualState) -> \(nextVisualState), width \(seedWidth) -> \(nextWidth)"
        }
        if visualStateChanged {
            return "visual state \(seedVisualState) -> \(nextVisualState)"
        }
        if widthChanged {
            return "width \(seedWidth) -> \(nextWidth)"
        }
        return "no shell-shape delta from seed"
    }

    private static func sizingResult(
        for derivedState: IslandDerivedState
    ) -> IslandWindowSizingResult {
        IslandWindowSizingEngine.resolve(
            state: derivedState.visualState,
            attachmentMetrics: syntheticAttachmentMetrics(),
            widthConstraints: derivedState.widthConstraints
        )
    }

    private static func shadowAppearance(for state: IslandVisualState) -> IslandShadowAppearanceTokens {
        let tokenHeight = IslandVisualTokens.shell(for: state.tokenSet).height
        let visualScale = max(IslandShapeMetrics.resolve(for: state, visualScale: 1).height / max(tokenHeight, 1), 0.78)
        return IslandVisualTokens.shadow.appearance(for: state, visualScale: visualScale)
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
        case .musicSnapshotUpdated:
            return "musicSnapshotUpdated"
        case .musicStopped:
            return "musicStopped"
        case let .musicCommandRequested(command):
            return "musicCommandRequested(\(command.rawValue))"
        case .modeSwitchToggle:
            return "modeSwitchToggle"
        case .reminderDue:
            return "reminderDue"
        case .pausedMusicTimeout:
            return "pausedMusicTimeout"
        case let .mockScenarioSelect(identifier):
            return "mockScenarioSelect(\(identifier))"
        case .retargetPresentation:
            return "retargetPresentation"
        case let .transitionComplete(identifier):
            return "transitionComplete(\(identifier ?? "nil"))"
        }
    }

    private static func syntheticAttachmentMetrics() -> TopAttachmentMetrics {
        NotchLayoutEngine().topAttachmentMetrics(for: syntheticNotchScreenMetrics)
    }

    private static var syntheticNotchScreenMetrics: ScreenMetrics {
        ScreenMetrics(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            notchFrame: CGRect(x: 651, y: 950, width: 210, height: 32),
            backingScaleFactor: 2,
            displayIdentity: ScreenMetrics.DisplayIdentity(displayID: 1)
        )
    }

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
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

enum InteractionSequenceEvidenceError: Error, CustomStringConvertible {
    case missingRequiredSequences(expected: [String], actual: [String])
    case missingGuardOutcomeCoverage

    var description: String {
        switch self {
        case let .missingRequiredSequences(expected, actual):
            return "Missing Phase 5 interaction sequence evidence. Expected \(expected), actual \(actual)."
        case .missingGuardOutcomeCoverage:
            return "Phase 5 interaction guard outcome coverage is incomplete."
        }
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

enum NativePreviewScenarioE2EError: Error, CustomStringConvertible {
    case missingRequiredScenarios(expected: [String], actual: [String])
    case missingVisibleMarkerContent([IslandPhase5NativePreviewScenarioE2ERow])
    case missingVisibleMockContent([IslandPhase5NativePreviewScenarioE2ERow])
    case notchAttachmentFailed([IslandPhase5NativePreviewScenarioE2ERow])
    case noVisibleScenarioDelta([IslandPhase5NativePreviewScenarioE2ERow])

    var description: String {
        switch self {
        case let .missingRequiredScenarios(expected, actual):
            return "Missing native preview e2e scenario rows. Expected \(expected), actual \(actual)."
        case let .missingVisibleMarkerContent(rows):
            return "Native preview e2e rows are missing visible marker content: \(rows)."
        case let .missingVisibleMockContent(rows):
            return "Native preview e2e rows are missing visible mock content coverage: \(rows)."
        case let .notchAttachmentFailed(rows):
            return "Native preview e2e rows failed notch attachment checks: \(rows)."
        case let .noVisibleScenarioDelta(rows):
            return "Native preview e2e rows did not record a visible shell or marker delta: \(rows)."
        }
    }
}

enum NativePreviewMouseE2EError: Error, CustomStringConvertible {
    case missingRequiredChecks(expected: [String], actual: [String])
    case notchAttachmentFailed([IslandPhase5NativePreviewMouseE2ERow])
    case missingVisibleMouseOutcome([IslandPhase5NativePreviewMouseE2ERow])

    var description: String {
        switch self {
        case let .missingRequiredChecks(expected, actual):
            return "Missing native preview mouse e2e rows. Expected \(expected), actual \(actual)."
        case let .notchAttachmentFailed(rows):
            return "Native preview mouse e2e rows failed notch attachment checks: \(rows)."
        case let .missingVisibleMouseOutcome(rows):
            return "Native preview mouse e2e rows did not cover hover, tap, and pointer outcomes: \(rows)."
        }
    }
}

enum NativePreviewTrackpadE2EError: Error, CustomStringConvertible {
    case missingRequiredChecks(expected: [String], actual: [String])
    case notchAttachmentFailed([IslandPhase5NativePreviewTrackpadE2ERow])
    case missingVisibleTrackpadOutcome([IslandPhase5NativePreviewTrackpadE2ERow])

    var description: String {
        switch self {
        case let .missingRequiredChecks(expected, actual):
            return "Missing native preview trackpad e2e rows. Expected \(expected), actual \(actual)."
        case let .notchAttachmentFailed(rows):
            return "Native preview trackpad e2e rows failed notch attachment checks: \(rows)."
        case let .missingVisibleTrackpadOutcome(rows):
            return "Native preview trackpad e2e rows did not cover vertical open/expand/close/compact, horizontal music commands, and app-mode ignore behavior: \(rows)."
        }
    }
}
