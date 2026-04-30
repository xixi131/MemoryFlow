# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Phase 5 is active: native state machine, mock scenarios, and preview-visible gesture behavior for the macOS island shell.

The first 27 Phase 5 tasks are complete. The reducer now covers reminder due and paused-music timeout intents, `IslandMockScenario.phase5Catalog` defines the required 10 mock scenarios, `docs/evidence/mac-island-phase5/` contains scenario-matrix, interaction-sequence, preview-interaction, scenario-selection, and interaction-demo menu probe JSON, and `IslandWindowController` now owns Phase 5 preview state plus reducer-backed tap, hover, pointer, trackpad, status-menu scenario routing, and status-menu interaction demo routing.

Phase 5 remains intentionally mock-driven. Do not add real backend calls, real music provider integration, or Phase 6 content layouts in this slice.

## First pending task
* `Add minimal mock content markers so Phase 5 state changes are visible.`

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json` and select the first pending task.
4. Read the Phase 5 section in `灵动岛迁移方案.md`.
5. Read only the matching rows in `docs/mac-island-state-spec.md`, `docs/mac-island-interaction-spec.md`, and `docs/mac-island-animation-spec.md`.
6. Read `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`, `mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift`, `mac-island/MemoryFlowIsland/MenuBar/StatusBarController.swift`, and `docs/evidence/mac-island-phase5/` first.

## Runtime notes
* `init.sh` is still the runtime entry point for full execution-path work.
* `xcodebuild` is unavailable in the current environment because the active developer directory is CommandLineTools only.
* Lightweight native verification can use `swiftc -module-cache-path /tmp/... -typecheck` plus focused Swift probes.
* `init.sh` may fail in the sandbox because port `8080` is already occupied or local bind attempts hit `SocketException: Operation not permitted` / `listen EPERM`; Phase 5 native work can fall back to probe-driven verification when that happens.

## Active blockers / caveats
* No active feature blocker is recorded at startup.
* Phase 4 motion-profile and interruptibility evidence still need physical-device calibration later.
* Remaining Phase 5 work should stay preview-only and mock-only until later phases explicitly expand scope.
* The Phase 5 scenarios submenu is gated by `MEMORYFLOW_ISLAND_PHASE5_SCENARIOS=1`; Phase 5 interaction demo controls are preview-only and reducer-backed when Phase 5 preview routing is enabled.
