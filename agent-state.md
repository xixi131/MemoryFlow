# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration is now in the Phase 3 native visual-geometry queue for token mapping, path parity, preview shells, and top-band-aware scaling in `mac-island/MemoryFlowIsland/UI/`.

## First pending task
* Implement `IslandVisualTokens.swift` as the single Swift geometry-token source for Phase 3 previews.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 3 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-visual-token-map.md` and `docs/mac-island-phase3-geometry-acceptance.md`.
6. Read `front-end/src/components/DynamicIslandWidget.tsx` for the Windows path functions and visual constants.
7. Read `mac-island/MemoryFlowIsland/UI/IslandRootView.swift`, then `mac-island/MemoryFlowIsland/UI/Visual/` and `mac-island/MemoryFlowIsland/Window/` as needed for preview and top-band scaling integration.
8. Read `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` when adding new Visual files to the native target.
9. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 2 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* Phase 3 should prefer native preview verification and screenshot evidence over business-data wiring.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* Keep Phase 3 scoped to visual geometry only: do not mix in Phase 4 window-sizing refactors beyond required size plumbing, and do not start Phase 5 state-machine or business-data migration from this queue.
