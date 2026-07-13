# Phase 6 Mock Animation Acceptance

## Scope And Evidence Standard

Phase 6 accepts the native macOS island's deterministic mock presentation of review, todo, reminder, greeting, and music states. It is a visual and interaction-parity review surface only. A `Passed` row below is supported by deterministic native-model frames or an explicitly labeled Swift fallback probe; it is not a claim of physical-device GUI capture.

The mock-only queue excludes backend services, authentication, MediaRemote, Apple Music, Spotify, Keychain, and IPC integration. No real media command, account state, persisted todo mutation, or remote data call is an acceptance prerequisite.

## References

- [State specification](mac-island-state-spec.md)
- [Interaction specification](mac-island-interaction-spec.md)
- [Animation specification](mac-island-animation-spec.md)
- [Migration plan: Phase 6, collapsed/activity/expanded content views](../灵动岛迁移方案.md#phase-6迁移-collapsedactivityexpanded-内容视图)

## Windows States And Mock Modules

| Status | Windows-parity state or module | Native implementation | Evidence |
| --- | --- | --- | --- |
| Passed | Logged-out compact, logged-in compact, and greeting compact | `IslandMockScenario`, `IslandDerivedState`, `IslandVisualStatePreview`, `IslandGreetingSequence` | [`visual-state-frame-sequences.md`](evidence/mac-island-phase6/visual-state-frame-sequences.md) covers `logged-out-compact` and `greeting`; the greeting sequence has deterministic lifecycle probes. |
| Passed | Review and todo activity, including counters, subjects, six local todo rows, and width requests | `IslandMockScenario`, `IslandVisualStatePreview`, `IslandWindowSizingEngine` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers `review-activity` and `todo-activity`; [`mac-motion-e2e-mouse-fallback-probe.json`](evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json) covers mock todo success and rollback. |
| Passed | Music playing, paused, stopped fallback, activity, and expanded music | `IslandMockScenario`, `IslandMusicTakeover`, `IslandMusicWaveform`, `IslandMockMusicProgressClock`, `IslandVisualStatePreview` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers playing, paused, expanded, and stopped-fallback states. |
| Passed | Expanded review and todo layouts | `IslandVisualStatePreview`, `IslandContentChoreographyPlan`, `IslandWindowSizingEngine` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers `expanded-review` and `expanded-todo`. |
| Passed | Reminder due as an activity trigger, not a standalone presentation mode | `IslandPresentationReducer`, `IslandDerivedState`, `IslandContentChoreographyPlan` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers `reminder-due`. |

## Motion, Shell, And Content Choreography

| Status | Requirement | Native implementation | Evidence |
| --- | --- | --- | --- |
| Passed | Previous and next derived state, reducer reason, presentation snapshot, and Reduce Motion preference select one non-mutating motion plan. | `IslandMotionEngine`, `IslandMotionPlan`, `IslandMotionTokens` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) records transition kinds and frame samples for all required scenarios. |
| Passed | Compact, activity, and expanded shells interpolate geometry, shadow, and path metrics while preserving top-center attachment and synchronized interaction frames. | `IslandAnimationDriver`, `IslandShapeEngine`, `IslandWindowSizingEngine`, `IslandWindowController` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) records centered attachment, unclipped shadow, and seam checks for each sequence. |
| Passed | Activity open uses the Windows 0.56s baseline and delayed content choreography; collapse uses the 0.85s segmented profile. | `IslandMotionTokens`, `IslandMotionEngine`, `IslandContentChoreographyPlan` | [`visual-state-frame-sequences.md`](evidence/mac-island-phase6/visual-state-frame-sequences.md) records sampled start, intermediate, hold, content-enter, and settled frames. |
| Passed | Review/todo expand to 460 x 320 and music expands to 460 x 210 before display scaling; expanded content waits for usable shell geometry. | `IslandWindowSizingEngine`, `IslandContentChoreographyPlan`, `IslandVisualStatePreview` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers expanded review, todo, and music. |
| Passed | Content has hidden, exiting, waiting, entering, and visible phases; stale completion cannot restore old review, todo, or music content. | `IslandContentChoreographyPlan`, `IslandAnimationDriver`, `IslandVisualStatePreview` | [`mac-motion-e2e-mouse-fallback-probe.json`](evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json) covers rapid retarget and stale completion rejection. |
| Passed | Greeting enters, remains for ten seconds, exits, returns compact width, and is cancelled by music takeover. | `IslandGreetingSequence`, `IslandGreetingTransitionGate`, `IslandVisualStatePreview` | [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers `greeting`; deterministic greeting probes validate lifecycle and cancellation. |
| Passed | Playing waveform uses local mock state; paused waveform settles and stopped state releases music presentation. | `IslandMusicWaveform`, `IslandMockMusicProgressClock`, `IslandVisualStatePreview` | [`motion-performance-evidence.json`](evidence/mac-island-phase6/motion-performance-evidence.json) audits local waveform/clock behavior; [`visual-state-frame-sequences.json`](evidence/mac-island-phase6/visual-state-frame-sequences.json) covers paused and stopped outcomes. |

## Mouse Input

| Status | Requirement | Native implementation | Evidence |
| --- | --- | --- | --- |
| Passed with fallback evidence | Hover enter/leave breathes only compact shells, retains the top anchor, and recovers click-through. | `IslandHoverMonitor`, `IslandAnimationDriver`, `IslandWindowController` | [`mac-motion-e2e-mouse-fallback-probe.json`](evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json), rows `hover-enter-leave` and `outside-collapse-and-click-through-recovery`. |
| Passed with fallback evidence | Pointer tap expands/collapses, horizontal swipes move activity/compact, and long press switches review/todo under its lock. | `IslandPointerGestureAdapter`, `IslandPreviewInteractionProbe`, `IslandModeSwitchProbe` | [`mac-motion-e2e-mouse-fallback-probe.json`](evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json), rows `tap-expand-collapse`, `pointer-swipe-compact-activity`, and `long-press-review-todo-switch`. |
| Passed with fallback evidence | Rapid hover and expand/collapse requests retarget from live metrics; only the final callback settles state. | `IslandAnimationDriver`, `IslandAnimationDriverProbe` | [`mac-motion-e2e-mouse-fallback-probe.json`](evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json), rows `rapid-enter-leave-enter` and `rapid-expand-collapse-expand`. |

## Trackpad Input

| Status | Requirement | Native implementation | Evidence |
| --- | --- | --- | --- |
| Passed with fallback evidence | Vertical 70-point gestures open, expand, recover, and compact through adapter, reducer, motion plan, and driver. | `IslandInteractionHostingView`, `IslandTrackpadWheelAdapter`, `IslandTrackpadMotionE2EProbe` | [`trackpad-e2e-fallback.json`](evidence/mac-island-phase6/trackpad-e2e-fallback.json), `vertical-round-trip`. |
| Passed with fallback evidence | Horizontal 70-point commands control only mock music; equal-axis selection, 160ms reset, and 320ms cooldown are guarded. | `IslandTrackpadWheelAdapter`, `IslandPresentationReducer` | [`trackpad-e2e-fallback.json`](evidence/mac-island-phase6/trackpad-e2e-fallback.json), `horizontal-music` and `ignored-input`. |

## Accessibility And Performance

| Status | Requirement | Native implementation | Evidence |
| --- | --- | --- | --- |
| Passed | Reduce Motion replaces nonessential animated presentation while preserving derived state and input routing; interactive mock controls have labels. | `IslandWindowController`, `IslandMotionEngine`, `IslandVisualStatePreview` | `IslandWindowController` observes `accessibilityDisplayOptionsDidChangeNotification`; `IslandVisualStatePreview` labels login, greeting, artwork, lists, tasks, and playback controls. |
| Passed with deterministic evidence | Shell morph, waveform, content stagger, retarget, and shadow workloads have bounded native-model samples at simulated 60Hz and 120Hz; no retained driver callbacks or clocks are recorded. | `IslandAnimationDriver`, `IslandAnimationDisplayLink`, `IslandShapeEngine`, `IslandMusicWaveform`, `IslandMockMusicProgressClock` | [`motion-performance-evidence.md`](evidence/mac-island-phase6/motion-performance-evidence.md) and [`motion-performance-evidence.json`](evidence/mac-island-phase6/motion-performance-evidence.json). |

## Evidence Limits And Future Work

The linked mouse and trackpad artifacts are Swift fallback probes, not physical GUI input captures. Frame sequences are deterministic native-model frames, not screenshots or video. Performance cadence is simulated rather than measured from a physical display or Instruments trace.

- Physical-device spring calibration, mouse/trackpad feel, notch attachment, hover focus, and 60Hz/120Hz GUI capture remain pending.
- Instruments, Core Animation FPS, GPU, and main-thread profiling remain pending.
- Real provider integration remains out of scope: backend data, authentication, persisted todo updates, MediaRemote, Apple Music, Spotify, Keychain, and IPC.
- The Windows Electron implementation remains read-only parity reference and is not changed by this acceptance.

## Non-Goals

This document does not approve production data wiring, auth storage, real playback, real media commands, backend validation, or persisted todo updates.
