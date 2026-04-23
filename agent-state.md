# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Dynamic Island migration is in Phase 1 native macOS shell scaffolding. Phase 0 baseline/spec capture is complete enough to support implementation, and the active queue is now filling out the standalone native shell around `mac-island/`.

## First pending task
* `frontend`
* `Add app resource placeholders and basic mac app metadata for standalone launch.`

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read the first pending item in `feature_list.json`.
4. If the pending task is still the app-resources task, read:
   * `灵动岛迁移方案.md`
   * `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj`
   * `mac-island/MemoryFlowIsland/Resources/`
   * `mac-island/MemoryFlowIsland/App/`
   * `mac-island/MemoryFlowIsland/MenuBar/`
5. Read `codex-progress.md` for the compressed recent log.
6. Read `codex-progress-archive.md` only if you need full historical detail.

## Runtime notes
* `init.sh` exists and is the runtime entry point.
* Default validation path is web unless a task explicitly needs Electron or native-shell verification.
* `xcodebuild` is still unavailable in the current environment because the active developer directory is CommandLineTools only.

## Active blockers / caveats
* No feature blocker is recorded at startup.
* If commit or git post-processing fails after implementation/test work succeeds, treat it as a post-processing blocker rather than a feature failure.
