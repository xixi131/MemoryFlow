# AGENTS.md

This file is the default-loaded project summary, operating constitution, and multi-agent SOP for Codex agents working in this repository.

## 1. Project Summary (Auto-Loaded Memory)
* **Project:** MemoryFlow
* **Domain:** An AI-assisted study planning and memory-flow system based on spaced repetition, with desktop and web experiences for learning workflows.
* **Goal:** TODO: replace with the primary delivery goal for this project.
* **Tech stack:** React 19, Vite, Electron, Spring Boot 3, MySQL, Redis
* **Memory rule:** This section is the primary project summary that Codex should retain by default. Keep it short, stable, and high-signal.

## 2. Core Automation Memory Files (Single Source of Coordination)
Every agent in this repository MUST treat the following files as the external memory layer of the automation system:
* `AGENTS.md`: Default-loaded project summary, architectural guardrails, and execution SOP.
* `feature_list.json`: Task state machine. Planning agents may initialize or rewrite pending items from a new requirement. Parent agents dispatch from here. Worker agents update the assigned item only after validation passes.
* `codex-progress.md`: Shared work log for humans and agents. Read before major work when more context is needed; append a new entry after each completed task.
* `init.sh`: Environment safety line. Use it to initialize dependencies and start the project before feature validation.

## 3. Multi-Agent SOP (Mandatory 8-Step Loop)
When acting as a worker agent on a task, follow this exact sequence:
1. **Get memory:** Read `AGENTS.md` first. Do not start coding before understanding the repository rules and current automation contract.
2. **Initialize environment:** Run `init.sh` to ensure the project still boots. If the environment is broken and cannot be recovered safely, stop and escalate.
3. **Select task and recover context:** Use `feature_list.json` as the task source. Work only on the assigned pending item. Read `codex-progress.md`, recent diffs, or focused Git history only when needed to recover context. Do NOT blindly read the whole repository.
4. **Load only the needed project docs:** Read detailed documents from `project_DS/` only when they are relevant to the task. Do not read every rule file by default.
5. **Implement:** Modify only the files directly related to the assigned task. Prefer targeted reads and minimal edits.
6. **Test thoroughly:** Validate against each `steps` entry from the assigned `feature_list.json` item. For user-visible or end-to-end tasks, use browser MCP to exercise the real flow. For backend tasks, use a real API request tool such as `curl`, `httpie`, project scripts, or another local HTTP client to call the actual endpoint. For data-affecting tasks, verify the resulting database state when needed.
7. **Repair or escalate:** If validation fails or behavior does not match expectations, debug through the relevant layers instead of guessing. Follow the shortest applicable chain: browser/UI -> API request/response -> backend logs/code path -> database state. The worker may self-repair up to 3 times for the same failing symptom. If the same problem still blocks completion after the third repair attempt, stop and escalate instead of continuing indefinitely.
8. **Update state, log, and commit:** Only after all verification passes, set the task's `passes` field to `true`, append a structured record to `codex-progress.md`, create a focused Git commit, and then return control to the parent agent.

## 4. Human-in-the-Loop Break Conditions
Abort the normal loop and ask for human intervention when any of the following occurs:
* **Repair loop exceeded:** The same failing test, runtime error, or validation symptom still persists after 3 self-repair attempts.
* **Missing prerequisite:** The current task depends on missing APIs, missing components, missing schema/data, missing environment variables, missing permissions, or other blocked dependencies outside the assigned scope.
* **Requirement unclear:** The acceptance criteria, product behavior, or expected data contract is ambiguous, conflicting, or not specified enough to implement safely.
* **Environment collapse:** `init.sh` fails and the agent cannot recover the project with safe, local fixes.

When escalating, the child agent MUST include:
* the current error log or failing symptom,
* the fixes already attempted, including how many repair attempts were used,
* the impacted files or modules,
* the verification methods already used, such as browser MCP, API requests, backend logs, or database checks,
* and the exact blocker category: `repair-loop-exceeded`, `missing-prerequisite`, `requirement-unclear`, or `environment-collapse`.

## 5. Parent Agent Responsibilities
When acting as the scheduler or supervisor:
* If `feature_list.json` is empty, placeholder-only, or not aligned with the user's current requirement, run the task-planning flow first before dispatching workers.
* Read `feature_list.json` from top to bottom and pick the first item whose `passes` field is `false`.
* Dispatch one worker per task and keep task ownership narrow.
* Pass the worker only the selected task, its `steps`, and the repository escalation contract. Do not broaden the assignment.
* Accept a task only after confirming both of the following:
  * the target item in `feature_list.json` was flipped to `true`,
  * and `codex-progress.md` contains a new matching log entry.
* For frontend, backend, or cross-module tasks, require the worker to report the concrete verification path used: browser MCP, API request checks, and database verification when applicable.
* Reject completion and stop the loop if the worker triggers any break condition or fails to provide the required escalation packet.
* Stop early and surface a report if a worker triggers any break condition.

## 5.1 Child Agent Runtime Control
Every dispatched child agent MUST obey these runtime controls:
* Own only the assigned task. Do not opportunistically fix unrelated issues.
* Keep a repair counter for the current failing symptom. A new symptom may start a new counter, but the same symptom cannot exceed 3 repair attempts.
* Stop before mutating `feature_list.json` or `codex-progress.md` when any break condition is hit.
* Never mark `passes: true` unless every declared `steps` item was validated successfully.
* For backend tasks, do not mark `passes: true` without exercising the real API path with an API request tool.
* For user-visible end-to-end tasks, do not mark `passes: true` without browser MCP verification unless the UI cannot be started and that itself is the blocker being escalated.
* For data-writing tasks, verify database-side results when needed to prove the flow completed correctly.

## 5.2 Planning Agent Responsibilities
When acting as the requirement-planning agent:
* Read `AGENTS.md`, the incoming requirement, `feature_list.json`, and `codex-progress.md` before planning.
* Load detailed docs from `project_DS/` only when they are directly relevant to the requirement being decomposed.
* Convert the requirement into an ordered list of executable tasks for `feature_list.json`.
* Prefer business-flow ordering and user-visible acceptance over low-level technical checklists.
* Preserve completed items unless the human explicitly asks to reset or fully rewrite the queue.
* Do not write placeholders, TODO items, or unverifiable tasks into `feature_list.json`.
* For frontend or cross-module tasks, include browser-verifiable `steps`.
* For backend tasks, include API-request-verifiable `steps`.
* For write-path tasks, include final-state verification steps when database effects matter.
* If requirements are unclear or prerequisites are missing, stop and escalate instead of writing low-confidence tasks.

## 6. Critical Domain Memory
Before writing business logic, keep a few repository-wide invariants here.
* **Invariant 1:** TODO: replace with the most important domain rule.
* **Invariant 2:** TODO: replace with the second most important domain rule.
* **Invariant 3:** TODO: replace with the third most important domain rule.

## 7. Working Style
* Read existing code before architectural decisions.
* Favor minimal, high-signal edits over broad rewrites.
* Always check data contracts between frontend payloads and backend maps before declaring a feature complete.
* For bugs and regressions, prefer reproducing the real flow first, then debug across browser, API, backend, and database in the minimum necessary path to isolate the root cause.
* Do not blind-scan unrelated directories. Prefer targeted file reads based on the current task.

## 8. Task-Scoped Project Docs
Read the following documents only when they match the current task:
* **Backend, domain model, schema, or module boundaries:** `project_DS/specification/project_core_architecture.md`
* **General coding conventions, API structure, engineering standards, and Git style:** `project_DS/specification/project_standards.md`
* **Frontend layout, UI details, design system, modal style, or interaction rules:** `project_DS/specification/ui_design_system.md`
* **macOS 灵动岛原生化、Electron 与原生 helper 边界、迁移阶段规划、窗口/音乐接管方案：** `灵动岛迁移方案.md`
* **Requirement decomposition, queue planning, or `feature_list.json` initialization:** `project_DS/workflows/task_init_loop.md`
* **Multi-agent workflow details beyond this file:** `project_DS/workflows/auto_dev_loop.md`

If any generated pattern conflicts with these documents, the stricter repository rule takes precedence.

## 9. Migration Planning Note
Root directory`灵动岛迁移方案.md` is a task-scoped architecture and migration reference for the macOS native Dynamic Island effort only.
It supplements repository context for relevant tasks, but it does NOT remove, weaken, or replace any agent execution contract, multi-agent SOP, validation rule, escalation rule, or state-update requirement defined earlier in this file.
