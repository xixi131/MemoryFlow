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

## 2026-04-16 - Visual state machine transition matrix in state spec

- Task: Add the Visual State Machine transition matrix from component state logic.
- What was done:
  - Traced collapsed/activity/expanded transition triggers in `front-end/src/components/DynamicIslandWidget.tsx`.
  - Replaced the placeholder row under `Visual State Machine` in `docs/mac-island-state-spec.md` with 5 transition rules.
  - Added an explicit reminder row stating auto-open is a trigger path into review activity state, not a standalone display mode.
- How it was tested:
  - Extracted `Visual State Machine` section via `awk` and verified 5 populated rows exist.
  - Verified no placeholder empty row remains in `Visual State Machine`.
  - Verified explicit reminder trigger-path wording and evidence references are present.
  - Confirmed assigned task status is updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static code tracing only (`rg`/`sed`/`nl -ba`/`awk`) and did not run browser MCP, API runtime checks, or `init.sh`.

## 2026-04-16 - Reminder trigger rules in state spec

- Task: Add Reminder Trigger Rules from `reminderTime` and guard refs in widget code.
- What was done:
  - Traced reminder-related refs and guards in `front-end/src/components/DynamicIslandWidget.tsx` (`reminderAutoOpenKeyRef`, `reminderDueRef`, `reminderCheckInitializedRef`, `justReachedReminderTime`, and the compact/app/review guards).
  - Replaced the placeholder row under `Reminder Trigger Rules` in `docs/mac-island-state-spec.md` with 2 static rules covering invalid/missing reminder time and the one-per-day auto-open transition.
  - Added a note clarifying that reminder timing is separate from the `appDisplayMode` display-mode enum.
- How it was tested:
  - Extracted the `Reminder Trigger Rules` section with `nl -ba` and confirmed both populated rows are present.
  - Verified the section includes an explicit separation note for time-trigger logic vs display-mode definitions.
  - Checked the assigned task status was updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`) and did not run browser MCP, API runtime checks, or `init.sh`.

## 2026-04-16 - Expand/Collapse and mode-switch animation rows in animation spec

- Task: Add Expand/Collapse and Mode Switch animation rows from current UI animation definitions.
- What was done:
  - Traced expand/collapse animation constants, segmented/open transition flags, and Framer Motion transition branches in `front-end/src/components/DynamicIslandWidget.tsx`.
  - Traced mode-switch long-press and sequence timers (`compact -> mode flip -> reopen -> unlock`) in `front-end/src/components/DynamicIslandWidget.tsx`.
  - Replaced template rows in `docs/mac-island-animation-spec.md` under `Expand/Collapse` and `Mode Switch` with concrete duration/easing/trigger/observed-result entries and code evidence.
- How it was tested:
  - Verified step-1 tracing coverage by checking referenced constants/timers/transition branches with `nl -ba` on `DynamicIslandWidget.tsx`.
  - Verified step-2 completion by inspecting both updated sections in `docs/mac-island-animation-spec.md` and confirming populated rows include required fields.
  - Ran `rg -n 'Template Row' docs/mac-island-animation-spec.md` and confirmed no placeholder remains in `Expand/Collapse` and `Mode Switch`.
  - Confirmed assigned task status is updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`) and did not run `init.sh`, browser MCP, or API runtime checks.

## 2026-04-16 - Hover activation and click-through toggle in interaction spec

- Task: Add Hover Activation and Click-Through Toggle rules from renderer and Electron bridge code.
- What was done:
  - Traced hover handling in `front-end/src/components/DynamicIslandWidget.tsx`, including `isHovered`, the `:hover` guard used during gesture finalization, and the mouse-enter/mouse-leave handlers that gate hover state.
  - Traced click-through toggling in `front-end/src/components/DynamicIslandWidget.tsx` and `front-end/electron/main.cjs`, including `set-ignore-mouse-events` IPC calls and the Electron bridge that forwards them to `BrowserWindow.setIgnoreMouseEvents()`.
  - Filled `docs/mac-island-interaction-spec.md` with concrete Hover Activation and Click-Through Toggle rows, including trigger guards, recovery behavior, and evidence links.
- How it was tested:
  - Verified the `Hover Activation` and `Click-Through Toggle` sections now contain populated rows instead of template placeholders.
  - Confirmed each row includes a trigger threshold or guard, recovery behavior, and an evidence link to concrete code locations.
  - Confirmed `feature_list.json` for this task was updated to `passes: true`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`) and did not run browser MCP, API runtime checks, or `init.sh`.

## 2026-04-16 - Pointer and trackpad gesture rules in interaction spec

- Task: Add Pointer and Trackpad gesture rules from gesture accumulators and cooldown logic.
- What was done:
  - Traced pointer gesture deltas and guards in `front-end/src/components/DynamicIslandWidget.tsx`, including `startX`, `lastPointerXRef`, `activePointerIdRef`, `GESTURE_SWITCH_THRESHOLD`, and `TAP_THRESHOLD`.
  - Traced trackpad gesture accumulators and cooldown logic in `front-end/src/components/DynamicIslandWidget.tsx`, including `trackpadDeltaXRef`, `trackpadDeltaYRef`, `trackpadGestureLockedRef`, `TRACKPAD_GESTURE_RESET_MS`, and `TRACKPAD_GESTURE_COOLDOWN_MS`.
  - Replaced template rows in `docs/mac-island-interaction-spec.md` under `Pointer Gestures` and `Trackpad Gestures` with action-mapped rules and code evidence links.
- How it was tested:
  - Verified `Pointer Gestures` and `Trackpad Gestures` sections contain populated behavior rows by inspecting the updated markdown table content.
  - Ran `rg -n 'Template Row' docs/mac-island-interaction-spec.md` and confirmed no placeholder rows remain.
  - Verified each new row includes concrete evidence references to gesture thresholds, accumulator/reset paths, and lock/cooldown code locations in `DynamicIslandWidget.tsx`.
  - Confirmed assigned task status is updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`) and did not run browser MCP, API runtime checks, or `init.sh`.
