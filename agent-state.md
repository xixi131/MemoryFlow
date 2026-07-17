# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
The `MemoryFlow_Windows` branch was bootstrapped from `master` on 2026-07-17 as the Windows product line. macOS native content (`mac-island/`, mac docs and evidence, `mac-island-release.yml`, `灵动岛迁移方案.md`) was removed; the Windows release pipeline now triggers on `win-v*` tags. The earlier "Windows Electron must not be modified" constraint from the macOS migration is **lifted on this branch** — Windows Electron code is the primary modification target here.

## Product direction
Keep the Windows island behavior-equivalent to the macOS native island (maintained on `master`), then build new features on top. The immediate queue back-ports the macOS Phase 7 capabilities that Windows lacks.

## Queue status
`win-parity-gap-audit` is complete: `docs/windows-parity-gap.md` records 10 gaps (G1-G10) with code citations, 7 intentional divergences (D1-D7), and n/a items. The audit added `win-reduce-motion-support` to the queue and confirmed the other task scopes. Next task: `win-login-free-music-default` (gaps G1+G2; the only G1 blocker is the renderer-side login gate at `DynamicIslandWidget.tsx:686`). No task is in progress.

## Key entry files
- `front-end/src/components/DynamicIslandWidget.tsx`: all island states, timings, and interactions.
- `front-end/electron/main.cjs` (1802 lines): widget window, tray, protocol callback, updater, region-aware update sources. Modularization is a scheduled task — avoid drive-by refactors before it.
- `front-end/electron/MusicService.cjs`: SMTC music takeover.
- `docs/windows-parity-contract.md`: the shared state/constant/sequence contract; treat as the parity baseline.

## Durable constraints
- Parity divergences need explicit approval plus a contract update in `docs/windows-parity-contract.md`.
- Shared (`front-end/src/` non-widget, `back-end/`) changes should land on `master` and be merged in, to limit branch drift.
- Do not change `appId`, the `xixi131/MemoryFlow.exe` publish repository, or artifact naming — existing installs auto-update from that feed.
- Reuse the browser login + `memoryflow://callback` auth contract; no native credentials UI.

## Release
- Tag `win-vX.Y.Z` on this branch → `.github/workflows/release.yml` builds NSIS on `windows-latest` and publishes to `xixi131/MemoryFlow.exe` (requires `GH_RELEASE_TOKEN` secret).
- `v*` tags no longer trigger the Windows release; they belong to the macOS pipeline on `master`.
