import Foundation

struct MusicTakeoverProbeRow: Codable, Equatable {
    let scenarioID: String
    let intent: String
    let reason: String
    let visualState: String
    let hasMusicSource: Bool
    let title: String?
    let artist: String?
    let elapsedSeconds: Double?
    let durationSeconds: Double?
    let command: String?
}

enum MusicTakeoverProbe {
    /// Covers the Phase 6 split between a first mock takeover and in-place track updates.
    static func validateTakeoverAndRetargeting() throws {
        let snapshots = sampleSnapshots()
        let started = IslandPresentationReducer.reduce(
            current: .loggedInReviewActivity,
            intent: .mockPlaybackStarted(snapshots.playing)
        )
        let startedPlan = IslandMotionEngine.plan(
            previous: IslandDerivedState.derive(from: .loggedInReviewActivity),
            next: started.derivedState,
            reason: started.reason,
            presentation: .idle,
            reduceMotion: false
        )
        let retargeted = IslandPresentationReducer.reduce(
            current: started.state,
            intent: .musicSnapshotUpdated(snapshots.paused)
        )
        let retargetPlan = IslandMotionEngine.plan(
            previous: started.derivedState,
            next: retargeted.derivedState,
            reason: retargeted.reason,
            presentation: .idle,
            reduceMotion: false
        )
        let ignoredLoggedOut = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .mockPlaybackStarted(snapshots.playing)
        )
        var loggedOutMusic = started.state
        loggedOutMusic.authState = .loggedOut
        let acceptedWhileActive = IslandPresentationReducer.reduce(
            current: loggedOutMusic,
            intent: .musicSnapshotUpdated(snapshots.paused)
        )

        guard started.reason == .musicTakeoverStarted,
              started.state.primaryMode == .music,
              started.state.forceCompactMode == false,
              started.derivedState.visualState == .activityCollapsed,
              startedPlan.transitionKind == .musicTakeover,
              startedPlan.content.exit.duration == 0.15,
              retargeted.reason == .musicSnapshotRetargeted,
              retargeted.state.primaryMode == .music,
              retargeted.state.mockSources.music?.trackTitle == snapshots.paused.title,
              retargetPlan.transitionKind == .musicContentRetarget,
              retargetPlan.shellFrame.keyframes.duration == 0.18,
              ignoredLoggedOut.reason == .musicSnapshotIgnoredLoggedOut,
              ignoredLoggedOut.state == .loggedOutCompact,
              acceptedWhileActive.reason == .musicSnapshotRetargeted,
              acceptedWhileActive.state.mockSources.music?.trackTitle == snapshots.paused.title else {
            throw MusicTakeoverProbeError.invalidTakeoverOrRetarget
        }
    }

    static func rows() -> [MusicTakeoverProbeRow] {
        let snapshots = sampleSnapshots()
        let playingSnapshot = snapshots.playing
        let pausedSnapshot = snapshots.paused

        return [
            row(
                scenarioID: "playing-snapshot-enters-music-activity",
                initialState: .loggedInReviewCompact,
                intent: .musicSnapshotUpdated(playingSnapshot),
                intentDescription: "musicSnapshotUpdated(playing)"
            ),
            row(
                scenarioID: "tap-expands-real-music",
                initialState: state(
                    after: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    from: state(after: .musicSnapshotUpdated(playingSnapshot), from: .loggedInReviewCompact)
                ),
                intent: .tap,
                intentDescription: "tap"
            ),
            row(
                scenarioID: "paused-snapshot-keeps-music-source",
                initialState: .musicActivity,
                intent: .musicSnapshotUpdated(pausedSnapshot),
                intentDescription: "musicSnapshotUpdated(paused)"
            ),
            row(
                scenarioID: "stopped-exits-to-app",
                initialState: .musicActivityWithAppFallback,
                intent: .musicStopped,
                intentDescription: "musicStopped"
            ),
            row(
                scenarioID: "paused-timeout-exits-to-app",
                initialState: .musicActivityWithAppFallback,
                intent: .pausedMusicTimeout,
                intentDescription: "pausedMusicTimeout"
            ),
            row(
                scenarioID: "previous-command-metadata",
                initialState: .musicActivity,
                intent: .musicCommandRequested(.previousTrack),
                intentDescription: "musicCommandRequested(previousTrack)"
            ),
            row(
                scenarioID: "play-pause-command-metadata",
                initialState: .expandedMusic,
                intent: .musicCommandRequested(.playPause),
                intentDescription: "musicCommandRequested(playPause)"
            ),
            row(
                scenarioID: "next-command-metadata",
                initialState: .musicActivity,
                intent: .musicCommandRequested(.nextTrack),
                intentDescription: "musicCommandRequested(nextTrack)"
            )
        ]
    }

    private static func sampleSnapshots() -> (playing: MusicTrackSnapshot, paused: MusicTrackSnapshot) {
        let playing = MusicTrackSnapshot(
            title: "No Bottom Cave",
            artist: "Jolin Tsai",
            album: "Sample Album",
            status: .playing,
            isPlaying: true,
            position: 10,
            duration: 241,
            artworkData: Data([0x01, 0x02, 0x03]),
            themeColorHex: "#f6b7a2",
            source: "Apple Music",
            updatedAt: Date(timeIntervalSince1970: 1),
            capabilities: .transport
        )
        let paused = MusicTrackSnapshot(
            title: "Paused Song",
            artist: "Apple Music",
            album: nil,
            status: .paused,
            isPlaying: false,
            position: 24,
            duration: 180,
            artworkData: nil,
            themeColorHex: "#22d3ee",
            source: "Apple Music",
            updatedAt: Date(timeIntervalSince1970: 2),
            capabilities: .transport
        )

        return (playing, paused)
    }

    private static func state(
        after intent: IslandInteractionIntent,
        from initialState: IslandDomainState
    ) -> IslandDomainState {
        IslandPresentationReducer.reduce(current: initialState, intent: intent).state
    }

    private static func row(
        scenarioID: String,
        initialState: IslandDomainState,
        intent: IslandInteractionIntent,
        intentDescription: String
    ) -> MusicTakeoverProbeRow {
        let result = IslandPresentationReducer.reduce(
            current: initialState,
            intent: intent
        )
        let derivedState = result.derivedState
        let music = result.state.mockSources.music

        return MusicTakeoverProbeRow(
            scenarioID: scenarioID,
            intent: intentDescription,
            reason: result.reason.rawValue,
            visualState: derivedState.visualState.rawValue,
            hasMusicSource: music != nil,
            title: music?.trackTitle,
            artist: music?.artistName,
            elapsedSeconds: music.map { scalar($0.elapsedSeconds) },
            durationSeconds: music?.durationSeconds.map(scalar),
            command: result.metadata.musicCommand?.rawValue ?? result.metadata.mockMusicCommand?.rawValue
        )
    }

    private static func scalar(_ value: TimeInterval) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}

enum MusicTakeoverProbeError: Error {
    case invalidTakeoverOrRetarget
}
