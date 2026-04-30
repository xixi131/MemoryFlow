# AGENTS.md

This file is the project-memory entry point for MemoryFlow. Keep it focused on project facts, module routing, and durable constraints. Generic parent-child automation SOP lives in the global [$Auto_dev](/Users/tangxitao/.codex/skills/Auto_dev/SKILL.md) and [$Task_init](/Users/tangxitao/.codex/skills/Task_init/SKILL.md) skills.

## 1. Project Summary
* **Project:** MemoryFlow
* **Domain:** An AI-assisted study planning and memory-flow system with web, Electron, and macOS native Dynamic Island surfaces.
* **Goal:** Deliver the macOS native Dynamic Island migration without losing clarity about current Windows Electron behavior or breaking the broader learning workflow product.
* **Tech stack:** React 19, Vite, Electron, Spring Boot 3, MySQL, Redis, Swift/AppKit helper in `mac-island/`

## 2. Minimal Read Order
Use the smallest context that can safely start the task:
1. Read `AGENTS.md`.
2. Read `agent-state.md` for the current phase, next focus, and recommended entry files.
3. Read `feature_list.json` and select the assigned task.
4. Read `init.sh` only when the task needs runtime startup.
5. Read `codex-progress.md` only if `agent-state.md` is not enough, or when you need audit detail for a specific recent task.
6. Read `project_DS/` only for the task-specific doc you actually need.

## 3. Coordination Files
Treat these files as the durable coordination layer:
* `AGENTS.md`: stable project facts and read-routing.
* `agent-state.md`: short current-state handoff for the next agent.
* `feature_list.json`: ordered task queue and completion state.
* `codex-progress.md`: current summary plus recent high-signal records for default startup.
* `codex-progress-archive.md`: older detailed history and audit trail, read only when you need deeper implementation context.
* `init.sh`: repository bootstrap and runtime safety line.

## 4. Project Map
Read only the slice that matches the task:
* `front-end/src/`: React UI, widget logic, browser-visible behavior.
* `front-end/electron/`: Electron main-process and bridge logic, including Windows desktop integration and music takeover paths.
* `mac-island/MemoryFlowIsland/`: macOS native helper, windows, menu wiring, and migration work for the native island experience.
* `back-end/`: Spring Boot APIs, persistence, scheduling, and supporting services.
* `docs/`: migration evidence docs, state specs, interaction specs, animation specs, and checklist artifacts.
* `灵动岛迁移方案.md`: migration architecture reference for the Dynamic Island effort.

## 5. Critical Project Memory
Keep these project-specific constraints in mind before changing behavior:
* **Phase separation matters:** Phase 0 docs capture current Windows Electron behavior before macOS-native implementation. Do not mix future-state assumptions into baseline evidence.
* **Behavior parity is intentional:** macOS migration tasks should preserve documented user-visible behavior unless the task explicitly introduces an approved divergence.
* **Cross-layer island behavior is real:** state, reminders, hover, music takeover, and window behavior can span React widget code, Electron bridge code, and native helper code. Pick the minimum correct layer for tracing and validation.
* **Evidence quality matters:** do not present runtime claims without evidence from browser/runtime observation or directly cited code paths.

## 6. Task Routing
Use the right reference file for the task instead of rereading everything:
* **Task planning / queue regeneration:** `agent-state.md`, `feature_list.json`, `project_DS/workflows/task_init_loop.md`
* **General repository standards:** `project_DS/specification/project_standards.md`
* **Frontend/UI/widget behavior:** `project_DS/specification/ui_design_system.md`
* **Architecture / backend / module boundaries:** `project_DS/specification/project_core_architecture.md`
* **Dynamic Island migration / native helper boundaries / parity decisions:** `灵动岛迁移方案.md`
* **Detailed automation flow questions:** use the global skills, then fall back to `project_DS/workflows/auto_dev_loop.md` or `project_DS/workflows/task_init_loop.md` only if needed

## 7. Working Style
* Prefer targeted reads over repository-wide scanning.
* Keep `agent-state.md` short and current so future agents do not need to reread the full progress log.
* Use `codex-progress.md` as the lightweight recent log and `codex-progress-archive.md` for older detail.
* Preserve project-specific content; when slimming context, remove duplicated process text before removing project facts.

## 8. Migration Note
`灵动岛迁移方案.md` is a task-scoped architecture reference for the macOS native Dynamic Island effort only. It supplements project understanding for relevant tasks, but it does not replace the execution contracts defined by the global automation skills.
