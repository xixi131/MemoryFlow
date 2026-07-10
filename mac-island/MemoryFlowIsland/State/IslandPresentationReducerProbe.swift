import CoreGraphics
import Foundation

struct IslandPresentationReducerProbeRow: Codable, Equatable {
    let scenarioID: String
    let intent: String
    let reason: String
    let mockMusicCommand: String?
    let stateChanged: Bool
    let visualStateBefore: String
    let visualStateAfter: String
    let collapsedWidthBefore: Double
    let collapsedWidthAfter: Double
}

struct IslandPresentationReducerSequenceProbeStep: Codable, Equatable {
    let intent: String
    let reason: String
    let presentationState: String
    let visualState: String
    let collapsedWidth: Double
}

struct IslandPresentationReducerSequenceProbeRow: Codable, Equatable {
    let scenarioID: String
    let initialVisualState: String
    let steps: [IslandPresentationReducerSequenceProbeStep]
}

struct IslandPresentationReducerSequenceEvidenceState: Codable, Equatable {
    let authState: String
    let primaryMode: String
    let appDisplayMode: String
    let presentationState: String
    let forceCompactMode: Bool
    let isHovered: Bool
    let gestureState: String
    let isReminderActive: Bool
    let hasReviewSource: Bool
    let hasTodoSource: Bool
    let hasMusicSource: Bool
}

struct IslandPresentationReducerSequenceEvidenceStep: Codable, Equatable {
    let intent: String
    let reason: String
    let guardOutcome: String
    let mockMusicCommand: String?
    let state: IslandPresentationReducerSequenceEvidenceState
    let visualState: String
    let collapsedWidth: Double
}

struct IslandPresentationReducerSequenceEvidenceRow: Codable, Equatable {
    let scenarioID: String
    let intents: [String]
    let initialState: IslandPresentationReducerSequenceEvidenceState
    let initialVisualState: String
    let steps: [IslandPresentationReducerSequenceEvidenceStep]
    let finalState: IslandPresentationReducerSequenceEvidenceState
    let finalVisualState: String
}

enum IslandPresentationReducerProbe {
    static func noOpRows() -> [IslandPresentationReducerProbeRow] {
        representativeCases.map { entry in
            let beforeDerivedState = IslandDerivedState.derive(from: entry.state)
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let afterDerivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: beforeDerivedState.visualState.rawValue,
                visualStateAfter: afterDerivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(beforeDerivedState.collapsedWidth),
                collapsedWidthAfter: scalar(afterDerivedState.collapsedWidth)
            )
        }
    }

    static func compactDerivationRows() -> [IslandPresentationReducerProbeRow] {
        compactRepresentativeCases.map { entry in
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let derivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: derivedState.visualState.rawValue,
                visualStateAfter: derivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(derivedState.collapsedWidth),
                collapsedWidthAfter: scalar(derivedState.collapsedWidth)
            )
        }
    }

    static func activityDerivationRows() -> [IslandPresentationReducerProbeRow] {
        activityRepresentativeCases.map { entry in
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let derivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: derivedState.visualState.rawValue,
                visualStateAfter: derivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(derivedState.collapsedWidth),
                collapsedWidthAfter: scalar(derivedState.collapsedWidth)
            )
        }
    }

    static func musicDerivationRows() -> [IslandPresentationReducerProbeRow] {
        musicRepresentativeCases.map { entry in
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let derivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: derivedState.visualState.rawValue,
                visualStateAfter: derivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(derivedState.collapsedWidth),
                collapsedWidthAfter: scalar(derivedState.collapsedWidth)
            )
        }
    }

    static func musicCommandRows() -> [IslandPresentationReducerProbeRow] {
        musicCommandRepresentativeCases.map { entry in
            let beforeDerivedState = IslandDerivedState.derive(from: entry.state)
            let result = IslandPresentationReducer.reduce(
                current: entry.state,
                intent: entry.intent
            )
            let afterDerivedState = result.derivedState

            return IslandPresentationReducerProbeRow(
                scenarioID: entry.id,
                intent: entry.intentDescription,
                reason: result.reason.rawValue,
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                stateChanged: result.state != entry.state,
                visualStateBefore: beforeDerivedState.visualState.rawValue,
                visualStateAfter: afterDerivedState.visualState.rawValue,
                collapsedWidthBefore: scalar(beforeDerivedState.collapsedWidth),
                collapsedWidthAfter: scalar(afterDerivedState.collapsedWidth)
            )
        }
    }

    static func tapTransitionSequences() -> [IslandPresentationReducerSequenceProbeRow] {
        tapSequenceCases.map { entry in
            let initialDerivedState = IslandDerivedState.derive(from: entry.initialState)
            var currentState = entry.initialState
            let steps = entry.intents.map { intent, intentDescription in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPresentationReducerSequenceProbeStep(
                    intent: intentDescription,
                    reason: result.reason.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    visualState: derivedState.visualState.rawValue,
                    collapsedWidth: scalar(derivedState.collapsedWidth)
                )
            }

            return IslandPresentationReducerSequenceProbeRow(
                scenarioID: entry.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    static func hoverTransitionSequences() -> [IslandPresentationReducerSequenceProbeRow] {
        hoverSequenceCases.map { entry in
            let initialDerivedState = IslandDerivedState.derive(from: entry.initialState)
            var currentState = entry.initialState
            let steps = entry.intents.map { intent, intentDescription in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPresentationReducerSequenceProbeStep(
                    intent: intentDescription,
                    reason: result.reason.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    visualState: derivedState.visualState.rawValue,
                    collapsedWidth: scalar(derivedState.collapsedWidth)
                )
            }

            return IslandPresentationReducerSequenceProbeRow(
                scenarioID: entry.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    static func pointerTransitionSequences() -> [IslandPresentationReducerSequenceProbeRow] {
        pointerSequenceCases.map { entry in
            let initialDerivedState = IslandDerivedState.derive(from: entry.initialState)
            var currentState = entry.initialState
            let steps = entry.intents.map { intent, intentDescription in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPresentationReducerSequenceProbeStep(
                    intent: intentDescription,
                    reason: result.reason.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    visualState: derivedState.visualState.rawValue,
                    collapsedWidth: scalar(derivedState.collapsedWidth)
                )
            }

            return IslandPresentationReducerSequenceProbeRow(
                scenarioID: entry.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    static func trackpadTransitionSequences() -> [IslandPresentationReducerSequenceProbeRow] {
        trackpadSequenceCases.map { entry in
            let initialDerivedState = IslandDerivedState.derive(from: entry.initialState)
            var currentState = entry.initialState
            let steps = entry.intents.map { intent, intentDescription in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPresentationReducerSequenceProbeStep(
                    intent: intentDescription,
                    reason: result.reason.rawValue,
                    presentationState: result.state.presentationState.rawValue,
                    visualState: derivedState.visualState.rawValue,
                    collapsedWidth: scalar(derivedState.collapsedWidth)
                )
            }

            return IslandPresentationReducerSequenceProbeRow(
                scenarioID: entry.id,
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps
            )
        }
    }

    static func interactionSequenceEvidenceRows() -> [IslandPresentationReducerSequenceEvidenceRow] {
        interactionSequenceCases.map { entry in
            let initialDerivedState = IslandDerivedState.derive(from: entry.initialState)
            var currentState = entry.initialState
            let steps = entry.intents.map { intent, intentDescription in
                let result = IslandPresentationReducer.reduce(
                    current: currentState,
                    intent: intent
                )
                currentState = result.state
                let derivedState = result.derivedState

                return IslandPresentationReducerSequenceEvidenceStep(
                    intent: intentDescription,
                    reason: result.reason.rawValue,
                    guardOutcome: guardOutcome(for: result.reason),
                    mockMusicCommand: result.metadata.mockMusicCommand?.rawValue ?? result.metadata.musicCommand?.rawValue,
                    state: snapshot(for: result.state),
                    visualState: derivedState.visualState.rawValue,
                    collapsedWidth: scalar(derivedState.collapsedWidth)
                )
            }

            return IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: entry.id,
                intents: entry.intents.map(\.1),
                initialState: snapshot(for: entry.initialState),
                initialVisualState: initialDerivedState.visualState.rawValue,
                steps: steps,
                finalState: snapshot(for: currentState),
                finalVisualState: IslandDerivedState.derive(from: currentState).visualState.rawValue
            )
        }
    }

    @discardableResult
    static func validateNoOpRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = noOpRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-outside-collapse",
                intent: "outsideCollapse",
                reason: "intentIgnored",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-pointer-restore",
                intent: "pointerSwipe(left)",
                reason: "intentIgnored",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "app-mode-horizontal-music-command",
                intent: "horizontalMusicCommand(nextTrack)",
                reason: "intentIgnored",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "unknown-mock-scenario",
                intent: "mockScenarioSelect(missing-scenario)",
                reason: "intentIgnored",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 230,
                collapsedWidthAfter: 230
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "idle-transition-complete",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateCompactDerivationRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = compactDerivationRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-out-compact-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 180,
                collapsedWidthAfter: 180
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-in-review-compact-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateActivityDerivationRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = activityDerivationRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-in-review-activity-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "logged-in-todo-activity-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateMusicDerivationRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = musicDerivationRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "music-activity-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "music-compact-fallback-derivation",
                intent: "transitionComplete(nil)",
                reason: "noChange",
                mockMusicCommand: nil,
                stateChanged: false,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateMusicCommandRows() throws -> [IslandPresentationReducerProbeRow] {
        let rows = musicCommandRows()
        let expectedRows = [
            IslandPresentationReducerProbeRow(
                scenarioID: "music-horizontal-previous-track",
                intent: "horizontalMusicCommand(previousTrack)",
                reason: "mockPreviousTrackCommanded",
                mockMusicCommand: "previousTrack",
                stateChanged: true,
                visualStateBefore: "activityCollapsed",
                visualStateAfter: "activityCollapsed",
                collapsedWidthBefore: 240,
                collapsedWidthAfter: 240
            ),
            IslandPresentationReducerProbeRow(
                scenarioID: "music-horizontal-next-track",
                intent: "horizontalMusicCommand(nextTrack)",
                reason: "mockNextTrackCommanded",
                mockMusicCommand: "nextTrack",
                stateChanged: true,
                visualStateBefore: "compactCollapsed",
                visualStateAfter: "compactCollapsed",
                collapsedWidthBefore: 160,
                collapsedWidthAfter: 160
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateTapTransitionSequences() throws -> [IslandPresentationReducerSequenceProbeRow] {
        let rows = tapTransitionSequences()
        let expectedRows = [
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-compact-tap-recovery",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-activity-tap-recovery",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "music-compact-tap-recovery",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToMusic",
                        presentationState: "expanded",
                        visualState: "expandedMusic",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "music-activity-tap-recovery",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToMusic",
                        presentationState: "expanded",
                        visualState: "expandedMusic",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-force-compact-locked-tap-recovery",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "forceCompactTransitionLocked",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "expanded-app-source-collapse-recovery",
                initialVisualState: "expandedApp",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "expanded-music-source-collapse-recovery",
                initialVisualState: "expandedMusic",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "expanded-logged-out-collapse-recovery",
                initialVisualState: "expandedApp",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToCompact",
                        presentationState: "collapsed",
                        visualState: "compactCollapsed",
                        collapsedWidth: 180
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "expanded-compact-only-collapse-recovery",
                initialVisualState: "expandedApp",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "outsideCollapse",
                        reason: "outsideCollapsedToCompact",
                        presentationState: "collapsed",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ]
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedSequenceRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateHoverTransitionSequences() throws -> [IslandPresentationReducerSequenceProbeRow] {
        let rows = hoverTransitionSequences()
        let expectedRows = [
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-compact-hover-enter-leave",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "hoverEnter",
                        reason: "hoverEntered",
                        presentationState: "collapsed",
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "hoverLeave",
                        reason: "hoverLeft",
                        presentationState: "collapsed",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-expanded-hover-leave",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "hoverLeave",
                        reason: "noChange",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "music-expanded-hover-leave",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToMusic",
                        presentationState: "expanded",
                        visualState: "expandedMusic",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "hoverLeave",
                        reason: "noChange",
                        presentationState: "expanded",
                        visualState: "expandedMusic",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-mode-switch-hover-tap-lock",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "hoverEnter",
                        reason: "hoverEntered",
                        presentationState: "collapsed",
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "modeSwitchLocked",
                        presentationState: "collapsed",
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(modeSwitchLock)",
                        reason: "noChange",
                        presentationState: "collapsed",
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ]
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedSequenceRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validatePointerTransitionSequences() throws -> [IslandPresentationReducerSequenceProbeRow] {
        let rows = pointerTransitionSequences()
        let expectedRows = [
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-activity-pointer-collapse-restore",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "pointerSwipe(right)",
                        reason: "pointerSwipedToCompact",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "pointerSwipe(left)",
                        reason: "pointerSwipedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedSequenceRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateTrackpadTransitionSequences() throws -> [IslandPresentationReducerSequenceProbeRow] {
        let rows = trackpadTransitionSequences()
        let expectedRows = [
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-expanded-trackpad-close",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-activity-trackpad-close",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToCompact",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-compact-trackpad-reopen",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-activity-trackpad-expand",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToExpandedApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-activity-trackpad-cooldown-lock",
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToCompact",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadGestureLocked",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(trackpadGestureCooldown)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-compact-trackpad-open-before-expand",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadGestureLocked",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(trackpadGestureCooldown)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToExpandedApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ]
            ),
            IslandPresentationReducerSequenceProbeRow(
                scenarioID: "review-tap-collapse-trackpad-close",
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        presentationState: "expanded",
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "tap",
                        reason: "tapCollapsedToActivity",
                        presentationState: "activity",
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceProbeStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToCompact",
                        presentationState: "activity",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ]
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedSequenceRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    @discardableResult
    static func validateInteractionSequenceEvidenceRows() throws -> [IslandPresentationReducerSequenceEvidenceRow] {
        let rows = interactionSequenceEvidenceRows()
        let expectedRows = [
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "hover-enter-leave",
                intents: ["hoverEnter", "hoverLeave"],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "hoverEnter",
                        reason: "hoverEntered",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: hoveredState(from: .loggedInReviewCompact)),
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "hoverLeave",
                        reason: "hoverLeft",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .loggedInReviewCompact),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ],
                finalState: snapshot(for: .loggedInReviewCompact),
                finalVisualState: "compactCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "tap-expand-collapse",
                intents: ["tap", "tap"],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewCompact,
                                presentationState: .expanded
                            )
                        ),
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapCollapsedToActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .loggedInReviewActivityPlain),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ],
                finalState: snapshot(for: .loggedInReviewActivityPlain),
                finalVisualState: "activityCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "pointer-compact-activity-swipes",
                intents: [
                    "pointerSwipe(right)",
                    "transitionComplete(forceCompactTransition)",
                    "pointerSwipe(left)"
                ],
                initialState: snapshot(for: .loggedInReviewActivityPlain),
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "pointerSwipe(right)",
                        reason: "pointerSwipedToCompact",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "pointerSwipe(left)",
                        reason: "pointerSwipedToActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                presentationState: .activity,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ],
                finalState: snapshot(
                    for: lockedState(
                        from: .loggedInReviewActivityPlain,
                        presentationState: .activity,
                        isForceCompactLocked: true,
                        transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                    )
                ),
                finalVisualState: "activityCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "trackpad-vertical-swipes",
                intents: [
                    "trackpadSwipe(up)",
                    "transitionComplete(trackpadGestureCooldown)",
                    "transitionComplete(forceCompactTransition)",
                    "trackpadSwipe(down)"
                ],
                initialState: snapshot(for: .loggedInReviewActivityPlain),
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToCompact",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity,
                                gestureState: .cooldown,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(trackpadGestureCooldown)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "trackpadSwipe(down)",
                        reason: "trackpadSwipedDownToActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                presentationState: .activity,
                                gestureState: .cooldown,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ],
                finalState: snapshot(
                    for: lockedState(
                        from: .loggedInReviewActivityPlain,
                        presentationState: .activity,
                        gestureState: .cooldown,
                        isForceCompactLocked: true,
                        transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                    )
                ),
                finalVisualState: "activityCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "horizontal-music-command",
                intents: [
                    "horizontalMusicCommand(previousTrack)",
                    "transitionComplete(trackpadGestureCooldown)",
                    "horizontalMusicCommand(nextTrack)"
                ],
                initialState: snapshot(for: .musicActivity),
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "horizontalMusicCommand(previousTrack)",
                        reason: "mockPreviousTrackCommanded",
                        guardOutcome: "passed",
                        mockMusicCommand: "previousTrack",
                        state: snapshot(
                            for: lockedState(
                                from: .musicActivity,
                                gestureState: .cooldown
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(trackpadGestureCooldown)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .musicActivity),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "horizontalMusicCommand(nextTrack)",
                        reason: "mockNextTrackCommanded",
                        guardOutcome: "passed",
                        mockMusicCommand: "nextTrack",
                        state: snapshot(
                            for: lockedState(
                                from: .musicActivity,
                                gestureState: .cooldown
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ],
                finalState: snapshot(
                    for: lockedState(
                        from: .musicActivity,
                        gestureState: .cooldown
                    )
                ),
                finalVisualState: "activityCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "reminder-due",
                intents: ["reminderDue", "transitionComplete(forceCompactTransition)"],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "reminderDue",
                        reason: "reminderDueOpenedReviewActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivity,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .loggedInReviewActivity),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    )
                ],
                finalState: snapshot(for: .loggedInReviewActivity),
                finalVisualState: "activityCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "paused-music-timeout",
                intents: ["pausedMusicTimeout"],
                initialState: snapshot(for: .musicActivityWithAppFallback),
                initialVisualState: "activityCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "pausedMusicTimeout",
                        reason: "pausedMusicTimedOutToApp",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .pausedMusicTimeoutCompact),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ],
                finalState: snapshot(for: .pausedMusicTimeoutCompact),
                finalVisualState: "compactCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "rapid-retargeting",
                intents: [
                    "hoverEnter",
                    "pointerSwipe(left)",
                    "tap",
                    "transitionComplete(forceCompactTransition)",
                    "tap"
                ],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "hoverEnter",
                        reason: "hoverEntered",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: hoveredState(from: .loggedInReviewCompact)),
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "pointerSwipe(left)",
                        reason: "pointerSwipedToActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "forceCompactTransitionLocked",
                        guardOutcome: "blocked",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "transitionComplete(forceCompactTransition)",
                        reason: "noChange",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .loggedInReviewActivityPlain),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .expandedAppReview),
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    )
                ],
                finalState: snapshot(for: .expandedAppReview),
                finalVisualState: "expandedApp"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "rapid-hover-tap-hover",
                intents: [
                    "hoverEnter",
                    "tap",
                    "retargetPresentation(hoverCollapsed)"
                ],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "hoverEnter",
                        reason: "hoverEntered",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: hoveredState(from: .loggedInReviewCompact)),
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewCompact,
                                presentationState: .expanded
                            )
                        ),
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "retargetPresentation(hoverCollapsed)",
                        reason: "presentationRetargeted",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: hoveredState(from: .loggedInReviewCompact)),
                        visualState: "hoverCollapsed",
                        collapsedWidth: 160
                    )
                ],
                finalState: snapshot(for: hoveredState(from: .loggedInReviewCompact)),
                finalVisualState: "hoverCollapsed"
            ),
            IslandPresentationReducerSequenceEvidenceRow(
                scenarioID: "tap-tap-trackpad",
                intents: [
                    "tap",
                    "tap",
                    "trackpadSwipe(up)"
                ],
                initialState: snapshot(for: .loggedInReviewCompact),
                initialVisualState: "compactCollapsed",
                steps: [
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapExpandedToApp",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewCompact,
                                presentationState: .expanded
                            )
                        ),
                        visualState: "expandedApp",
                        collapsedWidth: 160
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "tap",
                        reason: "tapCollapsedToActivity",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(for: .loggedInReviewActivityPlain),
                        visualState: "activityCollapsed",
                        collapsedWidth: 240
                    ),
                    IslandPresentationReducerSequenceEvidenceStep(
                        intent: "trackpadSwipe(up)",
                        reason: "trackpadSwipedUpToCompact",
                        guardOutcome: "passed",
                        mockMusicCommand: nil,
                        state: snapshot(
                            for: lockedState(
                                from: .loggedInReviewActivityPlain,
                                forceCompactMode: true,
                                presentationState: .activity,
                                gestureState: .cooldown,
                                isForceCompactLocked: true,
                                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                            )
                        ),
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
                    )
                ],
                finalState: snapshot(
                    for: lockedState(
                        from: .loggedInReviewActivityPlain,
                        forceCompactMode: true,
                        presentationState: .activity,
                        gestureState: .cooldown,
                        isForceCompactLocked: true,
                        transitionID: IslandTransitionLockIdentifier.forceCompactTransition
                    )
                ),
                finalVisualState: "compactCollapsed"
            )
        ]

        guard rows == expectedRows else {
            throw IslandPresentationReducerProbeValidationError.unexpectedEvidenceRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    static func interactionSequenceEvidenceJSONData(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(validateInteractionSequenceEvidenceRows())
    }

    @discardableResult
    static func writeInteractionSequenceEvidence(outputDirectory: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let outputURL = outputDirectory.appendingPathComponent("interaction-sequences.json")
        try interactionSequenceEvidenceJSONData().write(to: outputURL)
        return outputURL
    }

    private static func lockedState(
        from base: IslandDomainState,
        forceCompactMode: Bool? = nil,
        presentationState: IslandPresentationState? = nil,
        gestureState: IslandGestureState? = nil,
        isModeSwitchLocked: Bool? = nil,
        isForceCompactLocked: Bool? = nil,
        transitionID: String? = nil,
        mutate: ((inout IslandDomainState) -> Void)? = nil
    ) -> IslandDomainState {
        var state = base

        if let forceCompactMode {
            state.forceCompactMode = forceCompactMode
        }

        if let presentationState {
            state.presentationState = presentationState
        }

        if let gestureState {
            state.gestureState = gestureState
        }

        if let isModeSwitchLocked {
            state.presentationLockState.isModeSwitchLocked = isModeSwitchLocked
        }

        if let isForceCompactLocked {
            state.presentationLockState.isForceCompactLocked = isForceCompactLocked
        }

        if let transitionID {
            state.presentationLockState.transitionID = transitionID
        }

        mutate?(&state)

        return state
    }

    private static let representativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "logged-out-outside-collapse",
            state: .loggedOutCompact,
            intent: .outsideCollapse,
            intentDescription: "outsideCollapse"
        ),
        (
            id: "logged-out-pointer-restore",
            state: .loggedOutCompact,
            intent: .pointerSwipe(.left),
            intentDescription: "pointerSwipe(left)"
        ),
        (
            id: "app-mode-horizontal-music-command",
            state: .loggedInReviewCompact,
            intent: .horizontalMusicCommand(.nextTrack),
            intentDescription: "horizontalMusicCommand(nextTrack)"
        ),
        (
            id: "unknown-mock-scenario",
            state: .loggedInTodoCompact,
            intent: .mockScenarioSelect("missing-scenario"),
            intentDescription: "mockScenarioSelect(missing-scenario)"
        ),
        (
            id: "idle-transition-complete",
            state: .musicActivity,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static let compactRepresentativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "logged-out-compact-derivation",
            state: .loggedOutCompact,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        ),
        (
            id: "logged-in-review-compact-derivation",
            state: .loggedInReviewCompact,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static let activityRepresentativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "logged-in-review-activity-derivation",
            state: .loggedInReviewActivity,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        ),
        (
            id: "logged-in-todo-activity-derivation",
            state: .loggedInTodoActivity,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static let musicRepresentativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "music-activity-derivation",
            state: .musicActivity,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        ),
        (
            id: "music-compact-fallback-derivation",
            state: .musicCompactFallback,
            intent: .transitionComplete(nil),
            intentDescription: "transitionComplete(nil)"
        )
    ]

    private static let musicCommandRepresentativeCases: [(id: String, state: IslandDomainState, intent: IslandInteractionIntent, intentDescription: String)] = [
        (
            id: "music-horizontal-previous-track",
            state: .musicActivity,
            intent: .horizontalMusicCommand(.previousTrack),
            intentDescription: "horizontalMusicCommand(previousTrack)"
        ),
        (
            id: "music-horizontal-next-track",
            state: .musicCompactFallback,
            intent: .horizontalMusicCommand(.nextTrack),
            intentDescription: "horizontalMusicCommand(nextTrack)"
        )
    ]

    private static let tapSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "review-compact-tap-recovery",
            initialState: .loggedInReviewCompact,
            intents: [(.tap, "tap"), (.tap, "tap")]
        ),
        (
            id: "review-activity-tap-recovery",
            initialState: .loggedInReviewActivity,
            intents: [(.tap, "tap"), (.outsideCollapse, "outsideCollapse")]
        ),
        (
            id: "music-compact-tap-recovery",
            initialState: .musicCompactFallback,
            intents: [(.tap, "tap"), (.tap, "tap")]
        ),
        (
            id: "music-activity-tap-recovery",
            initialState: .musicActivity,
            intents: [(.tap, "tap"), (.outsideCollapse, "outsideCollapse")]
        ),
        (
            id: "review-force-compact-locked-tap-recovery",
            initialState: lockedState(
                from: .loggedInReviewActivity,
                forceCompactMode: true,
                presentationState: .activity,
                isForceCompactLocked: true,
                transitionID: IslandTransitionLockIdentifier.forceCompactTransition
            ),
            intents: [
                (.tap, "tap"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.tap, "tap")
            ]
        ),
        (
            id: "expanded-app-source-collapse-recovery",
            initialState: .expandedAppReview,
            intents: [(.outsideCollapse, "outsideCollapse")]
        ),
        (
            id: "expanded-music-source-collapse-recovery",
            initialState: .expandedMusic,
            intents: [(.outsideCollapse, "outsideCollapse")]
        ),
        (
            id: "expanded-logged-out-collapse-recovery",
            initialState: lockedState(
                from: .loggedOutCompact,
                presentationState: .expanded
            ),
            intents: [(.outsideCollapse, "outsideCollapse")]
        ),
        (
            id: "expanded-compact-only-collapse-recovery",
            initialState: lockedState(
                from: .loggedInReviewCompact,
                presentationState: .expanded
            ) { state in
                state.mockSources = .none
            },
            intents: [(.outsideCollapse, "outsideCollapse")]
        )
    ]

    private static let hoverSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "review-compact-hover-enter-leave",
            initialState: .loggedInReviewCompact,
            intents: [(.hoverEnter, "hoverEnter"), (.hoverLeave, "hoverLeave")]
        ),
        (
            id: "review-expanded-hover-leave",
            initialState: .loggedInReviewCompact,
            intents: [(.tap, "tap"), (.hoverLeave, "hoverLeave")]
        ),
        (
            id: "music-expanded-hover-leave",
            initialState: .musicCompactFallback,
            intents: [(.tap, "tap"), (.hoverLeave, "hoverLeave")]
        ),
        (
            id: "review-mode-switch-hover-tap-lock",
            initialState: lockedState(
                from: .loggedInReviewCompact,
                isModeSwitchLocked: true,
                transitionID: IslandTransitionLockIdentifier.modeSwitchLock
            ),
            intents: [
                (.hoverEnter, "hoverEnter"),
                (.tap, "tap"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.modeSwitchLock),
                    "transitionComplete(modeSwitchLock)"
                ),
                (.tap, "tap")
            ]
        )
    ]

    private static let pointerSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "review-activity-pointer-collapse-restore",
            initialState: .loggedInReviewActivity,
            intents: [
                (.pointerSwipe(.right), "pointerSwipe(right)"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
                (.pointerSwipe(.left), "pointerSwipe(left)")
            ]
        )
    ]

    private static let trackpadSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "review-expanded-trackpad-close",
            initialState: .loggedInReviewActivity,
            intents: [(.tap, "tap"), (.trackpadSwipe(.up), "trackpadSwipe(up)")]
        ),
        (
            id: "review-activity-trackpad-close",
            initialState: .loggedInReviewActivity,
            intents: [(.trackpadSwipe(.up), "trackpadSwipe(up)")]
        ),
        (
            id: "review-compact-trackpad-reopen",
            initialState: .loggedInReviewCompact,
            intents: [(.trackpadSwipe(.down), "trackpadSwipe(down)")]
        ),
        (
            id: "review-activity-trackpad-expand",
            initialState: .loggedInReviewActivity,
            intents: [(.trackpadSwipe(.down), "trackpadSwipe(down)")]
        ),
        (
            id: "review-activity-trackpad-cooldown-lock",
            initialState: .loggedInReviewActivity,
            intents: [
                (.trackpadSwipe(.up), "trackpadSwipe(up)"),
                (.trackpadSwipe(.down), "trackpadSwipe(down)"),
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
            id: "review-compact-trackpad-open-before-expand",
            initialState: .loggedInReviewCompact,
            intents: [
                (.trackpadSwipe(.down), "trackpadSwipe(down)"),
                (.trackpadSwipe(.down), "trackpadSwipe(down)"),
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
            id: "review-tap-collapse-trackpad-close",
            initialState: .loggedInReviewCompact,
            intents: [
                (.tap, "tap"),
                (.tap, "tap"),
                (.trackpadSwipe(.up), "trackpadSwipe(up)")
            ]
        )
    ]

    private static let interactionSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "hover-enter-leave",
            initialState: .loggedInReviewCompact,
            intents: [(.hoverEnter, "hoverEnter"), (.hoverLeave, "hoverLeave")]
        ),
        (
            id: "tap-expand-collapse",
            initialState: .loggedInReviewCompact,
            intents: [(.tap, "tap"), (.tap, "tap")]
        ),
        (
            id: "pointer-compact-activity-swipes",
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
            id: "trackpad-vertical-swipes",
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
            id: "reminder-due",
            initialState: .loggedInReviewCompact,
            intents: [
                (.reminderDue, "reminderDue"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                )
            ]
        ),
        (
            id: "paused-music-timeout",
            initialState: .musicActivityWithAppFallback,
            intents: [(.pausedMusicTimeout, "pausedMusicTimeout")]
        ),
        (
            id: "rapid-retargeting",
            initialState: .loggedInReviewCompact,
            intents: [
                (.hoverEnter, "hoverEnter"),
                (.pointerSwipe(.left), "pointerSwipe(left)"),
                (.tap, "tap"),
                (
                    .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    "transitionComplete(forceCompactTransition)"
                ),
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

    private static func snapshot(for state: IslandDomainState) -> IslandPresentationReducerSequenceEvidenceState {
        IslandPresentationReducerSequenceEvidenceState(
            authState: state.authState.rawValue,
            primaryMode: state.primaryMode.rawValue,
            appDisplayMode: state.appDisplayMode.rawValue,
            presentationState: state.presentationState.rawValue,
            forceCompactMode: state.forceCompactMode,
            isHovered: state.isHovered,
            gestureState: state.gestureState.rawValue,
            isReminderActive: state.isReminderActive,
            hasReviewSource: state.mockSources.review != nil,
            hasTodoSource: state.mockSources.todo != nil,
            hasMusicSource: state.mockSources.music != nil
        )
    }

    private static func hoveredState(from base: IslandDomainState) -> IslandDomainState {
        var state = base
        state.isHovered = true
        return state
    }

    private static func guardOutcome(
        for reason: IslandPresentationTransitionReason
    ) -> String {
        switch reason {
        case .intentIgnored:
            return "ignored"
        case .trackpadGestureLocked, .modeSwitchLocked, .forceCompactTransitionLocked:
            return "blocked"
        default:
            return "passed"
        }
    }

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}

enum IslandPresentationReducerProbeValidationError: Error, CustomStringConvertible {
    case unexpectedRows(
        expected: [IslandPresentationReducerProbeRow],
        actual: [IslandPresentationReducerProbeRow]
    )
    case unexpectedSequenceRows(
        expected: [IslandPresentationReducerSequenceProbeRow],
        actual: [IslandPresentationReducerSequenceProbeRow]
    )
    case unexpectedEvidenceRows(
        expected: [IslandPresentationReducerSequenceEvidenceRow],
        actual: [IslandPresentationReducerSequenceEvidenceRow]
    )

    var description: String {
        switch self {
        case let .unexpectedRows(expected, actual):
            return """
            Unexpected presentation-reducer probe rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        case let .unexpectedSequenceRows(expected, actual):
            return """
            Unexpected presentation-reducer probe sequence rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        case let .unexpectedEvidenceRows(expected, actual):
            return """
            Unexpected presentation-reducer evidence rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        }
    }
}
