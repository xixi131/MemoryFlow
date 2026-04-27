# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration is now queued for Phase 5: native state machine, interaction intents, and mock animation scenarios. The completed Phase 4 sizing-and-motion queue has been archived into `feature_list_summary.json`; the first 6 Phase 5 tasks are now complete and `feature_list.json` has 35 pending Phase 5 tasks.

The Phase 5 queue is intentionally mock-driven. It should make state changes, hover, tap, pointer swipe, trackpad gestures, and scenario switching visibly testable in the native island shell before Phase 6 content migration, Phase 7 app data, or Phase 8 real music provider work begins.

Recent local fix to keep in mind: `IslandVisualStatePreview.swift` offsets the SwiftUI shell by the bottom shadow outset so expanded and hover states stay visually attached to the notch while preserving bottom shadow buffer space.

Recent Phase 5 docs handoff: `docs/mac-island-phase5-interaction-state-acceptance.md` now contains the acceptance shell plus state, derived-state, mouse, pointer, and trackpad rows with links to the migration plan and baseline specs.

Recent Phase 5 native model handoff: `mac-island/MemoryFlowIsland/State/IslandDomainState.swift` defines mock-driven domain state and payload sources, `mac-island/MemoryFlowIsland/State/IslandInteractionIntent.swift` defines pure interaction intents plus Windows baseline thresholds, and `mac-island/MemoryFlowIsland/State/IslandDerivedState.swift` now resolves Phase 5 visual-state decisions with a matching probe in `IslandDerivedStateProbe.swift`.

## First pending task
* `Create the Phase 5 presentation reducer shell.`

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json` and select the first pending task.
4. Read the Phase 5 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-state-spec.md`, `docs/mac-island-interaction-spec.md`, and `docs/mac-island-animation-spec.md` only for the task-specific rows being implemented.
6. Read `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`, `mac-island/MemoryFlowIsland/UI/IslandRootView.swift`, `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift`, `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionEngine.swift`, and the menu files when wiring visible preview interactions.
7. Read `feature_list_summary.json` only if completed Phase 0 to Phase 4 history is needed.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation may rely on Swift typecheck plus focused synthetic probes unless unrestricted runtime startup is available.
* Phase 5 visible-effect tasks should prefer a native preview/menu path gated by environment flags and should truthfully record when physical-device hover, pointer, or trackpad evidence is unavailable.
* Phase 5 should not add real backend calls, real music provider integration, or full Phase 6 content layouts. Use mock state, mock scenario rows, and minimal preview markers only.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* The first 6 Phase 5 tasks are complete; remaining Phase 5 tasks still start with `passes: false`.
* Motion and interruptibility checklist gates from Phase 4 still require physical-device calibration later.
* The current queue is designed so the user can see state-switching effects before real content and real provider integration land.
