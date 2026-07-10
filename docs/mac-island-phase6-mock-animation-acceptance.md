# Phase 6 Mock Animation Acceptance

## Scope

This acceptance shell covers the native macOS island's deterministic mock presentation of review, todo, reminder, greeting, and music states. It is a visual and interaction-parity review surface only.

The mock-only queue excludes backend services, authentication, MediaRemote, Apple Music, Spotify, Keychain, and IPC integration. No real media command, account state, persisted todo mutation, or remote data call is an acceptance prerequisite.

## References

- [State specification](mac-island-state-spec.md)
- [Interaction specification](mac-island-interaction-spec.md)
- [Animation specification](mac-island-animation-spec.md)
- [Migration plan: Phase 6, collapsed/activity/expanded content views](../灵动岛迁移方案.md#phase-6迁移-collapsedactivityexpanded-内容视图)

## Windows Parity

Windows remains the read-only parity baseline. For each deterministic mock scenario, native state selection, shell family, visible text/counters, color branches, and input outcome must match the documented Windows behavior. Any intentional divergence requires an explicit follow-up decision and evidence.

## Motion Architecture

The renderer must derive a transition plan from previous and next presentation state rather than replacing target geometry immediately. Shell metrics, path metrics, shadow, and content phases must share a transition identifier and preserve the top-center anchor.

## Shell Morphs

Acceptance covers compact, activity, and expanded shell changes, including width, height, corner/path metrics, shadow, and top-center positioning. Retargeting a running shell morph must remain continuous, with no frame jump or detached hit frame.

## Content Choreography

Shell motion begins before incoming content. Incoming content enters with the documented delayed fade/blur treatment; outgoing content leaves before the shell finishes collapsing. Review, todo, reminder, greeting, and music mock content must not flash, remain as residual content, or directly mutate the panel frame.

## Mouse Input

Verify hover enter/leave, click-through recovery, pointer capture, tap expansion, and horizontal activity-state swipes. Mouse input must honor the documented thresholds and must not conflict with an active motion or mode-switch lock.

## Trackpad Input

Verify accumulated vertical presentation changes and horizontal mock music track commands. Threshold, reset window, dominant-axis selection, and cooldown behavior must follow the interaction specification without invoking a real media provider.

## Mock Modules

The deterministic scenario catalog must expose logged-out and logged-in compact states, greeting, review activity, todo activity, music playing/paused/stopped, expanded review/todo/music, and reminder due. Each module supplies local fixed data and declares width needs through the sizing path.

## Interruptibility

Rapid tap, hover reversal, activity open/collapse, reminder open, music takeover, and mode-switch transitions must retarget from current presentation values. The final derived state determines the settled output; cancelled content callbacks cannot restore stale content.

## Accessibility

Reduce Motion must replace nonessential spring, path, blur, and staged-content effects with an understandable immediate or short crossfade presentation while retaining state, input, focus, and readable contrast. Mock controls require accessible names and keyboard-reachable equivalents where they are interactive.

## Performance

At 60 Hz and 120 Hz review targets, shell and content animation must avoid visible stutter, unbounded layout work, and repeated panel-frame writes. Animation should use presentation values and bounded per-frame work; mock scenario switching must not create retained callbacks or timers.

## Evidence

Record deterministic scenario selection, derived state, resolved visual/motion plan, content-width requirement, and resulting frames or screenshots for every accepted shell family. Label GUI-only mouse, trackpad, refresh-rate, and physical-notch observations honestly when they cannot be captured in the current environment.

## Non-Goals

This document does not approve production data wiring, auth storage, MediaRemote control, Apple Music or Spotify integration, Keychain access, IPC, real playback, backend validation, or persisted todo updates. It also does not change the Windows Electron implementation, which remains the parity reference.
