# codex-progress.md

Current summary and recent high-signal records for the `MemoryFlow_Windows` branch. Older macOS migration history lives on `master` (`codex-progress.md` / `codex-progress-archive.md` there).

## Current summary
- 2026-07-17: Branch `MemoryFlow_Windows` cut from `master` (at 9d6ca3a) as the Windows product line. Direction: keep behavior parity with the macOS native island, then add new features.
- Bootstrap changes: removed `mac-island/`, mac docs/evidence and `mac-island-release.yml`; renamed the Phase 6 parity contract to `docs/windows-parity-contract.md` as the two-way baseline; rewrote `AGENTS.md`, `agent-state.md`, `feature_list.json` for the Windows line; Windows release trigger moved from `v*` to `win-v*` tags; removed tracked build artifacts (`dist-dev/`, `node_modules_old/`, `release_new/`) and extended `.gitignore`.
- Next: `win-parity-gap-audit` in `feature_list.json`.

## Records
(append newest first)

### 2026-07-17 - win-parity-gap-audit
- Produced `docs/windows-parity-gap.md`: 10 gaps (login-free music, compact login entry removal, Advanced Features, login-required square, island update prompt/download, 24h checks, Reduce Motion, summary 30s polling, collapse continuity), 7 kept divergences (NSIS engine, gh-proxy sources, skip-version, SMTC, tray settings surface, non-always-on-top, localStorage tokens), and n/a items (notch, Gatekeeper, Sparkle).
- Evidence gathered by direct code inspection with line citations; key findings: music gate is renderer-only (`DynamicIslandWidget.tsx:686`), update UX is dialog+data-URL windows with a one-shot 5s startup check and 6h reminder, widget has no reduced-motion handling.
- Queue updated: audit marked passed, `win-reduce-motion-support` added, update-task scope extended to remove native dialogs while keeping D2/D3.
