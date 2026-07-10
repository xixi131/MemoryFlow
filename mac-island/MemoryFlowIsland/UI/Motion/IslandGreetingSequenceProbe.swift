import Foundation

struct IslandGreetingSequenceProbeRow: Equatable {
    let phase: IslandGreetingPhase
    let timestamp: TimeInterval
    let opacity: Double
    let offsetY: Double
}

enum IslandGreetingSequenceProbe {
    static func rows() -> [IslandGreetingSequenceProbeRow] {
        [
            row(.hidden, 0),
            sampledRow(IslandGreetingSequence.transitionDuration / 2),
            row(.visible, IslandGreetingSequence.transitionDuration),
            sampledRow(IslandGreetingSequence.lifecycleDuration + (IslandGreetingSequence.transitionDuration / 2)),
            row(.expired, IslandGreetingSequence.lifecycleDuration + IslandGreetingSequence.transitionDuration)
        ]
    }

    static func validate() throws {
        let rows = rows()
        guard rows.map(\.phase) == [.hidden, .entering, .visible, .exiting, .expired],
              rows[0].opacity == 0 && rows[0].offsetY == 6,
              rows[1].opacity == 0.5 && rows[1].offsetY == 3,
              rows[2].opacity == 1 && rows[2].offsetY == 0,
              rows[3].opacity == 0.5 && rows[3].offsetY == -3,
              rows[4].timestamp == 10.35,
              IslandGreetingSequence.sample(at: IslandGreetingSequence.lifecycleDuration).shouldUseGreetingWidth,
              IslandGreetingSequence.sample(at: IslandGreetingSequence.lifecycleDuration + IslandGreetingSequence.transitionDuration).shouldUseGreetingWidth == false else {
            throw IslandGreetingSequenceProbeError.invalidTimeline(rows)
        }

        var gate = IslandGreetingTransitionGate()
        let greetingEpoch = gate.begin()
        let musicEpoch = gate.begin()
        guard gate.accepts(greetingEpoch) == false, gate.accepts(musicEpoch) else {
            throw IslandGreetingSequenceProbeError.musicDidNotCancelGreeting
        }

        let greeting = IslandDerivedState.derive(from: .mockGreetingCompact)
        let fastForward = IslandPresentationReducer.reduce(
            current: .mockGreetingCompact,
            intent: .greetingFastForward
        )
        let musicTakeover = IslandPresentationReducer.reduce(
            current: .mockGreetingCompact,
            intent: .musicSnapshotUpdated(.stopped)
        )
        guard fastForward.state.isGreetingActive == false,
              fastForward.derivedState.collapsedWidth < greeting.collapsedWidth,
              musicTakeover.state.isGreetingActive == false,
              musicTakeover.derivedState.contentWidthBranch != .greeting else {
            throw IslandGreetingSequenceProbeError.greetingWidthWasNotReleased
        }
    }

    private static func row(_ phase: IslandGreetingPhase, _ timestamp: TimeInterval) -> IslandGreetingSequenceProbeRow {
        let presentation = IslandGreetingSequence.presentation(for: phase)
        return IslandGreetingSequenceProbeRow(
            phase: phase,
            timestamp: timestamp,
            opacity: presentation.opacity,
            offsetY: presentation.offsetY
        )
    }

    private static func sampledRow(_ timestamp: TimeInterval) -> IslandGreetingSequenceProbeRow {
        let sample = IslandGreetingSequence.sample(at: timestamp)
        return IslandGreetingSequenceProbeRow(
            phase: sample.phase,
            timestamp: timestamp,
            opacity: sample.presentation.opacity,
            offsetY: sample.presentation.offsetY
        )
    }
}

enum IslandGreetingSequenceProbeError: Error {
    case invalidTimeline([IslandGreetingSequenceProbeRow])
    case musicDidNotCancelGreeting
    case greetingWidthWasNotReleased
}
