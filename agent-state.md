# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 3 native visual-geometry queue and has now landed the first Phase 4 sizing slice in the native window layer.

`IslandWindowSizingEngine.swift` now owns the Phase 4 shell-sizing path: it accepts `IslandVisualState`, `TopAttachmentMetrics`, and `IslandWidthConstraints`, resolves `IslandShapeEngine.snapshot(...)`, applies shadow-aware display-width clamping, and returns screen-space `visibleFrame`, `shadowFrame`, `contentFrame`, and `hitTestFrame` via `IslandWindowSizingResult`.

`IslandWindowController` now derives preview width constraints, requests sizing through `IslandWindowSizingEngine`, feeds the resolved constraints back into `IslandRootView`, and applies panel placement from the sizing result instead of assembling sizing inline.

The current narrow-screen synthetic probe confirms that compact, activity, expanded music, and expanded app preview states all produce non-empty sizing output, and that expanded shadow output clamps inside a `320`-point top-band width while staying center-anchored.

Migration plan update on 2026-04-27 still stands: Phase 4+ is oriented toward Alcove/iPhone-like native feel, not just Windows parity. Phase 4 should continue with diagnostics, sizing matrices, shadow-buffer tuning, and motion infrastructure before Phase 5 mock-state and interruptible-animation work.

## First pending task
* Add sizing diagnostics for Phase 4 preview states.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 4 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-phase3-geometry-handoff.md` for Phase 3 inputs.
6. Read `docs/mac-island-phase4-sizing-motion-acceptance.md`, then `mac-island/MemoryFlowIsland/Window/IslandWindowSizingEngine.swift`, `mac-island/MemoryFlowIsland/Window/IslandWindowSizingResult.swift`, and `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`.
7. Read `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeEngine.swift` and `IslandShapeMetrics.swift` if the next task needs sizing-input or snapshot internals.
8. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 3 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation still relies on the Swift render/typecheck path unless unrestricted runtime startup is available.
* The latest Phase 4 sizing probe compiled a focused harness to validate non-empty compact/activity/expanded sizing plus shadow-aware clamping on a synthetic `320`-point display width.
* The current Phase 3 acceptance evidence includes native render-harness PNGs, path-sample parity JSON, and synthetic `ScreenMetrics` scaling matrices.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* The external-display evidence for Phase 3 is a truthful synthetic `ScreenMetrics` harness result, not a physical second-display run.
* Business data, auth, and Phase 5 state-machine migration remain out of scope for the completed Phase 3 slice.
