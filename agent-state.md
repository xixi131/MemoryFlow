# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 3 native visual-geometry queue and now has a broader Phase 4 shell foundation in place across sizing, diagnostics, shadow buffering, and first-pass motion planning.

`IslandWindowSizingResult.swift` now carries preview-safe diagnostics for state, scales, visible size, shadow size, content size, and hit frame. `IslandWindowController.swift` can gate those logs behind `MEMORYFLOW_ISLAND_SIZING_DIAGNOSTICS=1`, while preview state changes now derive an `IslandMotionPlan` before updating root-view inputs or animation timing.

`IslandSizingMatrixProbe.swift` now generates synthetic Phase 4 display coverage, and `docs/evidence/mac-island-phase4/sizing-matrix.json` currently records compact, activity, expanded music, and expanded app sizing on notch and flat-top displays.

Expanded shadow buffer values now live in `IslandVisualTokens.shadow`, and `IslandShapeEngine.snapshot(...)` correctly offsets `visibleFrame` above the bottom shadow buffer so `IslandPanel` receives real downward shadow space instead of a collapsed zero-bottom inset.

## First pending task
* Apply motion profiles to SwiftUI shell shadow transitions.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 4 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-phase4-sizing-motion-acceptance.md` and `docs/evidence/mac-island-phase4/sizing-matrix.json`.
6. Read `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionTokens.swift`, `IslandTransitionKind.swift`, and `IslandMotionEngine.swift`.
7. Read `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`, `IslandWindowSizingResult.swift`, and `IslandSizingMatrixProbe.swift`.
8. Read `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift`, `IslandVisualTokens.swift`, and `IslandShapeEngine.swift` if the next task needs shell-shadow or frame-offset details.
9. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 3 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation still relies on the Swift render/typecheck path unless unrestricted runtime startup is available.
* The current Phase 4 validation path is: repository-wide Swift typecheck plus the focused harness that regenerates `docs/evidence/mac-island-phase4/sizing-matrix.json` and checks diagnostics fields, shadow buffer separation, motion-plan coverage, and preview-state ordering.
* The preview-state ordering check is synthetic (`compact -> hover -> activity -> expandedMusic -> expandedApp`), not a real GUI tap capture.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* The external-display evidence for Phase 3 is a truthful synthetic `ScreenMetrics` harness result, not a physical second-display run.
* Business data, auth, preview content timing hooks, and interruptible Phase 5 state storage remain out of scope for the completed Phase 4 slice so far.
