# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration is now queued for Phase 5: native state machine, interaction intents, and mock animation scenarios. The completed Phase 4 sizing-and-motion queue has been archived into `feature_list_summary.json`; the first 11 Phase 5 tasks are now complete and `feature_list.json` has 30 pending Phase 5 tasks.

The Phase 5 queue is intentionally mock-driven. It should make state changes, hover, tap, pointer swipe, trackpad gestures, and scenario switching visibly testable in the native island shell before Phase 6 content migration, Phase 7 app data, or Phase 8 real music provider work begins.

Recent local fix to keep in mind: `IslandVisualStatePreview.swift` offsets the SwiftUI shell by the bottom shadow outset so expanded and hover states stay visually attached to the notch while preserving bottom shadow buffer space.

Recent Phase 5 docs handoff: `docs/mac-island-phase5-interaction-state-acceptance.md` now contains the acceptance shell plus state, derived-state, mouse, pointer, and trackpad rows with links to the migration plan and baseline specs.

Recent Phase 5 native model handoff: `mac-island/MemoryFlowIsland/State/IslandDomainState.swift` defines mock-driven domain state and payload sources, `mac-island/MemoryFlowIsland/State/IslandInteractionIntent.swift` defines pure interaction intents plus Windows baseline thresholds, and `mac-island/MemoryFlowIsland/State/IslandDerivedState.swift` now resolves Phase 5 visual-state decisions with a matching probe in `IslandDerivedStateProbe.swift`.

Recent Phase 5 reducer handoff: `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` now provides a pure reducer shell that returns next state plus transition reason, and `IslandPresentationReducerProbe.swift` validates unknown/no-op intents preserve state and derived visual output.

Recent Phase 5 compact derivation handoff: reducer results now expose `derivedState` directly so compact visual output can be checked through the reducer path, and `IslandDerivedStateProbe.swift` now covers both logged-out compact and logged-in review compact rows.

Recent Phase 5 app-activity derivation handoff: `IslandDomainState.swift` now exposes reusable logged-in review and todo activity mock states, `IslandDerivedStateProbe.swift` covers both app activity rows plus todo compact width, and `IslandPresentationReducerProbe.swift` validates review/todo activity visual output through the reducer result path.

Recent Phase 5 music derivation handoff: `IslandDomainState.swift` now exposes a reusable `musicCompactFallback` mock state, `IslandDerivedStateProbe.swift` covers both music activity and music compact fallback rows, and `IslandPresentationReducerProbe.swift` validates the same music takeover states through the reducer result path without any real provider integration.

Recent Phase 5 tap reducer handoff: `IslandPresentationReducer.swift` now expands compact/activity states into app or music expanded presentation on tap, collapses expanded states back to activity or compact on tap or outside-collapse based on activity-source availability, and `IslandPresentationReducerProbe.swift` now validates reducer-backed tap sequences for app/music compact and activity recovery.

## First pending task
* `Implement hover enter and hover leave transitions in the reducer.`

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json` and select the first pending task.
4. Read the Phase 5 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-state-spec.md`, `docs/mac-island-interaction-spec.md`, and `docs/mac-island-animation-spec.md` only for the task-specific rows being implemented.
6. Read `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift`, `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift`, `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`, `mac-island/MemoryFlowIsland/UI/IslandRootView.swift`, `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift`, `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionEngine.swift`, and the menu files when wiring visible preview interactions.
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
* The first 11 Phase 5 tasks are complete; remaining Phase 5 tasks still start with `passes: false`.
* Motion and interruptibility checklist gates from Phase 4 still require physical-device calibration later.
* The current queue is designed so the user can see state-switching effects before real content and real provider integration land.
