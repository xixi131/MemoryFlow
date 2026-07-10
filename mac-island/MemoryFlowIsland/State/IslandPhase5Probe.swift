import CoreGraphics
import Foundation

struct IslandPhase5ScenarioProbeRow: Codable, Equatable {
    let scenarioID: String
    let menuTitle: String
    let domainState: IslandPhase5ScenarioDomainStateEvidence
    let derivedState: IslandPhase5ScenarioDerivedStateEvidence
    let visualState: IslandPhase5ScenarioVisualStateEvidence
    let width: IslandPhase5ScenarioWidthEvidence
    let expectedTransitionMetadata: IslandPhase5ScenarioTransitionMetadata
    let expectedVisualState: String
    let derivedVisualState: String
    let collapsedWidth: Double
    let primaryMode: String
    let presentationState: String
    let hasAnyActivitySource: Bool
    let showAnyActivity: Bool
    let showReminder: Bool
    let showTodoActivity: Bool
    let showMusicActivity: Bool
    let contentWidthBranch: String
    let contentExtensionWidth: Double
    let previewMarkerGlyph: String
    let previewMarkerLabel: String
    let previewMarkerTone: String
    let markerContentExtensionWidth: Double
    let previewContentKind: String
    let previewContentTitle: String
    let previewContentBadge: String
    let previewContentSignature: String
    let previewContentExtensionWidth: Double
}

struct IslandPhase5ScenarioDomainStateEvidence: Codable, Equatable {
    let authState: String
    let primaryMode: String
    let appDisplayMode: String
    let presentationState: String
    let forceCompactMode: Bool
    let isHovered: Bool
    let gestureState: String
    let isModeSwitchLocked: Bool
    let isForceCompactLocked: Bool
    let isReminderActive: Bool
    let isReminderCollapsing: Bool
    let isGreetingActive: Bool
    let hasReviewMockSource: Bool
    let hasTodoMockSource: Bool
    let hasMusicMockSource: Bool
}

struct IslandPhase5ScenarioDerivedStateEvidence: Codable, Equatable {
    let hasMusicActivitySource: Bool
    let hasAppActivitySource: Bool
    let hasAnyActivitySource: Bool
    let showMusicActivity: Bool
    let showReviewActivity: Bool
    let showTodoActivity: Bool
    let showReminder: Bool
    let showAppActivity: Bool
    let showAnyActivity: Bool
    let isActivityVisualState: Bool
}

struct IslandPhase5ScenarioVisualStateEvidence: Codable, Equatable {
    let expected: String
    let derived: String
    let presentationState: String
    let primaryMode: String
}

struct IslandPhase5ScenarioWidthEvidence: Codable, Equatable {
    let collapsedWidth: Double
    let contentWidthBranch: String
    let contentExtensionWidth: Double
    let markerContentExtensionWidth: Double
}

struct IslandPhase5ScenarioTransitionMetadata: Codable, Equatable {
    let selectionIntent: String
    let expectedGuardOutcome: String
    let previousVisualState: String
    let expectedNextVisualState: String
    let expectedTransitionKind: String
    let expectedPresentationState: String
    let changesVisualState: Bool
}

struct IslandPhase5InteractionProbeStep: Codable, Equatable {
    let intent: String
    let guardOutcome: String
    let transitionKind: String
    let primaryMode: String
    let presentationState: String
    let forceCompactMode: Bool
    let gestureState: String
    let visualState: String
}

struct IslandPhase5InteractionProbeRow: Codable, Equatable {
    let sequenceID: String
    let initialVisualState: String
    let steps: [IslandPhase5InteractionProbeStep]
}

struct IslandPhase5InteractionDemoProbeRow: Codable, Equatable {
    let controlID: String
    let menuTitle: String
    let intent: String
    let menuGuardOutcome: String
    let reducerGuardOutcome: String
    let menuFinalVisualState: String
    let reducerFinalVisualState: String
    let menuFinalPresentationState: String
    let reducerFinalPresentationState: String
    let menuFinalForceCompactMode: Bool
    let reducerFinalForceCompactMode: Bool
    let menuFinalGestureState: String
    let reducerFinalGestureState: String
    let matchesReducerSequence: Bool
}

struct IslandPhase5PreviewMarkerLayoutProbeRow: Codable, Equatable {
    let scenarioID: String
    let markerGlyph: String
    let markerTone: String
    let visualState: String
    let contentWidthBranch: String
    let contentExtensionWidth: Double
    let layoutInputContentExtensionWidth: Double
    let sizingContentExtensionWidth: Double
    let markerContentExtensionWidth: Double
    let visibleFrameWidth: Double
    let visibleFrameCenterX: Double
    let notchCenterX: Double
    let visibleFrameMaxY: Double
    let displayMaxY: Double
}

enum IslandPhase5Probe {
    static func scenarioRows() -> [IslandPhase5ScenarioProbeRow] {
        IslandMockScenario.phase5Catalog.map { scenario in
            let derivedState = IslandDerivedState.derive(from: scenario.initialState)
            let transitionMetadata = scenarioTransitionMetadata(
                for: scenario,
                derivedState: derivedState
            )

            return IslandPhase5ScenarioProbeRow(
                scenarioID: scenario.id,
                menuTitle: scenario.menuTitle,
                domainState: domainStateEvidence(for: scenario.initialState),
                derivedState: derivedStateEvidence(for: derivedState),
                visualState: IslandPhase5ScenarioVisualStateEvidence(
                    expected: scenario.expectedDerivedVisualState.rawValue,
                    derived: derivedState.visualState.rawValue,
                    presentationState: scenario.initialState.presentationState.rawValue,
                    primaryMode: scenario.initialState.primaryMode.rawValue
                ),
                width: IslandPhase5ScenarioWidthEvidence(
                    collapsedWidth: scalar(derivedState.collapsedWidth),
                    contentWidthBranch: derivedState.contentWidthBranch.rawValue,
                    contentExtensionWidth: scalar(
                        derivedState.contentWidthRequirement.requiredExtensionWidth
                    ),
                    markerContentExtensionWidth: scalar(
                        derivedState.previewMarker.contentWidthRequirement.requiredExtensionWidth
                    )
                ),
                expectedTransitionMetadata: transitionMetadata,
                expectedVisualState: scenario.expectedDerivedVisualState.rawValue,
                derivedVisualState: derivedState.visualState.rawValue,
                collapsedWidth: scalar(derivedState.collapsedWidth),
                primaryMode: scenario.initialState.primaryMode.rawValue,
                presentationState: scenario.initialState.presentationState.rawValue,
                hasAnyActivitySource: derivedState.hasAnyActivitySource,
                showAnyActivity: derivedState.showAnyActivity,
                showReminder: derivedState.showReminder,
                showTodoActivity: derivedState.showTodoActivity,
                showMusicActivity: derivedState.showMusicActivity,
                contentWidthBranch: derivedState.contentWidthBranch.rawValue,
                contentExtensionWidth: scalar(
                    derivedState.contentWidthRequirement.requiredExtensionWidth
                ),
                previewMarkerGlyph: derivedState.previewMarker.glyph,
                previewMarkerLabel: derivedState.previewMarker.label,
                previewMarkerTone: derivedState.previewMarker.tone.rawValue,
                markerContentExtensionWidth: scalar(
                    derivedState.previewMarker.contentWidthRequirement.requiredExtensionWidth
                ),
                previewContentKind: derivedState.previewContent.kind.rawValue,
                previewContentTitle: derivedState.previewContent.title,
                previewContentBadge: derivedState.previewContent.badge,
                previewContentSignature: previewContentSignature(for: derivedState.previewContent),
                previewContentExtensionWidth: scalar(
                    derivedState.previewContent.contentWidthRequirement.requiredExtensionWidth
                )
            )
        }
    }

    @discardableResult
    static func validateScenarioRows() throws -> [IslandPhase5ScenarioProbeRow] {
        let rows = scenarioRows()
        let ids = rows.map { (row: IslandPhase5ScenarioProbeRow) -> String in
            row.scenarioID
        }

        guard Set(ids).count == IslandMockScenario.phase5Catalog.count else {
            throw IslandPhase5ProbeValidationError.duplicateScenarioIDs(ids)
        }

        guard rows.count == IslandMockScenario.phase5Catalog.count else {
            throw IslandPhase5ProbeValidationError.unexpectedScenarioCount(
                expected: IslandMockScenario.phase5Catalog.count,
                actual: rows.count
            )
        }

        let requiredScenarioIDs: Set<String> = [
            "logged-out-compact",
            "logged-in-review-compact",
            "greeting",
            "review-activity",
            "todo-activity",
            "music-playing",
            "music-paused",
            "expanded-review",
            "expanded-todo",
            "expanded-music",
            "reminder-due",
            "music-stopped-fallback"
        ]
        guard Set(ids) == requiredScenarioIDs else {
            throw IslandPhase5ProbeValidationError.missingRequiredScenarioIDs(
                expected: requiredScenarioIDs.sorted(),
                actual: ids
            )
        }

        let mismatchedVisualStates = rows.filter { $0.expectedVisualState != $0.derivedVisualState }
        guard mismatchedVisualStates.isEmpty else {
            throw IslandPhase5ProbeValidationError.unexpectedScenarioRows(mismatchedVisualStates)
        }

        let invalidWidths = rows.filter { $0.collapsedWidth <= 0 }
        guard invalidWidths.isEmpty else {
            throw IslandPhase5ProbeValidationError.invalidScenarioWidths(invalidWidths)
        }

        let incompleteEvidenceRows = rows.filter {
            $0.domainState.presentationState.isEmpty ||
                $0.derivedState.showAnyActivity != $0.showAnyActivity ||
                $0.visualState.derived != $0.derivedVisualState ||
                $0.width.collapsedWidth != $0.collapsedWidth ||
                $0.expectedTransitionMetadata.selectionIntent !=
                    "mockScenarioSelect(\($0.scenarioID))" ||
                $0.expectedTransitionMetadata.expectedGuardOutcome !=
                    IslandPresentationTransitionReason.mockScenarioSelected.rawValue
        }
        guard incompleteEvidenceRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.incompleteScenarioEvidence(incompleteEvidenceRows)
        }

        let requiredMarkerRows = rows.filter {
            [
                "logged-out-compact",
                "logged-in-review-compact",
                "todo-activity",
                "music-playing",
                "reminder-due"
            ].contains($0.scenarioID)
        }
        guard requiredMarkerRows.allSatisfy({ $0.previewMarkerGlyph.isEmpty == false }) else {
            throw IslandPhase5ProbeValidationError.missingPreviewMarkers(requiredMarkerRows)
        }

        let requiredMarkerTones = Set(
            requiredMarkerRows.map { (row: IslandPhase5ScenarioProbeRow) -> String in
                row.previewMarkerTone
            }
        )
        let expectedMarkerTones: Set<String> = [
            IslandPreviewContentMarker.Tone.signedOut.rawValue,
            IslandPreviewContentMarker.Tone.review.rawValue,
            IslandPreviewContentMarker.Tone.todo.rawValue,
            IslandPreviewContentMarker.Tone.music.rawValue,
            IslandPreviewContentMarker.Tone.reminder.rawValue
        ]
        guard requiredMarkerTones == expectedMarkerTones else {
            throw IslandPhase5ProbeValidationError.unexpectedPreviewMarkerTones(
                expected: expectedMarkerTones.sorted(),
                actual: requiredMarkerTones.sorted()
            )
        }

        let expectedContentBranches: Set<String> = [
            IslandMockContentWidthBranch.review.rawValue,
            IslandMockContentWidthBranch.todo.rawValue,
            IslandMockContentWidthBranch.music.rawValue,
            IslandMockContentWidthBranch.compact.rawValue
        ]
        let contentBranches = Set(
            rows.map { (row: IslandPhase5ScenarioProbeRow) -> String in
                row.contentWidthBranch
            }
        )
        guard expectedContentBranches.isSubset(of: contentBranches) else {
            throw IslandPhase5ProbeValidationError.missingContentWidthBranches(
                expected: expectedContentBranches.sorted(),
                actual: contentBranches.sorted()
            )
        }

        let gestureLockState = gestureLockPreviewState()
        let gestureLockMarker = IslandDerivedState.derive(from: gestureLockState).previewMarker
        guard gestureLockMarker.tone == .gestureLock,
              gestureLockMarker.glyph.isEmpty == false,
              gestureLockMarker.contentWidthRequirement.requiredExtensionWidth > 0 else {
            throw IslandPhase5ProbeValidationError.missingGestureLockPreviewMarker
        }

        let invalidMarkerWidths = requiredMarkerRows.filter { $0.markerContentExtensionWidth <= 0 }
        guard invalidMarkerWidths.isEmpty else {
            throw IslandPhase5ProbeValidationError.invalidPreviewMarkerWidths(invalidMarkerWidths)
        }

        let missingPreviewContentRows = rows.filter {
            $0.previewContentKind.isEmpty ||
                $0.previewContentTitle.isEmpty ||
                $0.previewContentBadge.isEmpty ||
                $0.previewContentSignature.isEmpty ||
                $0.previewContentExtensionWidth <= 0
        }
        guard missingPreviewContentRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.missingPreviewContent(missingPreviewContentRows)
        }

        let distinctContentSignatures = Set(rows.map(\.previewContentSignature))
        guard distinctContentSignatures.count == rows.count else {
            throw IslandPhase5ProbeValidationError.previewContentNotDistinct(rows)
        }

        let invalidMockPayloads = IslandMockScenario.phase5Catalog.filter { scenario in
            let sources = scenario.initialState.mockSources
            switch scenario.id {
            case "review-activity", "expanded-review", "music-stopped-fallback":
                return sources.review?.subjectTitles.isEmpty != false
            case "todo-activity", "expanded-todo":
                return sources.todo?.tasks.count != 6
            case "reminder-due":
                return sources.reminder?.timeText.isEmpty != false || sources.reminder?.isDue != true
            case "music-playing":
                return sources.music?.playbackStatus != .playing ||
                    sources.music?.artworkPlaceholder.isEmpty != false
            case "music-paused":
                return sources.music?.playbackStatus != .paused ||
                    sources.music?.artworkPlaceholder.isEmpty != false
            case "expanded-music":
                return sources.music?.playbackStatus != .playing
            default:
                return false
            }
        }
        guard invalidMockPayloads.isEmpty else {
            throw IslandPhase5ProbeValidationError.invalidMockScenarioPayloads(
                invalidMockPayloads.map(\.id)
            )
        }

        return rows
    }

    private static func domainStateEvidence(
        for state: IslandDomainState
    ) -> IslandPhase5ScenarioDomainStateEvidence {
        IslandPhase5ScenarioDomainStateEvidence(
            authState: state.authState.rawValue,
            primaryMode: state.primaryMode.rawValue,
            appDisplayMode: state.appDisplayMode.rawValue,
            presentationState: state.presentationState.rawValue,
            forceCompactMode: state.forceCompactMode,
            isHovered: state.isHovered,
            gestureState: state.gestureState.rawValue,
            isModeSwitchLocked: state.isModeSwitchLocked,
            isForceCompactLocked: state.isForceCompactLocked,
            isReminderActive: state.isReminderActive,
            isReminderCollapsing: state.isReminderCollapsing,
            isGreetingActive: state.isGreetingActive,
            hasReviewMockSource: state.mockSources.review != nil,
            hasTodoMockSource: state.mockSources.todo != nil,
            hasMusicMockSource: state.mockSources.music != nil
        )
    }

    private static func derivedStateEvidence(
        for derivedState: IslandDerivedState
    ) -> IslandPhase5ScenarioDerivedStateEvidence {
        IslandPhase5ScenarioDerivedStateEvidence(
            hasMusicActivitySource: derivedState.hasMusicActivitySource,
            hasAppActivitySource: derivedState.hasAppActivitySource,
            hasAnyActivitySource: derivedState.hasAnyActivitySource,
            showMusicActivity: derivedState.showMusicActivity,
            showReviewActivity: derivedState.showReviewActivity,
            showTodoActivity: derivedState.showTodoActivity,
            showReminder: derivedState.showReminder,
            showAppActivity: derivedState.showAppActivity,
            showAnyActivity: derivedState.showAnyActivity,
            isActivityVisualState: derivedState.isActivityVisualState
        )
    }

    private static func previewContentSignature(for content: IslandPreviewContent) -> String {
        [content.kind.rawValue, content.title, content.subtitle, content.badge].joined(separator: "|")
    }

    private static func scenarioTransitionMetadata(
        for scenario: IslandMockScenario,
        derivedState: IslandDerivedState
    ) -> IslandPhase5ScenarioTransitionMetadata {
        let seedVisualState = IslandDerivedState
            .derive(from: IslandDomainState.loggedInReviewCompact)
            .visualState
        let presentationChange = presentationChangeKind(
            previous: seedVisualState,
            next: derivedState.visualState,
            reason: .mockScenarioSelected
        )

        return IslandPhase5ScenarioTransitionMetadata(
            selectionIntent: "mockScenarioSelect(\(scenario.id))",
            expectedGuardOutcome: IslandPresentationTransitionReason.mockScenarioSelected.rawValue,
            previousVisualState: seedVisualState.rawValue,
            expectedNextVisualState: scenario.expectedDerivedVisualState.rawValue,
            expectedTransitionKind: presentationChange,
            expectedPresentationState: scenario.initialState.presentationState.rawValue,
            changesVisualState: seedVisualState != derivedState.visualState
        )
    }

    private static func presentationChangeKind(
        previous: IslandVisualState,
        next: IslandVisualState,
        reason: IslandPresentationTransitionReason
    ) -> String {
        switch reason {
        case .hoverEntered:
            return "hoverEnter"
        case .hoverLeft:
            return "hoverLeave"
        default:
            break
        }

        switch (previous, next) {
        case (.compactCollapsed, .activityCollapsed):
            return "compactToActivity"
        case (.activityCollapsed, .compactCollapsed):
            return "activityToCompact"
        case (.compactCollapsed, .expandedMusic),
             (.compactCollapsed, .expandedApp),
             (.hoverCollapsed, .expandedMusic),
             (.hoverCollapsed, .expandedApp):
            return "compactToExpanded"
        case (.activityCollapsed, .expandedMusic), (.activityCollapsed, .expandedApp):
            return "activityToExpanded"
        case (.expandedMusic, .activityCollapsed), (.expandedApp, .activityCollapsed):
            return "expandedToActivity"
        case (.expandedMusic, .compactCollapsed),
             (.expandedMusic, .hoverCollapsed),
             (.expandedApp, .compactCollapsed),
             (.expandedApp, .hoverCollapsed):
            return "expandedToCompact"
        case (.expandedMusic, .expandedApp), (.expandedApp, .expandedMusic):
            return "expandedToExpanded"
        case (.activityCollapsed, .activityCollapsed):
            return "activityContentChanged"
        default:
            return "noVisualChange"
        }
    }

    private static func gestureLockPreviewState() -> IslandDomainState {
        var state = IslandDomainState.loggedInReviewActivityPlain
        state.gestureState = .cooldown
        return state
    }

    @discardableResult
    static func validatePreviewMarkerLayoutRows() throws -> [IslandPhase5PreviewMarkerLayoutProbeRow] {
        let rows = IslandPhase5PreviewMarkerLayoutProbe.rows()

        guard rows.allSatisfy({ $0.markerGlyph.isEmpty == false }) else {
            throw IslandPhase5ProbeValidationError.missingLayoutPreviewMarkers(rows)
        }

        guard rows.allSatisfy({
            $0.visualState == IslandVisualState.activityCollapsed.rawValue ||
                $0.contentExtensionWidth == 0
        }) else {
            throw IslandPhase5ProbeValidationError.compactWidthInflatedByContent(rows)
        }

        guard rows.allSatisfy({
            $0.contentExtensionWidth == $0.layoutInputContentExtensionWidth &&
                $0.contentExtensionWidth == $0.sizingContentExtensionWidth
        }) else {
            throw IslandPhase5ProbeValidationError.contentWidthNotRoutedThroughController(rows)
        }

        var branchWidths: [String: Double] = [:]
        for row in rows {
            let currentWidth = branchWidths[row.contentWidthBranch] ?? 0
            branchWidths[row.contentWidthBranch] = max(currentWidth, row.visibleFrameWidth)
        }
        let expectedBranchKeys: Set<String> = [
            IslandMockContentWidthBranch.review.rawValue,
            IslandMockContentWidthBranch.todo.rawValue,
            IslandMockContentWidthBranch.music.rawValue,
            IslandMockContentWidthBranch.greeting.rawValue,
            IslandMockContentWidthBranch.compact.rawValue
        ]
        guard expectedBranchKeys.isSubset(of: Set(branchWidths.keys)) else {
            throw IslandPhase5ProbeValidationError.missingContentWidthBranches(
                expected: expectedBranchKeys.sorted(),
                actual: branchWidths.keys.sorted()
            )
        }

        guard Set(branchWidths.values).count >= 2 else {
            throw IslandPhase5ProbeValidationError.activityWidthDidNotVaryByRequirement(rows)
        }

        let compactRows = rows.filter {
            $0.visualState == IslandVisualState.compactCollapsed.rawValue ||
                $0.visualState == IslandVisualState.hoverCollapsed.rawValue
        }
        guard compactRows.allSatisfy({ $0.contentExtensionWidth == 0 }) else {
            throw IslandPhase5ProbeValidationError.compactWidthInflatedByContent(compactRows)
        }

        guard rows.allSatisfy({ abs($0.visibleFrameCenterX - $0.notchCenterX) <= 0.5 }) else {
            throw IslandPhase5ProbeValidationError.shellNotCenteredAroundNotch(rows)
        }

        guard rows.allSatisfy({ $0.visibleFrameMaxY == $0.displayMaxY }) else {
            throw IslandPhase5ProbeValidationError.shellDetachedFromNotch(rows)
        }

        return rows
    }

    static func interactionRows() -> [IslandPhase5InteractionProbeRow] {
        interactionSequences.map { sequence in
            var currentState = sequence.initialState
            let initialDerivedState = IslandDerivedState.derive(from: currentState)
            let steps = sequence.intents.map { entry in
                let previousDerivedState = IslandDerivedState.derive(from: currentState)
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: entry.intent
                )
                currentState = result.state
                let derivedState = result.derivedState
                let presentationChange = presentationChangeKind(
                    previous: previousDerivedState.visualState,
                    next: derivedState.visualState,
                    reason: result.reason
                )

                return IslandPhase5InteractionProbeStep(
                    intent: entry.label,
                    guardOutcome: result.reason.rawValue,
                    transitionKind: presentationChange,
                    primaryMode: result.state.primaryMode.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    forceCompactMode: result.state.forceCompactMode,
                    gestureState: result.state.gestureState.rawValue,
                    visualState: derivedState.visualState.rawValue
                )
            }

            return IslandPhase5InteractionProbeRow(
                sequenceID: sequence.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    @discardableResult
    static func validateInteractionRows() throws -> [IslandPhase5InteractionProbeRow] {
        let rows = interactionRows()
        let ids = rows.map { (row: IslandPhase5InteractionProbeRow) -> String in
            row.sequenceID
        }
        let expectedInteractionIDs = interactionSequences.map { sequence in
            sequence.id
        }

        guard Set(ids) == Set(expectedInteractionIDs) else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionIDs(
                expected: expectedInteractionIDs,
                actual: ids
            )
        }

        let incompleteRows = rows.filter { $0.steps.isEmpty }
        guard incompleteRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.emptyInteractionRows(
                incompleteRows.map { (row: IslandPhase5InteractionProbeRow) -> String in
                    row.sequenceID
                }
            )
        }

        let missingVisualStates = rows.filter { row in
            row.steps.contains { $0.visualState.isEmpty }
        }
        guard missingVisualStates.isEmpty else {
            throw IslandPhase5ProbeValidationError.missingInteractionVisualState(
                missingVisualStates.map { (row: IslandPhase5InteractionProbeRow) -> String in
                    row.sequenceID
                }
            )
        }

        let expectedTransitionKinds: [String: [String]] = [
            "hover-enter-leave": [
                "hoverEnter",
                "hoverLeave"
            ],
            "tap-expand-collapse": [
                "compactToExpanded",
                "expandedToActivity"
            ],
            "pointer-compact-restore": [
                "activityToCompact",
                "noVisualChange",
                "compactToActivity"
            ],
            "trackpad-vertical-cycle": [
                "activityToCompact",
                "noVisualChange",
                "noVisualChange",
                "compactToActivity"
            ],
            "rapid-retargeting": [
                "compactToExpanded",
                "expandedToActivity",
                "activityToExpanded"
            ],
            "rapid-hover-tap-hover": [
                "hoverEnter",
                "compactToExpanded",
                "expandedToCompact"
            ],
            "tap-tap-trackpad": [
                "compactToExpanded",
                "expandedToActivity",
                "activityToCompact"
            ]
        ]
        let mismatchedTransitionKindRows = rows.filter { row in
            guard let expectedKinds = expectedTransitionKinds[row.sequenceID] else { return false }
            let actualKinds = row.steps.map { (step: IslandPhase5InteractionProbeStep) -> String in
                step.transitionKind
            }
            return actualKinds != expectedKinds
        }
        guard mismatchedTransitionKindRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionTransitionKinds(
                mismatchedTransitionKindRows
            )
        }

        return rows
    }

    static func interactionDemoRows() -> [IslandPhase5InteractionDemoProbeRow] {
        IslandPhase5InteractionDemoControl.allCases.map { control in
            let seedState = interactionDemoSeedState(for: control)
            var menuContainer = IslandPhase5PreviewStateContainer(initialState: seedState)
            let menuUpdate = menuContainer.dispatch(intent: control.intent)
            let reducerResult = IslandPresentationReducer.reduce(
                current: seedState,
                intent: control.intent
            )
            let reducerDerivedState = reducerResult.derivedState
            let menuCurrentState = menuUpdate.currentState
            let reducerCurrentState = reducerResult.state

            return IslandPhase5InteractionDemoProbeRow(
                controlID: control.rawValue,
                menuTitle: control.menuTitle,
                intent: describe(control.intent),
                menuGuardOutcome: menuUpdate.reducerResult.reason.rawValue,
                reducerGuardOutcome: reducerResult.reason.rawValue,
                menuFinalVisualState: menuUpdate.currentDerivedState.visualState.rawValue,
                reducerFinalVisualState: reducerDerivedState.visualState.rawValue,
                menuFinalPresentationState: menuCurrentState.presentationState.rawValue,
                reducerFinalPresentationState: reducerCurrentState.presentationState.rawValue,
                menuFinalForceCompactMode: menuCurrentState.forceCompactMode,
                reducerFinalForceCompactMode: reducerCurrentState.forceCompactMode,
                menuFinalGestureState: menuCurrentState.gestureState.rawValue,
                reducerFinalGestureState: reducerCurrentState.gestureState.rawValue,
                matchesReducerSequence: menuCurrentState == reducerCurrentState &&
                    menuUpdate.currentDerivedState == reducerDerivedState &&
                    menuUpdate.reducerResult.reason == reducerResult.reason
            )
        }
    }

    @discardableResult
    static func validateInteractionDemoRows() throws -> [IslandPhase5InteractionDemoProbeRow] {
        let rows = interactionDemoRows()
        let ids = rows.map { (row: IslandPhase5InteractionDemoProbeRow) -> String in
            row.controlID
        }
        let expectedIDs = IslandPhase5InteractionDemoControl.allCases.map { control in
            control.rawValue
        }

        guard ids == expectedIDs else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionDemoIDs(
                expected: expectedIDs,
                actual: ids
            )
        }

        let mismatchedRows = rows.filter { $0.matchesReducerSequence == false }
        guard mismatchedRows.isEmpty else {
            throw IslandPhase5ProbeValidationError.unexpectedInteractionDemoRows(mismatchedRows)
        }

        return rows
    }

    private static let interactionSequences: [(id: String, initialState: IslandDomainState, intents: [(intent: IslandInteractionIntent, label: String)])] = [
        (
            id: "hover-enter-leave",
            initialState: .loggedInReviewCompact,
            intents: [
                (.hoverEnter, "hoverEnter"),
                (.hoverLeave, "hoverLeave")
            ]
        ),
        (
            id: "tap-expand-collapse",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.outsideCollapse, "outsideCollapse")
            ]
        ),
        (
            id: "pointer-compact-restore",
            initialState: .loggedInReviewActivityPlain,
            intents: [
                (.pointerSwipe(.right), "pointerSwipe(right)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.pointerSwipe(.left), "pointerSwipe(left)")
            ]
        ),
        (
            id: "trackpad-vertical-cycle",
            initialState: .loggedInReviewActivityPlain,
            intents: [
                (.trackpadSwipe(.up), "trackpadSwipe(up)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown),
                    "transitionComplete(trackpadGestureCooldown)"
                ),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.trackpadSwipe(.down), "trackpadSwipe(down)")
            ]
        ),
        (
            id: "horizontal-music-command",
            initialState: .musicActivity,
            intents: [
                (.horizontalMusicCommand(.previousTrack), "horizontalMusicCommand(previousTrack)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.trackpadGestureCooldown),
                    "transitionComplete(trackpadGestureCooldown)"
                ),
                (.horizontalMusicCommand(.nextTrack), "horizontalMusicCommand(nextTrack)")
            ]
        ),
        (
            id: "reminder-due-open",
            initialState: .loggedInReviewCompact,
            intents: [
                (.reminderDue("phase5-reminder-due"), "reminderDue(phase5-reminder-due)")
            ]
        ),
        (
            id: "paused-music-timeout",
            initialState: .musicActivityWithAppFallback,
            intents: [
                (.pausedMusicTimeout, "pausedMusicTimeout")
            ]
        ),
        (
            id: "rapid-retargeting",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.outsideCollapse, "outsideCollapse"),
                (.tap, "tap")
            ]
        ),
        (
            id: "rapid-hover-tap-hover",
            initialState: .loggedInReviewCompact,
            intents: [
                (.hoverEnter, "hoverEnter"),
                (.tap, "tap"),
                (
                    .retargetPresentation(
                        IslandPresentationRetargetTarget(
                            presentationState: .collapsed,
                            forceCompactMode: true,
                            isHovered: true
                        )
                    ),
                    "retargetPresentation(hoverCollapsed)"
                )
            ]
        ),
        (
            id: "tap-tap-trackpad",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.tap, "tap"),
                (.trackpadSwipe(.up), "trackpadSwipe(up)")
            ]
        )
    ]

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private static func interactionDemoSeedState(
        for control: IslandPhase5InteractionDemoControl
    ) -> IslandDomainState {
        switch control {
        case .hoverEnter:
            return .loggedInReviewCompact
        case .hoverLeave:
            var state = IslandDomainState.loggedInReviewCompact
            state.isHovered = true
            return state
        case .tap:
            return .loggedInReviewCompact
        case .pointerSwipeLeft:
            return .loggedInReviewCompact
        case .pointerSwipeRight:
            return .loggedInReviewActivityPlain
        case .trackpadUp:
            return .loggedInReviewActivityPlain
        case .trackpadDown:
            return .loggedInReviewCompact
        case .horizontalPrevious, .horizontalNext:
            return .musicActivity
        case .modeSwitchToggle:
            return .loggedInReviewActivityPlain
        case .reminderDue:
            return .loggedInReviewCompact
        case .pausedMusicTimeout:
            return .musicActivityWithAppFallback
        case .greetingFastForward:
            return .mockGreetingCompact
        }
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
        case let .musicSnapshotUpdated(snapshot):
            return "musicSnapshotUpdated(\(snapshot.title))"
        case .musicStopped:
            return "musicStopped"
        case let .musicCommandRequested(command):
            return "musicCommandRequested(\(command.rawValue))"
        case .modeSwitchToggle:
            return "modeSwitchToggle"
        case .modeSwitchMutate:
            return "modeSwitchMutate"
        case let .reminderDue(key):
            return "reminderDue(\(key))"
        case .pausedMusicTimeout:
            return "pausedMusicTimeout"
        case .greetingLifecycleCompleted:
            return "greetingLifecycleCompleted"
        case .greetingFastForward:
            return "greetingFastForward"
        case let .mockScenarioSelect(scenarioID):
            return "mockScenarioSelect(\(scenarioID))"
        case .retargetPresentation:
            return "retargetPresentation"
        case let .transitionComplete(identifier):
            return "transitionComplete(\(identifier ?? "none"))"
        }
    }
}

enum IslandPhase5ProbeValidationError: Error, CustomStringConvertible {
    case duplicateScenarioIDs([String])
    case unexpectedScenarioCount(expected: Int, actual: Int)
    case missingRequiredScenarioIDs(expected: [String], actual: [String])
    case unexpectedScenarioRows([IslandPhase5ScenarioProbeRow])
    case invalidScenarioWidths([IslandPhase5ScenarioProbeRow])
    case incompleteScenarioEvidence([IslandPhase5ScenarioProbeRow])
    case unexpectedInteractionIDs(expected: [String], actual: [String])
    case emptyInteractionRows([String])
    case missingInteractionVisualState([String])
    case unexpectedInteractionDemoIDs(expected: [String], actual: [String])
    case unexpectedInteractionDemoRows([IslandPhase5InteractionDemoProbeRow])
    case unexpectedInteractionTransitionKinds([IslandPhase5InteractionProbeRow])
    case missingPreviewMarkers([IslandPhase5ScenarioProbeRow])
    case unexpectedPreviewMarkerTones(expected: [String], actual: [String])
    case missingGestureLockPreviewMarker
    case invalidPreviewMarkerWidths([IslandPhase5ScenarioProbeRow])
    case missingPreviewContent([IslandPhase5ScenarioProbeRow])
    case previewContentNotDistinct([IslandPhase5ScenarioProbeRow])
    case invalidMockScenarioPayloads([String])
    case missingContentWidthBranches(expected: [String], actual: [String])
    case missingLayoutPreviewMarkers([IslandPhase5PreviewMarkerLayoutProbeRow])
    case markerWidthNotRoutedThroughDerivedState([IslandPhase5PreviewMarkerLayoutProbeRow])
    case contentWidthNotRoutedThroughController([IslandPhase5PreviewMarkerLayoutProbeRow])
    case activityWidthDidNotVaryByRequirement([IslandPhase5PreviewMarkerLayoutProbeRow])
    case compactWidthInflatedByContent([IslandPhase5PreviewMarkerLayoutProbeRow])
    case shellNotCenteredAroundNotch([IslandPhase5PreviewMarkerLayoutProbeRow])
    case shellDetachedFromNotch([IslandPhase5PreviewMarkerLayoutProbeRow])

    var description: String {
        switch self {
        case let .duplicateScenarioIDs(ids):
            return "Duplicate Phase 5 scenario IDs: \(ids)"
        case let .unexpectedScenarioCount(expected, actual):
            return "Unexpected Phase 5 scenario count. Expected \(expected), actual \(actual)."
        case let .missingRequiredScenarioIDs(expected, actual):
            return "Phase 5 scenario rows are missing required IDs. Expected \(expected), actual \(actual)."
        case let .unexpectedScenarioRows(rows):
            return "Unexpected Phase 5 scenario rows: \(rows)"
        case let .invalidScenarioWidths(rows):
            return "Invalid Phase 5 scenario widths: \(rows)"
        case let .incompleteScenarioEvidence(rows):
            return "Phase 5 scenario rows are missing required evidence fields: \(rows)"
        case let .unexpectedInteractionIDs(expected, actual):
            return "Unexpected Phase 5 interaction IDs. Expected \(expected), actual \(actual)."
        case let .emptyInteractionRows(ids):
            return "Interaction rows must contain at least one step: \(ids)"
        case let .missingInteractionVisualState(ids):
            return "Interaction rows contain empty visual states: \(ids)"
        case let .unexpectedInteractionDemoIDs(expected, actual):
            return "Unexpected Phase 5 interaction demo IDs. Expected \(expected), actual \(actual)."
        case let .unexpectedInteractionDemoRows(rows):
            return "Unexpected Phase 5 interaction demo rows: \(rows)"
        case let .unexpectedInteractionTransitionKinds(rows):
            return "Unexpected Phase 5 interaction transition kinds: \(rows)"
        case let .missingPreviewMarkers(rows):
            return "Phase 5 preview markers are missing for rows: \(rows)"
        case let .unexpectedPreviewMarkerTones(expected, actual):
            return "Unexpected Phase 5 preview marker tones. Expected \(expected), actual \(actual)."
        case .missingGestureLockPreviewMarker:
            return "Phase 5 gesture-lock preview marker is missing or has no width requirement."
        case let .invalidPreviewMarkerWidths(rows):
            return "Phase 5 preview marker widths are invalid: \(rows)"
        case let .missingPreviewContent(rows):
            return "Phase 5 preview content is missing visible fields: \(rows)"
        case let .previewContentNotDistinct(rows):
            return "Phase 5 preview content does not distinguish enough mock scenarios: \(rows)"
        case let .invalidMockScenarioPayloads(ids):
            return "Mock scenario payloads are incomplete: \(ids)"
        case let .missingContentWidthBranches(expected, actual):
            return "Phase 5 content width branches are incomplete. Expected \(expected), actual \(actual)."
        case let .missingLayoutPreviewMarkers(rows):
            return "Phase 5 layout rows are missing preview markers: \(rows)"
        case let .markerWidthNotRoutedThroughDerivedState(rows):
            return "Phase 5 marker width requirements did not route through derived state: \(rows)"
        case let .contentWidthNotRoutedThroughController(rows):
            return "Phase 5 content width requirements did not route through layout input and sizing diagnostics: \(rows)"
        case let .activityWidthDidNotVaryByRequirement(rows):
            return "Phase 5 visible widths did not vary across mock content requirements: \(rows)"
        case let .compactWidthInflatedByContent(rows):
            return "Phase 5 compact/hover widths were inflated by mock content requirements: \(rows)"
        case let .shellNotCenteredAroundNotch(rows):
            return "Phase 5 shell is not centered around the notch: \(rows)"
        case let .shellDetachedFromNotch(rows):
            return "Phase 5 marker layout detached the shell from the notch: \(rows)"
        }
    }
}
