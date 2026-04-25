# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 3 native visual-geometry queue in `mac-island/MemoryFlowIsland/UI/` and the handoff is now ready for the Phase 4 window-sizing slice.

## First pending task
* No pending task remains in the current `feature_list.json` queue.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read `docs/mac-island-phase3-geometry-acceptance.md` and `docs/mac-island-phase3-geometry-handoff.md`.
5. Read the Phase 4 section in `灵动岛迁移方案.md`.
6. Read `mac-island/MemoryFlowIsland/UI/Visual/` and `mac-island/MemoryFlowIsland/Window/` if the next task needs to extend sizing or animation containers.
7. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 2 history.

## Runtime notes
* `init.sh` exists and remains the runtime entry point when full startup is required.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.
* Native-shell compile checks can still use `swiftc -module-cache-path /tmp/... -typecheck` when a task needs a lightweight verification path.
* In the current sandbox, `init.sh` can fail with occupied-port or bind-permission errors (`SocketException: Operation not permitted`, `listen EPERM`), so native-shell validation still relies on the Swift render/typecheck path unless unrestricted runtime startup is available.
* The current Phase 3 acceptance evidence includes native render-harness PNGs, path-sample parity JSON, and synthetic `ScreenMetrics` scaling matrices.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* `feature_list_summary.json` now stores the completed historical queue that was previously in `feature_list.json`.
* The external-display evidence for Phase 3 is a truthful synthetic `ScreenMetrics` harness result, not a physical second-display run.
* Business data, auth, and Phase 5 state-machine migration remain out of scope for the completed Phase 3 slice.
