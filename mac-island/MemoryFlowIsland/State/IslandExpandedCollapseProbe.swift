import Foundation

struct IslandExpandedCollapseProbeRow: Equatable {
    let source: String
    let input: String
    let firstVisualState: IslandVisualState
    let finalVisualState: IslandVisualState
    let firstReason: IslandPresentationTransitionReason
    let recoversOriginalActivity: Bool
    let trackpadCooldownActive: Bool
}

enum IslandExpandedCollapseProbe {
    static func rows() -> [IslandExpandedCollapseProbeRow] {
        let sources: [(String, IslandDomainState)] = [
            ("review", .mockExpandedReview),
            ("todo", .mockExpandedTodo),
            ("music", .mockExpandedMusic)
        ]
        let inputs: [(String, IslandInteractionIntent)] = [
            ("tap", .tap),
            ("outside", .outsideCollapse),
            ("trackpad-up", .trackpadSwipe(.up))
        ]

        return sources.flatMap { source, initialState in
            inputs.map { input, intent in
                row(source: source, input: input, initialState: initialState, intent: intent)
            }
        }
    }

    static func validate() throws {
        let rows = rows()
        guard rows.count == 9,
              rows.allSatisfy({
                  $0.firstVisualState == .compactCollapsed &&
                      $0.finalVisualState == .activityCollapsed &&
                      $0.recoversOriginalActivity
              }) else {
            throw IslandExpandedCollapseProbeError.activityRecoveryFailed(rows)
        }

        let expectedReasons: [String: IslandPresentationTransitionReason] = [
            "tap": .tapCollapsedToCompact,
            "outside": .outsideCollapsedToCompact,
            "trackpad-up": .trackpadSwipedUpToCompact
        ]
        guard rows.allSatisfy({ $0.firstReason == expectedReasons[$0.input] }),
              rows.filter({ $0.input == "trackpad-up" }).allSatisfy(\.trackpadCooldownActive),
              rows.filter({ $0.input != "trackpad-up" }).allSatisfy({ $0.trackpadCooldownActive == false }) else {
            throw IslandExpandedCollapseProbeError.inputSemanticsFailed(rows)
        }

        let forceCompactRows = [
            forcedCompactRow(source: "review", state: .mockExpandedReview),
            forcedCompactRow(source: "todo", state: .mockExpandedTodo),
            forcedCompactRow(source: "music", state: .mockExpandedMusic)
        ]
        guard forceCompactRows.allSatisfy({ $0.presentationState == .collapsed && $0.forceCompactMode }),
              forceCompactRows.allSatisfy({ IslandDerivedState.derive(from: $0).visualState == .compactCollapsed }),
              forceCompactRows.allSatisfy({ $0.presentationLockState.transitionID == nil }) else {
            throw IslandExpandedCollapseProbeError.forceCompactFailed
        }
    }

    private static func row(
        source: String,
        input: String,
        initialState: IslandDomainState,
        intent: IslandInteractionIntent
    ) -> IslandExpandedCollapseProbeRow {
        let first = IslandPresentationReducer.reduce(current: initialState, intent: intent)
        let completed = IslandPresentationReducer.reduce(
            current: first.state,
            intent: .transitionComplete("expandedCollapseRecovery")
        )

        return IslandExpandedCollapseProbeRow(
            source: source,
            input: input,
            firstVisualState: first.derivedState.visualState,
            finalVisualState: completed.derivedState.visualState,
            firstReason: first.reason,
            recoversOriginalActivity: completed.state.primaryMode == initialState.primaryMode &&
                completed.state.appDisplayMode == initialState.appDisplayMode &&
                completed.state.forceCompactMode == false,
            trackpadCooldownActive: completed.state.gestureState == .cooldown
        )
    }

    private static func forcedCompactRow(source: String, state: IslandDomainState) -> IslandDomainState {
        var forced = state
        forced.forceCompactMode = true
        let first = IslandPresentationReducer.reduce(current: forced, intent: .outsideCollapse)
        return IslandPresentationReducer.reduce(
            current: first.state,
            intent: .transitionComplete("expandedCollapseRecovery")
        ).state
    }
}

enum IslandExpandedCollapseProbeError: Error {
    case activityRecoveryFailed([IslandExpandedCollapseProbeRow])
    case inputSemanticsFailed([IslandExpandedCollapseProbeRow])
    case forceCompactFailed
}
