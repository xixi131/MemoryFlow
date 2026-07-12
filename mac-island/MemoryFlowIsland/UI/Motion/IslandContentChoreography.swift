import CoreGraphics
import Foundation

enum IslandContentPhase: String, CaseIterable, Equatable {
    case hidden
    case exiting
    case waitingForShell
    case entering
    case visible
}

struct IslandContentPresentation: Equatable {
    let phase: IslandContentPhase
    let opacity: Double
    let blurRadius: CGFloat
    let scale: CGFloat
    let offsetY: CGFloat
    let allowsHitTesting: Bool

    static let hidden = IslandContentPresentation(
        phase: .hidden,
        opacity: 0,
        blurRadius: 5,
        scale: 0.96,
        offsetY: -4,
        allowsHitTesting: false
    )
}

struct IslandContentChoreographyPlan: Equatable {
    let transitionKind: IslandTransitionKind
    let shellDuration: TimeInterval
    let enter: IslandContentMotionToken
    let exit: IslandContentMotionToken

    func enterStart(motionDuration: TimeInterval) -> TimeInterval {
        switch transitionKind {
        case .compactToActivity, .compactToExpanded, .activityToExpanded, .reminderOpen, .musicTakeover, .modeSwitch:
            return enter.delay
        case .activityToCompact, .expandedToCompact, .reminderRecover:
            return IslandMotionTokens.activityCollapseCompactContentDelay
        case .expandedToActivity:
            return max(
                motionDuration - enter.duration,
                exit.duration
            )
        default:
            return exit.duration + enter.delay
        }
    }

    func presentation(for phase: IslandContentPhase) -> IslandContentPresentation {
        switch phase {
        case .hidden, .waitingForShell:
            return .hidden
        case .exiting:
            return IslandContentPresentation(
                phase: .exiting,
                opacity: 0,
                blurRadius: exit.blurRadius,
                scale: 0.96,
                offsetY: -4,
                allowsHitTesting: false
            )
        case .entering:
            return IslandContentPresentation(
                phase: .entering,
                opacity: 1,
                blurRadius: 0,
                scale: 1,
                offsetY: 0,
                allowsHitTesting: false
            )
        case .visible:
            return IslandContentPresentation(
                phase: .visible,
                opacity: 1,
                blurRadius: 0,
                scale: 1,
                offsetY: 0,
                allowsHitTesting: true
            )
        }
    }

    static func resolve(
        from previous: IslandVisualState,
        to next: IslandVisualState
    ) -> IslandContentChoreographyPlan {
        let kind: IslandTransitionKind
        switch (previous, next) {
        case (.compactCollapsed, .activityCollapsed), (.hoverCollapsed, .activityCollapsed):
            kind = .compactToActivity
        case (.compactCollapsed, .expandedApp), (.compactCollapsed, .expandedMusic),
             (.hoverCollapsed, .expandedApp), (.hoverCollapsed, .expandedMusic):
            kind = .compactToExpanded
        case (.activityCollapsed, .expandedApp), (.activityCollapsed, .expandedMusic):
            kind = .activityToExpanded
        case (.expandedApp, .activityCollapsed), (.expandedMusic, .activityCollapsed):
            kind = .expandedToActivity
        case (.activityCollapsed, .compactCollapsed), (.activityCollapsed, .hoverCollapsed):
            kind = .activityToCompact
        default:
            kind = .defaultProfile
        }
        let tokens = kind.motionTokens
        return IslandContentChoreographyPlan(
            transitionKind: kind,
            shellDuration: tokens.shellKeyframes.duration,
            enter: tokens.contentEnter,
            exit: tokens.contentExit
        )
    }

    static func resolve(for motionPlan: IslandMotionPlan) -> IslandContentChoreographyPlan {
        IslandContentChoreographyPlan(
            transitionKind: motionPlan.transitionKind,
            shellDuration: motionPlan.shellFrame.keyframes.duration,
            enter: motionPlan.content.enter,
            exit: motionPlan.content.exit
        )
    }
}

struct IslandContentTransitionGate: Equatable {
    private(set) var epoch = 0

    mutating func begin() -> Int {
        epoch += 1
        return epoch
    }

    func accepts(_ candidateEpoch: Int) -> Bool {
        epoch == candidateEpoch
    }
}
