import Foundation

struct IslandContentChoreographyProbeRow: Equatable {
    let transition: String
    let phase: IslandContentPhase
    let timestamp: TimeInterval
    let opacity: Double
    let blurRadius: Double
    let scale: Double
    let offsetY: Double
    let allowsHitTesting: Bool
}

enum IslandContentChoreographyProbe {
    static func sampledRows() -> [IslandContentChoreographyProbeRow] {
        [
            ("compact-activity", IslandVisualState.compactCollapsed, IslandVisualState.activityCollapsed),
            ("activity-expanded", .activityCollapsed, .expandedApp),
            ("expanded-activity", .expandedApp, .activityCollapsed),
            ("mode-retarget", .activityCollapsed, .activityCollapsed)
        ].flatMap { name, previous, next in
            sampledRows(name: name, plan: .resolve(from: previous, to: next))
        }
    }

    static func validate() throws {
        let rows = sampledRows()
        let transitions = Set(rows.map(\.transition))
        guard transitions == ["compact-activity", "activity-expanded", "expanded-activity", "mode-retarget"],
              rows.allSatisfy({ $0.phase != .visible || $0.allowsHitTesting }),
              rows.allSatisfy({ $0.phase == .visible || $0.allowsHitTesting == false }),
              rows.filter({ $0.phase == .waitingForShell }).allSatisfy({ $0.opacity == 0 && $0.blurRadius == 5 }),
              rows.filter({ $0.phase == .entering }).allSatisfy({ $0.opacity == 1 && $0.allowsHitTesting == false }) else {
            throw IslandContentChoreographyProbeError.invalidPresentation(rows)
        }

        var gate = IslandContentTransitionGate()
        let staleEpoch = gate.begin()
        let currentEpoch = gate.begin()
        guard gate.accepts(staleEpoch) == false, gate.accepts(currentEpoch) else {
            throw IslandContentChoreographyProbeError.staleRetargetWasAccepted
        }
    }

    private static func sampledRows(
        name: String,
        plan: IslandContentChoreographyPlan
    ) -> [IslandContentChoreographyProbeRow] {
        let waitEnd = plan.exit.duration + max(plan.shellDuration - plan.exit.duration, 0) + plan.enter.delay
        return [
            row(name, .exiting, 0, plan: plan),
            row(name, .waitingForShell, plan.exit.duration, plan: plan),
            row(name, .entering, waitEnd, plan: plan),
            row(name, .visible, waitEnd + plan.enter.duration, plan: plan)
        ]
    }

    private static func row(
        _ transition: String,
        _ phase: IslandContentPhase,
        _ timestamp: TimeInterval,
        plan: IslandContentChoreographyPlan
    ) -> IslandContentChoreographyProbeRow {
        let presentation = plan.presentation(for: phase)
        return IslandContentChoreographyProbeRow(
            transition: transition,
            phase: phase,
            timestamp: timestamp,
            opacity: presentation.opacity,
            blurRadius: presentation.blurRadius,
            scale: presentation.scale,
            offsetY: presentation.offsetY,
            allowsHitTesting: presentation.allowsHitTesting
        )
    }
}

enum IslandContentChoreographyProbeError: Error {
    case invalidPresentation([IslandContentChoreographyProbeRow])
    case staleRetargetWasAccepted
}
