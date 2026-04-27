# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 4 sizing-and-motion queue. The native shell now has sizing outputs, content-driven width constraints, expanded shadow buffering, motion profiles, preview content-visibility timing hooks, interruptible preview-transition storage, preview-motion controls, and linked synthetic evidence captured in the Phase 4 acceptance and checklist docs.

`docs/mac-island-phase4-sizing-motion-acceptance.md` is now the canonical Phase 4 evidence gate for sizing outputs, content-driven width, shadow buffering, motion profiles, and interruptible transitions. `docs/mac-island-migration-checklist.md` now mirrors those gates at the broader migration-checklist layer, with sizing and shadow items marked `Passed` and motion or interruptibility items left `Real-device pending` until physical-device calibration exists.

`IslandWindowController.swift`, `IslandMotionEngine.swift`, `IslandVisualStatePreview.swift`, `IslandPreviewContentVisibility.swift`, `IslandPreviewTransitionState.swift`, and `IslandSizingMatrixProbe.swift` are the main Phase 4 native seams to revisit if the next queue expands into Phase 5 interaction/state-machine migration or real-device motion calibration.

## First pending task
* None. `feature_list.json` is fully passed at the moment.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. If the next work continues this slice, read the Phase 4 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-phase4-sizing-motion-acceptance.md` and `docs/mac-island-migration-checklist.md`.
6. Read `docs/evidence/mac-island-phase4/sizing-matrix.json`, `shadow-capture-checks.json`, and `motion-frame-sequences.md` only when evidence details are needed.
7. Read `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionTokens.swift`, `IslandPreviewContentVisibility.swift`, `IslandPreviewTransitionState.swift`, `IslandTransitionKind.swift`, and `IslandMotionEngine.swift` only if the next task changes motion behavior.
8. Read `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`, `IslandSizingMatrixProbe.swift`, and `IslandWindowSizingResult.swift` only if the next task changes sizing, preview routing, or synthetic validation.
9. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 3 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation still relies on the Swift render/typecheck path unless unrestricted runtime startup is available.
* The current Phase 4 validation path is: repository-wide Swift typecheck plus focused harnesses that check diagnostics fields, sizing-matrix coverage, shadow-capture boundary clearance, motion-plan coverage, preview-state ordering, motion-driven content-visibility inputs, and interruptible preview-transition retargeting.
* `MEMORYFLOW_ISLAND_PREVIEW_CONTROLS=1` enables the new local preview-motion submenu in the native status menu for manual motion-path checks without touching business data.
* The preview-state ordering, motion-control coverage, and retargeting checks are synthetic model/harness results, not real GUI tap, menu-click, or hover capture.
* The refreshed `docs/evidence/mac-island-phase4/sizing-matrix.json` evidence is synthetic harness output, not a physical-device AppKit capture.
* The refreshed expanded shadow captures and `shadow-capture-checks.json` are padded synthetic CoreGraphics renders; they confirm the exported evidence no longer hard-clips side or bottom shadow fade, but they are still not physical-device AppKit captures.
* The new motion frame-sequence evidence is synthetic motion-plan output (`motion-frame-sequences.md` / `.json`), not a physical-device AppKit capture, GIF, or video.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* The queue is currently empty; if the product scope changed or a new slice should begin, regenerate tasks before resuming `$Auto_dev`.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* The external-display evidence for Phase 3 is a truthful synthetic `ScreenMetrics` harness result, not a physical second-display run.
* Business data, auth, and Phase 5 interaction/state-machine migration remain out of scope for the completed Phase 4 slice so far.
* Motion and interruptibility checklist gates still require physical-device calibration even though the current synthetic evidence path is complete.
