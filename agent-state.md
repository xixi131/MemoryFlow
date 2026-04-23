# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration is in the Phase 2 native macOS window-system queue for notch-aware positioning, window anchoring, click-through, and hover behavior in `mac-island/`.

## First pending task
* Center the island shell against the notch-safe top region on notch displays.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 2 section in `灵动岛迁移方案.md`.
5. Read `mac-island/MemoryFlowIsland/Window/ScreenMetrics.swift`, `DisplayTopEdgeClassifier.swift`, `NotchLayoutEngine.swift`, `DisplayObserver.swift`, and `IslandWindowController.swift`.
6. Read `codex-progress.md` only if you need the recent Phase 1 implementation trail or acceptance context.

## Runtime notes
* `init.sh` exists and is the runtime entry point.
* Default validation path is web unless a task explicitly needs Electron or native-shell verification.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell tasks can use `swiftc -module-cache-path /tmp/... -typecheck` as the practical compile check; `init.sh` currently hits a sandbox `EPERM` when Vite binds `0.0.0.0:3000`.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* If commit or git post-processing fails after implementation/test work succeeds, treat it as a post-processing blocker rather than a feature failure.
* Phase 2 should stay scoped to the native shell layer; do not mix in Phase 3 state-machine work or Phase 4 business-data migration while executing the new queue.
