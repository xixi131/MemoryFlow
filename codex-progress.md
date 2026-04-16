## Bootstrap

### What this file is for:
- Record completed tasks, validations, and important implementation notes.
- Help newly started agents recover recent context quickly.

### Suggested entry format:
- Date and task name
- What was done
- How it was tested
- Important follow-up notes

## 2026-04-16 - Phase 0 baseline doc shell

- Task: Create the Phase 0 baseline document shell for the current Windows Electron Dynamic Island behavior.
- What was done:
  - Created `docs/mac-island-phase0-baseline.md`.
  - Added top-level headings: `Scope`, `Runtime Environment`, `Evidence Index`, `Phase 0 Acceptance`.
  - Added one-sentence scope note stating this captures current Windows behavior before macOS migration implementation.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified heading set with `rg '^# ' docs/mac-island-phase0-baseline.md`.
  - Verified heading uniqueness with duplicate-heading check (`sort | uniq -d` returned empty).
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - This file is a shell only; runtime evidence and acceptance details are intentionally left for later tasks.

## 2026-04-16 - State spec doc shell

- Task: Create the state specification document shell for review, todo, and visual state behavior.
- What was done:
  - Created `docs/mac-island-state-spec.md`.
  - Added section headings in order: `Startup/Auth`, `Review Rules`, `Todo Rules`, `Visual State Machine`, `Reminder Trigger Rules`.
  - Added an empty table template under each section with columns: `Condition`, `Trigger`, `Expected UI`, `Evidence`.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified heading order with `rg '^# ' docs/mac-island-state-spec.md`.
  - Verified table header consistency with `rg '^\\| Condition \\| Trigger \\| Expected UI \\| Evidence \\|' docs/mac-island-state-spec.md`.
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - This is a shell-only document and intentionally contains no behavior conclusions.

## 2026-04-16 - Interaction spec doc shell

- Task: Create the interaction specification document shell for hover, click-through, pointer, and gesture behavior.
- What was done:
  - Created `docs/mac-island-interaction-spec.md`.
  - Added section headings in order: `Hover Activation`, `Click-Through Toggle`, `Pointer Gestures`, `Trackpad Gestures`.
  - Added a reusable behavior row template under each section with fields for `Trigger Threshold`, `Debounce`, and `Recovery Behavior`.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified heading order with `rg '^# ' docs/mac-island-interaction-spec.md`.
  - Verified template header consistency with `rg '^\\| Interaction \\| Trigger Threshold \\| Debounce \\| Recovery Behavior \\| Evidence \\|' docs/mac-island-interaction-spec.md`.
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - This is a shell-only document and intentionally contains no behavior claims.

## 2026-04-16 - Animation spec doc shell

- Task: Create the animation specification document shell for transition timing and motion sequencing.
- What was done:
  - Created `docs/mac-island-animation-spec.md`.
  - Added section headings in order: `Expand/Collapse`, `Mode Switch`, `Hover Motion`, `Reminder-Triggered Motion`.
  - Added an animation table template under each section with fields for `Duration`, `Easing`, `Trigger`, and `Observed Result`.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified heading order with `rg '^# ' docs/mac-island-animation-spec.md`.
  - Verified template header consistency with `rg '^\\| Animation Step \\| Duration \\| Easing \\| Trigger \\| Observed Result \\| Evidence \\|' docs/mac-island-animation-spec.md`.
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - This is a shell-only document and intentionally contains no runtime behavior conclusions.

## 2026-04-16 - Music spec doc shell

- Task: Create the music takeover specification document shell for playback-driven island behavior.
- What was done:
  - Created `docs/mac-island-music-spec.md`.
  - Added section headings in order: `Providers/Inputs`, `Mode Switching`, `Playback States`, `Degraded Fallback`.
  - Added a behavior matrix template under each section with fields for `Media Event`, `Widget State Change`, and `User-Visible Output`.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified heading order with `rg '^# ' docs/mac-island-music-spec.md`.
  - Verified template header consistency with `rg '^\\| Media Event \\| Widget State Change \\| User-Visible Output \\| Evidence \\|' docs/mac-island-music-spec.md`.
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - This is a shell-only document and intentionally contains no unverified runtime conclusions.

## 2026-04-16 - Migration checklist doc shell

- Task: Create the Phase 0 migration checklist shell used to gate the move into Phase 1.
- What was done:
  - Created `docs/mac-island-migration-checklist.md`.
  - Added sections: `State Coverage`, `Interaction Coverage`, `Animation Coverage`, `Reminder Coverage`, `Music Coverage`.
  - Added checklist table rows with fields: `Item`, `Expected Behavior`, `Evidence Link`, `Status`.
- How it was tested:
  - Confirmed file exists from repository root.
  - Verified section order with `rg '^# ' docs/mac-island-migration-checklist.md`.
  - Verified table header consistency with `rg '^\\| Item \\| Expected Behavior \\| Evidence Link \\| Status \\|' docs/mac-island-migration-checklist.md`.
  - Opened file content from repository root using `sed -n`.
- Important follow-up notes:
  - Checklist status fields are intentionally left unset (empty) for later completion tasks.

## 2026-04-16 - Startup/Auth rules in state spec

- Task: Add startup and authentication behavior details to the state spec from current widget code and visible runtime behavior.
- What was done:
  - Filled `docs/mac-island-state-spec.md` under `Startup/Auth` with condition-to-UI mapping rules.
  - Traced startup/auth flows in `front-end/src/components/DynamicIslandWidget.tsx` and `front-end/electron/main.cjs` (token bootstrap, IPC auth-token, unauth fallback handling).
  - Added explicit evidence notes per rule (code path + runtime observation).
- How it was tested:
  - Browser MCP unauth startup observation at `http://localhost:3002/#/widget`: confirmed visible `点击登录`.
  - Browser MCP authenticated-context observation: local token presence confirmed and browser-side authenticated fetch to `/api/widget/summary` returned `code=200`.
  - Verified Startup/Auth table rows each include concrete evidence references.
- Important follow-up notes:
  - `init.sh` frontend started on `3002`; backend launch from `init.sh` hit `8080` conflict, so runtime verification reused the already-listening local backend on `8080`.

## 2026-04-16 - Review rules in state spec

- Task: Add Review Rules rows from static code paths without runtime sampling.
- What was done:
  - Traced review-mode data and render branches in `front-end/src/components/DynamicIslandWidget.tsx` (mode state, activity gating, summary fetch path, and expanded review panel rendering).
  - Replaced the placeholder row under `Review Rules` in `docs/mac-island-state-spec.md` with 5 concrete rules.
  - Added concrete code evidence with file+line references in every new Review Rules row.
- How it was tested:
  - Extracted the `Review Rules` section and confirmed the table contains populated rows with no empty placeholder row.
  - Verified each new row contains at least one concrete code location via `DynamicIslandWidget.tsx:<line>` matches.
  - Checked markdown heading structure/order remains valid in `docs/mac-island-state-spec.md`.
- Important follow-up notes:
  - This task used static code tracing only (no runtime/browser/API sampling) per docs fast-path requirements.

## 2026-04-16 - Todo rules in state spec

- Task: Add Todo Rules endpoint and rendering rows from existing frontend and API code.
- What was done:
  - Traced todo-related request and rendering paths in `front-end/src/components/DynamicIslandWidget.tsx` and API mapping in `front-end/src/services/todoApis.ts`.
  - Replaced the placeholder row under `Todo Rules` in `docs/mac-island-state-spec.md` with 3 endpoint-specific rules for `/todos/stats`, `/todos/tasks`, and `/todos/tasks/:id/status`.
  - Added explicit expected UI impact per endpoint, covering collapsed activity badges, expanded todo summary/list rendering, and optimistic status-toggle behavior with rollback.
- How it was tested:
  - Extracted `Todo Rules` section via `awk` and confirmed all three required endpoints are present as populated rows.
  - Verified placeholder empty row was removed from `Todo Rules`.
  - Checked each new row includes direct code evidence references (`DynamicIslandWidget.tsx:<line>` and API callsite references in `todoApis.ts:<line>`).
  - Confirmed markdown section order/structure remains valid in `docs/mac-island-state-spec.md`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`/`sed`/`awk`) and did not run browser/API runtime sampling.

## 2026-04-16 - Todo status-update persistence contract in state spec

- Task: Add Todo status-update persistence assumptions from code contracts and local schema references.
- What was done:
  - Traced todo status-update request flow from widget click handling to API call in `front-end/src/components/DynamicIslandWidget.tsx` and `front-end/src/services/todoApis.ts`.
  - Traced backend `/todos/tasks/{id}/status` controller and service update path in `back-end/src/main/java/com/memoryflow/controller/TodoController.java` and `back-end/src/main/java/com/memoryflow/service/TodoService.java`.
  - Added `Todo status-update persistence contract (code-derived)` under `Todo Rules` in `docs/mac-island-state-spec.md`, documenting write intent, persisted field effects, and read-after-write expectation using local schema references.
- How it was tested:
  - Extracted the `Todo Rules` section with `awk` and confirmed the new contract subsection is present.
  - Verified the note includes concrete code references for frontend callsites, backend controller/service write path, and schema/entity fields (`todo_tasks.status`, `todo_tasks.completed_at`).
  - Verified the section includes an explicit scope note that this task is static-code/schema based and does not claim runtime DB verification.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`, `awk`) and did not run browser MCP, API runtime checks, or `init.sh`.
