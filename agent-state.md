# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration has completed the current Phase 3 native visual-geometry queue. The active queue now starts Phase 4: native sizing, content-driven width, shadow buffering, and Alcove/iPhone-like motion infrastructure.

Post-Phase 3 connector polish updated `IslandPathFactory.earPath(...)`: the Mac liquid connector still uses the migrated idle/activity/expanded tension and blend-height tokens, but its visible edge is now a smooth sampled continuous-corner curve instead of the original cubic patch.

Post-Phase 3 sizing polish added content-driven activity width inputs: `IslandContentWidthRequirement` and `IslandWidthConstraints` live in `IslandShapeMetrics.swift`; `IslandVisualState.previewContentWidthRequirement` currently provides a preview-only activity stand-in; `IslandWindowController` only passes screen/notch constraints into the shape engine.

Migration plan update on 2026-04-27: Phase 4+ is now oriented toward Alcove/iPhone-like native feel, not just Windows parity. Phase 4 should build sizing plus motion infrastructure; Phase 5 should model mock state plus interaction intents and interruptible animation paths; Phase 6 content must declare width requirements; Phase 8 music activity width is content-driven; Phase 9 becomes real-input calibration and animation/performance QA.

## First pending task
* Add native sizing result types for Phase 4 window layout.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read `feature_list.json`.
4. Read the Phase 4 section in `灵动岛迁移方案.md`.
5. Read `docs/mac-island-phase3-geometry-handoff.md` for Phase 3 inputs.
6. Read `mac-island/MemoryFlowIsland/UI/Visual/` and `mac-island/MemoryFlowIsland/Window/` for sizing and motion implementation tasks.
7. Read `feature_list_summary.json` only if you need completed Phase 0 to Phase 3 history.

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
