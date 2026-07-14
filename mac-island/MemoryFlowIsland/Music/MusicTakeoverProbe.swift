import AppKit
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
        let realLoggedOutTakeover = IslandPresentationReducer.reduce(
            current: .loggedOutCompact,
            intent: .musicSnapshotUpdated(snapshots.playing)
        )
        let unlockedLoggedOutMusic = IslandPresentationReducer.reduce(
            current: realLoggedOutTakeover.state,
            intent: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition)
        )
        let expandedLoggedOutMusic = IslandPresentationReducer.reduce(
            current: unlockedLoggedOutMusic.state,
            intent: .tap
        )
        let restoredLoggedOut = IslandPresentationReducer.reduce(
            current: realLoggedOutTakeover.state,
            intent: .musicStopped
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
              realLoggedOutTakeover.reason == .musicSnapshotAccepted,
              realLoggedOutTakeover.state.primaryMode == .music,
              realLoggedOutTakeover.derivedState.visualState == .activityCollapsed,
              expandedLoggedOutMusic.reason == .tapExpandedToMusic,
              expandedLoggedOutMusic.state.authState == .loggedOut,
              expandedLoggedOutMusic.state.presentationState == .expanded,
              expandedLoggedOutMusic.derivedState.visualState == .expandedMusic,
              restoredLoggedOut.state.authState == .loggedOut,
              restoredLoggedOut.state.primaryMode == .app,
              restoredLoggedOut.state.presentationState == .collapsed,
              restoredLoggedOut.state.musicReturnState == nil,
              acceptedWhileActive.reason == .musicSnapshotRetargeted,
              acceptedWhileActive.state.mockSources.music?.trackTitle == snapshots.paused.title else {
            throw MusicTakeoverProbeError.invalidTakeoverOrRetarget
        }

        try validateArtworkPaletteExtraction()
        try validateArtworkSnapshotMerging()
        try validateWrappedArtworkBase64Decoding()
        try validateDistributedDurationNormalization()
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
                scenarioID: "logged-out-tap-expands-real-music",
                initialState: state(
                    after: .transitionComplete(IslandTransitionLockIdentifier.forceCompactTransition),
                    from: state(after: .musicSnapshotUpdated(playingSnapshot), from: .loggedOutCompact)
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
            themePalette: MusicThemePalette(colorsHex: ["#f6b7a2", "#8b5cf6"]),
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
            themePalette: .fallback,
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

    private static func validateArtworkPaletteExtraction() throws {
        let size = NSSize(width: 12, height: 6)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 6, height: 6)).fill()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 6, y: 0, width: 6, height: 6)).fill()
        image.unlockFocus()

        guard let data = image.tiffRepresentation else {
            throw MusicTakeoverProbeError.invalidArtworkPalette
        }
        let palette = MusicArtworkPaletteExtractor.extract(from: data)
        guard palette.colorsHex.count >= 2,
              palette.primaryHex != MusicThemePalette.fallbackHex else {
            throw MusicTakeoverProbeError.invalidArtworkPalette
        }
    }

    private static func validateArtworkSnapshotMerging() throws {
        let snapshots = sampleSnapshots()
        let knownArtwork = snapshots.playing.artworkData
        var sameTrackWithoutArtwork = snapshots.playing
        sameTrackWithoutArtwork.artworkData = nil
        let preserved = MusicArtworkSnapshotMerger.merge(
            primary: sameTrackWithoutArtwork,
            previous: snapshots.playing
        )

        var nextTrackWithoutArtwork = snapshots.paused
        nextTrackWithoutArtwork.status = .playing
        nextTrackWithoutArtwork.isPlaying = true
        var matchingFallback = nextTrackWithoutArtwork
        matchingFallback.artworkData = Data([0x10, 0x20, 0x30])
        let recovered = MusicArtworkSnapshotMerger.merge(
            primary: nextTrackWithoutArtwork,
            previous: snapshots.playing,
            fallback: matchingFallback
        )

        var mismatchedFallback = matchingFallback
        mismatchedFallback.title = "Different Song"
        let rejected = MusicArtworkSnapshotMerger.merge(
            primary: nextTrackWithoutArtwork,
            previous: snapshots.playing,
            fallback: mismatchedFallback
        )

        guard preserved.artworkData == knownArtwork,
              recovered.artworkData == matchingFallback.artworkData,
              rejected.artworkData == nil else {
            throw MusicTakeoverProbeError.invalidArtworkSnapshotMerge
        }
    }

    private static func validateWrappedArtworkBase64Decoding() throws {
        let artwork = Data((0..<192).map { UInt8($0) })
        let encoded = artwork.base64EncodedString()
        let encodedBytes = Array(encoded.utf8)
        let wrapped = stride(from: 0, to: encodedBytes.count, by: 64)
            .map { offset in
                let end = min(offset + 64, encodedBytes.count)
                return String(decoding: encodedBytes[offset..<end], as: UTF8.self)
            }
            .joined(separator: "\n")

        guard AppleMusicProvider.decodeArtworkBase64(wrapped) == artwork,
              AppleMusicProvider.decodeArtworkBase64("") == nil else {
            throw MusicTakeoverProbeError.invalidWrappedArtworkBase64
        }
    }

    private static func validateDistributedDurationNormalization() throws {
        let normalizedTotalTime = MediaRemoteMusicProvider.normalizedDistributedDuration(
            durationSeconds: nil,
            totalTimeMilliseconds: 262_000
        )
        let preferredSeconds = MediaRemoteMusicProvider.normalizedDistributedDuration(
            durationSeconds: 262,
            totalTimeMilliseconds: 999_000
        )
        guard normalizedTotalTime == 262,
              preferredSeconds == 262 else {
            throw MusicTakeoverProbeError.invalidDistributedDuration
        }
    }
}

enum MusicTakeoverProbeError: Error {
    case invalidTakeoverOrRetarget
    case invalidArtworkPalette
    case invalidArtworkSnapshotMerge
    case invalidWrappedArtworkBase64
    case invalidDistributedDuration
}
