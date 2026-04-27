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
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue,
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
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue,
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
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue,
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
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue,
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
                mockMusicCommand: result.metadata.mockMusicCommand?.rawValue,
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
                stateChanged: false,
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
                        reason: "tapCollapsedToCompact",
                        presentationState: "collapsed",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
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
                        reason: "tapCollapsedToCompact",
                        presentationState: "collapsed",
                        visualState: "compactCollapsed",
                        collapsedWidth: 160
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
        )
    ]

    private static let pointerSequenceCases: [(id: String, initialState: IslandDomainState, intents: [(IslandInteractionIntent, String)])] = [
        (
            id: "review-activity-pointer-collapse-restore",
            initialState: .loggedInReviewActivity,
            intents: [
                (.pointerSwipe(.right), "pointerSwipe(right)"),
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
        )
    ]

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
        }
    }
}
