# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 3 native visual-geometry queue and now has a broader Phase 4 shell foundation in place across sizing, diagnostics, shadow buffering, motion planning, preview content timing hooks, and interruptible preview-transition storage.

`IslandVisualStatePreview.swift` now routes shell-shadow animation through motion-plan timing instead of a generic shell spring, and the preview layer also accepts motion-driven content-visibility inputs via a transparent placeholder channel that keeps shell-only rendering unchanged while giving Phase 4 a content-timing seam.

`IslandWindowController.swift` now stores `IslandPreviewTransitionState`, cancels stale completion work items, and can retarget an in-flight preview transition to a newer tap or hover target without keeping stale lock state around. Hover entry and exit now reuse the same preview transition request path when the shell is cycling between compact and hover preview states.

`IslandPreviewContentVisibility.swift` and `IslandPreviewTransitionState.swift` now hold the two new Phase 4-only seams: one for opacity/blur timing inputs, and one for interruptible preview transition bookkeeping that can be validated without real business content or AppKit window mutation.

## First pending task
* Add Phase 4 preview controls for core motion paths.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 4 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-phase4-sizing-motion-acceptance.md` and `docs/evidence/mac-island-phase4/sizing-matrix.json`.
6. Read `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionTokens.swift`, `IslandPreviewContentVisibility.swift`, `IslandPreviewTransitionState.swift`, `IslandTransitionKind.swift`, and `IslandMotionEngine.swift`.
7. Read `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` and `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift`.
8. Read `mac-island/MemoryFlowIsland/Window/IslandSizingMatrixProbe.swift` and `IslandWindowSizingResult.swift` if the next task needs synthetic validation or sizing/motion coupling details.
9. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 3 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation still relies on the Swift render/typecheck path unless unrestricted runtime startup is available.
* The current Phase 4 validation path is: repository-wide Swift typecheck plus focused harnesses that check diagnostics fields, shadow buffer separation, motion-plan coverage, preview-state ordering, motion-driven content-visibility inputs, and interruptible preview-transition retargeting.
* The preview-state ordering and retargeting checks are synthetic model/harness results, not real GUI tap or hover capture.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* The external-display evidence for Phase 3 is a truthful synthetic `ScreenMetrics` harness result, not a physical second-display run.
* Business data, auth, preview control surfaces, and Phase 5 interaction/state-machine migration remain out of scope for the completed Phase 4 slice so far.
