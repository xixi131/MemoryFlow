# codex-progress.md

Current summary and recent high-signal records for the `MemoryFlow_Windows` branch. Older macOS migration history lives on `master` (`codex-progress.md` / `codex-progress-archive.md` there).

## Current summary
- 2026-07-17: Branch `MemoryFlow_Windows` cut from `master` (at 9d6ca3a) as the Windows product line. Direction: keep behavior parity with the macOS native island, then add new features.
- Bootstrap changes: removed `mac-island/`, mac docs/evidence and `mac-island-release.yml`; renamed the Phase 6 parity contract to `docs/windows-parity-contract.md` as the two-way baseline; rewrote `AGENTS.md`, `agent-state.md`, `feature_list.json` for the Windows line; Windows release trigger moved from `v*` to `win-v*` tags; removed tracked build artifacts (`dist-dev/`, `node_modules_old/`, `release_new/`) and extended `.gitignore`.
- Next: `win-parity-gap-audit` in `feature_list.json`.

## Records
(append newest first)
