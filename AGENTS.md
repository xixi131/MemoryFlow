# AGENTS.md

This file is the project-memory entry point for the **MemoryFlow_Windows** branch. Keep it focused on project facts, module routing, and durable constraints. Generic parent-child automation SOP lives in the global `$Auto_dev` and `$Task_init` skills when available.

## 1. Project Summary
* **Project:** MemoryFlow (Windows product line, branch `MemoryFlow_Windows`)
* **Domain:** An AI-assisted study planning and memory-flow system with a browser web app, a Spring Boot backend, and a Windows Electron Dynamic Island desktop widget.
* **Goal:** Evolve the Windows Electron island as a first-class product line: keep behavior parity with the macOS native island (maintained on `master`) unless a divergence is explicitly approved, and ship new features on top of that parity baseline.
* **Tech stack:** React 19, Vite, Electron 40 (NSIS/`electron-updater`), Spring Boot 3, MySQL, Redis. There is no macOS native code on this branch; `mac-island/` lives on `master` only.

## 2. Minimal Read Order
Use the smallest context that can safely start the task:
1. Read `AGENTS.md`.
2. Read `agent-state.md` for the current phase, next focus, and recommended entry files.
3. Read `feature_list.json` and select the assigned task.
4. Read `docs/windows-parity-contract.md` when the task touches island states, constants, or transition sequences.
5. Read `init.sh` only when the task needs runtime startup.
6. Read `codex-progress.md` only if `agent-state.md` is not enough.

## 3. Coordination Files
Treat these files as the durable coordination layer:
* `AGENTS.md`: stable project facts and read-routing.
* `agent-state.md`: short current-state handoff for the next agent.
* `feature_list.json`: ordered task queue and completion state for this branch.
* `codex-progress.md`: current summary plus recent high-signal records.
* `codex-progress-archive.md`: stub on this branch; the macOS migration history lives on `master`.
* `init.sh`: repository bootstrap and runtime safety line.

## 4. Project Map
Read only the slice that matches the task:
* `front-end/src/`: React UI, widget logic (`components/DynamicIslandWidget.tsx`), browser-visible behavior.
* `front-end/electron/`: Electron main-process and bridge logic — widget window, tray, `memoryflow://` protocol, SMTC music takeover (`MusicService.cjs`), `electron-updater` flow, release config.
* `back-end/`: Spring Boot APIs, persistence, scheduling, and supporting services.
* `docs/windows-parity-contract.md`: the state/constant/sequence contract shared with the macOS island.
* `project_DS/`: repository standards, UI design system, core architecture, workflow docs.

## 5. Critical Project Memory
Keep these branch-specific constraints in mind before changing behavior:
* **Parity first:** the macOS island (on `master`) and the Windows island must stay behavior-equivalent. Before changing island states, timings, or interaction sequences, check `docs/windows-parity-contract.md`; divergences require explicit approval and a documented contract update.
* **Shared code belongs on master:** changes to `front-end/src/` (non-widget) and `back-end/` that both platforms need should be made on `master` and merged into this branch. This branch carries Windows-specific work: `front-end/electron/`, packaging, Windows CI, and widget behavior work scheduled in `feature_list.json`.
* **Release channel is separate:** this branch releases via `win-v*` tags (e.g. `win-v1.0.9`). CI builds an NSIS installer and publishes to the `xixi131/MemoryFlow.exe` GitHub repository, which is also the `electron-updater` feed for existing users — do not change `appId`, the publish repository, or the artifact naming without an explicit migration plan, or existing installs lose auto-update.
* **Auth reuse boundary:** the desktop widget reuses the browser login page, `POST /auth/login`, JWT, and the `memoryflow://callback?token=...` contract. Do not build a native credentials form in the widget.
* **Evidence quality matters:** do not present runtime claims without evidence from browser/runtime observation or directly cited code paths.

## 6. Task Routing
Use the right reference file for the task instead of rereading everything:
* **Task planning / queue regeneration:** `agent-state.md`, `feature_list.json`, `project_DS/workflows/task_init_loop.md`
* **General repository standards:** `project_DS/specification/project_standards.md`
* **Frontend/UI/widget behavior:** `project_DS/specification/ui_design_system.md`, `docs/windows-parity-contract.md`
* **Architecture / backend / module boundaries:** `project_DS/specification/project_core_architecture.md`
* **Release / update flow:** `.github/workflows/release.yml`, `front-end/electron/release-config.cjs`, `front-end/electron-builder.config.cjs`

## 7. Working Style
* Prefer targeted reads over repository-wide scanning.
* Keep `agent-state.md` short and current so future agents do not need to reread the full progress log.
* Preserve project-specific content; when slimming context, remove duplicated process text before removing project facts.

## 8. Branch Note
This branch was cut from `master` on 2026-07-17. `master` continues to carry the macOS native island (`mac-island/`, its docs and release workflow), which were removed here. When porting a macOS Phase 7 behavior to Windows, read the corresponding implementation on `master` for reference; do not re-add macOS build artifacts to this branch.
