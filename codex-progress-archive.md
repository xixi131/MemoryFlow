## Archive Summary

- This file preserves the full detailed history that has been rolled out of the default startup path.
- As of 2026-04-23, the intended startup order is `AGENTS.md` -> `agent-state.md` -> `feature_list.json` -> `codex-progress.md`.
- Read this archive only when you need deeper implementation audit detail than the compressed recent log provides.

## 2026-04-26 - Main-log rollover for the Phase 3 path-factory slice

- Reason for rollover:
  - `codex-progress.md` exceeded the default startup threshold again during the Phase 3 native geometry path-factory slice.
  - The default startup path only needs the current queue summary plus the newest path-factory records that feed `IslandShapeEngine.swift` and `IslandVisualStatePreview.swift`.
- Detailed records moved out of the default startup path:
  - 2026-04-26 - Native path factory now mirrors the Windows open stroke for stroke-allowed shells.
  - 2026-04-26 - Native path factory now mirrors the Windows squircle body path for compact and expanded shells.
  - 2026-04-25 - Shared shape metrics now resolve preview states into concrete geometry inputs.
  - 2026-04-25 - Preview-only native visual states were added for the five Phase 3 shells.
  - 2026-04-25 - Phase 3 geometry values now have one shared Swift token source.
  - 2026-04-25 - Phase 3 visual-geometry scaffolding landed under UI/Visual.
  - 2026-04-25 - Phase 3 checklist gates were added to the migration checklist.
  - 2026-04-25 - Phase 3 acceptance matrix now names the five preview shells and explicit non-goals.
  - 2026-04-25 - Phase 3 geometry acceptance document shell created.
  - 2026-04-25 - Path-function sources and seam constraints were mapped for the native path factory.
  - 2026-04-25 - Expanded, hover, and shadow geometry tokens were mapped for the Phase 3 native engine.
  - 2026-04-25 - Compact and activity shell token values were mapped for Phase 3 native previews.
  - 2026-04-25 - Phase 3 visual token map shell created for the native geometry migration.
  - 2026-04-25 - Hover exit now restores click-through without leaving the shell stuck interactive.
  - 2026-04-25 - Hover entry now transitions the shell into interactive mode.
  - 2026-04-25 - Hover hotspot monitoring now works while the shell stays click-through.
  - 2026-04-25 - Phase 2 window-system handoff note added for the next native shell slice.
  - 2026-04-25 - Phase 2 acceptance checklist now covers shell recovery and hover behaviors.
- Full detailed entries preserved below:

## 2026-04-26 - Native path factory now mirrors the Windows open stroke for stroke-allowed shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `openSquircleStrokePath(width:height:radius:smoothness:)` port plus a metrics overload that returns `nil` when `IslandShapeMetrics.showsStroke` is false, keeping compact and activity shells fully black.
- Reused the same width, height, radius, and smoothness inputs as the filled body path so the open stroke follows the shared shell perimeter while staying unclosed across the top edge.
- Validation: `./init.sh`, `MEMORYFLOW_BACKEND_PORT=18080 ./init.sh`, and `MEMORYFLOW_BACKEND_PORT=48080 ./init.sh` were attempted to satisfy the full execution-path contract but hit sandbox port-binding failures (`SocketException: Operation not permitted` and `listen EPERM`); `swiftc -module-cache-path /tmp/mf-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and `/tmp/island_path_validation` printed `expandedStroke.start=460.0,0.0`, `expandedStroke.end=0.0,0.0`, `expandedStroke.bounds=460.0x210.0`, and `compactStroke=nil` after checking the path stays open at the top and disabled for compact state.

## 2026-04-26 - Native path factory now mirrors the Windows squircle body path for compact and expanded shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `squircleBodyPath(width:height:radius:smoothness:)` port plus a shared-metrics overload, preserving the Windows `generateSquirclePath` input contract for compact and expanded shells.
- Kept the top edge as explicit straight-line segments and sampled both lower corners with the same superellipse math used in `DynamicIslandWidget.tsx`, so the native body path stays aligned with the documented Phase 3 geometry tokens instead of falling back to a generic capsule.
- Validation: `MEMORYFLOW_BACKEND_PORT=38081 ./init.sh` succeeded outside the sandbox and brought up the backend plus Vite on `http://localhost:3003/`; `swiftc -module-cache-path /tmp/memoryflow-swift-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and `/tmp/island_path_validation` printed `compactCollapsed: ok width=160.0 height=36.0 radius=22.0 smoothness=3.5` plus `expandedMusic: ok width=460.0 height=210.0 radius=48.0 smoothness=3.5` after checking a flat top edge and continuous lower-corner samples.

## 2026-04-25 - Shared shape metrics now resolve preview states into concrete geometry inputs

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift` so preview states now resolve width, height, radius, smoothness, ear tension, ear blend height, render scale, stroke visibility, and shadow visibility from `IslandVisualState` plus an external scalar input.
- Kept the metrics API isolated from business-state enums by resolving everything through `IslandVisualState.tokenSet`, hover tokens, and shadow tokens instead of auth, reminder, todo, or music-provider logic.
- Validation: `swiftc -module-cache-path /tmp/mf-task11-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')` passed, and a dedicated Swift harness printed `phase3-shape-metrics-ok` after checking all five preview states against the documented Phase 3 values.

## 2026-04-25 - Preview-only native visual states were added for the five Phase 3 shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift` with preview-only cases for compact collapsed, hover compact, activity compact, expanded music, and expanded app.
- Added small geometry helpers for `isExpanded`, `allowsShadow`, and `tokenSet`, so later preview and metrics work can stay detached from auth, reminder, todo, or music-provider state.
- Validation: `swiftc -module-cache-path /tmp/mf-task10-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')` passed, and direct file checks confirmed the state file contains all five cases and no business-data dependency hooks.

## 2026-04-25 - Phase 3 geometry values now have one shared Swift token source

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift` with grouped shell tokens for compact, activity, expanded music, expanded app, hover, and shadow behavior, plus a stable `IslandVisualTokenSet` lookup.
- Refreshed `docs/mac-island-visual-token-map.md` so the Swift token source can map back to documented compact preview width selection, idle or activity or expanded ear metrics, and the Phase 3 stroke-visibility boundary.
- Validation: `swiftc -module-cache-path /tmp/mf-task9-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')` passed, and the token-map document now contains the added source-backed rows for every new Swift token family.

## 2026-04-25 - Phase 3 visual-geometry scaffolding landed under UI/Visual

- Added `mac-island/MemoryFlowIsland/UI/Visual/` with placeholder files for `IslandVisualTokens.swift`, `IslandVisualState.swift`, `IslandShapeMetrics.swift`, `IslandPathFactory.swift`, `IslandShapeEngine.swift`, and `IslandVisualStatePreview.swift`.
- Updated `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` so the new Visual files are present in the `UI` group and the native app target sources without disturbing the existing Phase 2 window-layer files.
- Validation: `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` passed and `swiftc -module-cache-path /tmp/mf-task8-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')` completed successfully.

## 2026-04-25 - Phase 3 checklist gates were added to the migration checklist

- Updated `docs/mac-island-migration-checklist.md` with a new `Phase 3 Visual Geometry` section covering path parity, preview shell coverage, compact-state black-edge checks, ear seam checks, and external-display scaling.
- Linked each Phase 3 checklist row to `docs/mac-island-phase3-geometry-acceptance.md` and `docs/mac-island-visual-token-map.md`, while leaving every status field prepared rather than marked complete.
- Validation: confirmed the new section exists, each checklist row has a clear pass condition, and the requested acceptance/token-map links are present.

## 2026-04-25 - Phase 3 acceptance matrix now names the five preview shells and explicit non-goals

- Updated `docs/mac-island-phase3-geometry-acceptance.md` so `Preview Matrix` now includes compact collapsed, hover compact, activity compact, expanded music shell, and expanded app shell as prepared acceptance rows.
- Added `Non-Goals` rows that explicitly keep auth sync, review data, todo data, real music provider integration, and Phase 5 state-machine work outside the Phase 3 geometry gate.
- Validation: confirmed the document contains five preview rows, five non-goal rows, and link-backed evidence references to `docs/mac-island-visual-token-map.md` or `灵动岛迁移方案.md` in each acceptance row.

## 2026-04-25 - Phase 3 geometry acceptance document shell created

- Added `docs/mac-island-phase3-geometry-acceptance.md` with the required shell sections: `Preview Matrix`, `Path Parity`, `Pixel Edge Checks`, `External Display Scaling`, `Non-Goals`, and `Evidence`.
- Added an empty checklist table under each heading with the columns `Condition`, `Expected Result`, `Evidence`, and `Status`.
- Validation: confirmed the file exists, the heading order matches the requested shell, and each section contains the expected empty checklist table only.

## 2026-04-25 - Path-function sources and seam constraints were mapped for the native path factory

- Updated `docs/mac-island-visual-token-map.md` so `Path Sources` now maps `generateSquirclePath`, `generateOpenSquirclePath`, `generateLeftCapPath`, `generateRightCapPath`, and `generateEarPath` to their Windows inputs and native roles.
- Added `Seam Rules` rows for the `1px` ear overlap behavior, the explicit ban on replacing the shell with a `Capsule`, and the rule that stroke can appear only where the Windows source already draws it.
- Validation: confirmed all five path rows and all requested seam-sensitive constraints now have concrete source references in the token-map document.

## 2026-04-25 - Expanded, hover, and shadow geometry tokens were mapped for the Phase 3 native engine

- Updated `docs/mac-island-visual-token-map.md` so the `Expanded Shell Tokens` section now records width `460`, music height `210`, app height `320`, and expanded radius `48` from the Windows widget path.
- Added `Hover and Shadow Rules` rows for collapsed hover scale `1.06`, the `isExpanded || isHovered` shadow visibility gate, and the `260ms ease-out` shadow transition timing.
- Validation: confirmed both sections contain direct code references and explicitly mark which rules are preview-direct in Phase 3 versus deferred until later business-state migration.

## 2026-04-25 - Compact and activity shell token values were mapped for Phase 3 native previews

- Updated `docs/mac-island-visual-token-map.md` so the `Compact Shell Tokens` and `Activity Shell Tokens` sections now capture the Windows collapsed-width branches, shared `36`-point collapsed height, and the activity-vs-default radius and smoothness values.
- Each new row now links back to direct `DynamicIslandWidget.tsx` code references and names the expected preview-shell usage instead of leaving shell placeholders behind.
- Validation: confirmed both sections contain concrete data rows with direct code references and no placeholder-only content remains in those sections.

## 2026-04-25 - Phase 3 visual token map shell created for the native geometry migration

- Added `docs/mac-island-visual-token-map.md` with the required shell headings: `Compact Shell Tokens`, `Activity Shell Tokens`, `Expanded Shell Tokens`, `Hover and Shadow Rules`, `Path Sources`, `Seam Rules`, and `Evidence`.
- Added a scope note that keeps the document limited to Phase 3 visual geometry and explicitly excludes auth, todo data, review data, and music provider integration.
- Validation: confirmed the file opens from repository root, verified heading uniqueness, and checked that all required headings are present.

## 2026-04-25 - Hover exit now restores click-through without leaving the shell stuck interactive

- Updated `mac-island/MemoryFlowIsland/Window/IslandHoverMonitor.swift` so the monitor reports both hover-entry and hover-exit edge transitions instead of only start events.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` so hover-exit restores click-through only after the pointer actually leaves the island hotspot.
- Validation: `swiftc -module-cache-path /tmp/mf-task44-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')` plus the worker-reported hover-monitor harness result `hover-monitor-cycles-ok`.

## 2026-04-25 - Hover entry now transitions the shell into interactive mode

- Updated `IslandWindowController.swift` so hover-start routes through a dedicated `activateInteractiveHoverMode()` path.
- Updated `IslandPanel.swift` with an in-place helper that disables click-through without recreating the panel.
- Validation: full native source set typechecked through `swiftc -module-cache-path /tmp/mf-task43-module-cache -typecheck`.

## 2026-04-25 - Hover hotspot monitoring now works while the shell stays click-through

- Added `mac-island/MemoryFlowIsland/Window/IslandHoverMonitor.swift` as the Window-layer hotspot monitor.
- Wired monitor lifecycle into `IslandWindowController.show()`, `hide()`, and teardown.
- Validation: full native source set typechecked through `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck`.

## 2026-04-25 - Phase 2 window-system handoff note added for the next native shell slice

- Added `docs/mac-island-phase2-window-handoff.md` with the active Window-layer files, acceptance path, and explicit non-goals.
- Validation: lightweight doc checks confirmed Phase 2 scope and references remain correct.

## 2026-04-25 - Phase 2 acceptance checklist now covers shell recovery and hover behaviors

- Updated `docs/mac-island-migration-checklist.md` with the `Phase 2 Window Positioning and Recovery` section.
- Validation: lightweight checklist review confirmed the requested window-shell behaviors are present and scoped to Phase 2 only.

## Bootstrap

### What this file is for:
- Record completed tasks, validations, and important implementation notes.
- Help newly started agents recover recent context quickly.

### Suggested entry format:
- Date and task name
- What was done
- How it was tested
- Important follow-up notes

## 2026-04-25 - Main-log rollover for Phase 2 to Phase 3 handoff

- Reason for rollover:
  - `codex-progress.md` exceeded the default startup size threshold and still described an outdated queue snapshot with no pending tasks.
  - The startup path was refreshed so Phase 3 visual-geometry work can begin from the correct first pending task.
- Detailed records moved out of the default startup path:
  - 2026-04-25 - Native click-through toggle landed for the island panel.
  - 2026-04-25 - Expanded shell shadow now has native panel breathing room.
  - 2026-04-25 - Placeholder shell size presets now switch through the controller path.
  - 2026-04-25 - Wake recovery now reuses the display-change re-anchor path.
  - 2026-04-25 - Island panel now stays floating without taking app focus.
  - 2026-04-25 - Display-change re-anchor now reuses one native reposition path.
  - 2026-04-24 - Display-target persistence landed for screen-parameter changes.
  - 2026-04-24 - Island show path now applies the placement result on the target display.
  - 2026-04-24 - Flat-top fallback placement landed for the native island shell.
  - 2026-04-24 - Notch-safe top-region centering landed for the native island shell.
  - 2026-04-23 - Display top-edge classification landed for Phase 2 notch routing.
  - 2026-04-23 - Window-layer screen metrics model landed for Phase 2 positioning.
  - 2026-04-23 - Phase 1 acceptance-gate checklist items added for native shell readiness.
  - 2026-04-23 - Phase 1 scaffold handoff note added for native shell modules.
  - 2026-04-23 - Native app resources and bundle metadata placeholders landed.
  - 2026-04-23 - Preferences window skeleton wired into the native menu bar.
  - 2026-04-16 - Phase 1 gate confirmed and native shell queue opened.
  - 2026-04-16 - Native app container and bootstrap scaffold landed.
  - 2026-04-16 - Window shell and geometry placeholders landed.
  - 2026-04-16 - Placeholder UI and menu bar shell reached preferences handoff.
- Archive note:
  - The detailed wording for the five most recent Phase 2 entries remains in `codex-progress.md` because they are still useful for Phase 3 startup.
  - Read the Git history or prior task commits if a future task needs the full pre-rollup wording for an older moved entry.

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

## 2026-04-16 - Hover and reminder-triggered motion rows in animation spec

- Task: Add Hover Motion and Reminder-Triggered Motion animation rows from existing implementation.
- What was done:
  - Traced hover-motion state and render paths in `front-end/src/components/DynamicIslandWidget.tsx`, including hover enter/leave handlers, collapsed-scale branch, shadow transition style, and shared spring config.
  - Traced reminder-triggered auto-open and reminder-collapse animation paths in `front-end/src/components/DynamicIslandWidget.tsx`, including reminder due guards, `setForceCompactModeWithTransition(false)`, open/collapse duration constants, and segmented collapse transition branches.
  - Replaced template rows under `Hover Motion` and `Reminder-Triggered Motion` in `docs/mac-island-animation-spec.md` with source-backed entries and explicit code location evidence.
- How it was tested:
  - Verified step-1 tracing coverage with `rg -n` and `nl -ba` on `DynamicIslandWidget.tsx` for hover handlers, reminder guards, transition flags/constants, and Framer Motion variants.
  - Verified step-2 completion by inspecting the updated `Hover Motion` and `Reminder-Triggered Motion` sections in `docs/mac-island-animation-spec.md`.
  - Verified step-3 evidence quality by checking each new row contains concrete `DynamicIslandWidget.tsx:<line>` references and uses only durations/easing present in source (or explicitly marks no fixed duration in source).
  - Confirmed assigned task status is updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`) and did not run `init.sh`, browser MCP, or API runtime checks.

## 2026-04-16 - Music behavior rows in mac island music spec

- Task: Add music behavior rows from `MusicService`, `MusicWorker`, and renderer IPC listeners.
- What was done:
  - Traced end-to-end music payload flow from worker SMTC events/polling (`front-end/electron/MusicWorker.cjs`) to main-process forwarding and dedupe (`front-end/electron/MusicService.cjs`) and renderer listener/mode updates (`front-end/src/components/DynamicIslandWidget.tsx`).
  - Replaced template rows in `docs/mac-island-music-spec.md` with concrete rows for `Providers/Inputs`, `Mode Switching`, `Playback States`, and `Degraded Fallback`.
  - Ensured each row explicitly states event trigger, state effect, user-visible result, and concrete code evidence references.
- How it was tested:
  - Verified Step 1 tracing coverage by checking source locations for worker payload emit, service IPC forwarding, and renderer `music-data-update` handling.
  - Verified Step 2 completion by inspecting all four updated sections in `docs/mac-island-music-spec.md` and confirming placeholder rows are removed.
  - Verified Step 3 quality by reviewing each inserted row includes all required fields and at least one direct code location reference.
  - Confirmed assigned task status is updated to `passes: true` in `feature_list.json`.
- Important follow-up notes:
  - This task used docs fast-path static tracing only (`rg`, `sed`, `nl -ba`, `apply_patch`) and did not run `init.sh`, browser MCP, or API/runtime checks.

## 2026-04-16 - Phase 0 migration checklist population

- Task: Populate the migration checklist with concrete evidence links from all Phase 0 spec documents.
- What was done:
  - Replaced all template rows in `docs/mac-island-migration-checklist.md` with concrete checklist items for `State`, `Interaction`, `Animation`, `Reminder`, and `Music` coverage.
  - Added explicit pass-condition phrasing (`Pass when ...`) to each checklist row.
  - Linked every checklist item to specific section rows in Phase 0 spec docs: `docs/mac-island-state-spec.md`, `docs/mac-island-interaction-spec.md`, `docs/mac-island-animation-spec.md`, and `docs/mac-island-music-spec.md`.
  - Set task index 17 to `passes: true` in `feature_list.json` after documentation validation.
- How it was tested:
  - Verified template rows are removed and no empty placeholder row remains using `rg -n "Template Item|\|\s*\|\s*$" docs/mac-island-migration-checklist.md` (no matches).
  - Manually reviewed the updated checklist sections with `sed -n` to confirm each prepared row has non-empty `Status` (`Prepared`) and at least one evidence link.
  - Verified `feature_list.json` task index 17 now reports `passes=true`.
- Important follow-up notes:
  - Validation followed docs lightweight path only (no `init.sh`, browser MCP, or API runtime checks), matching the task execution contract.

## 2026-04-16 - Phase 1 entry gate note after Phase 0 checklist coverage check

- Task: Add a Phase 1 entry gate note after checking Phase 0 checklist coverage.
- What was done:
  - Compared Phase 0 outputs/focus points in `灵动岛迁移方案.md` (state, gestures/interaction, animation, mode-switch behavior, reminder trigger logic, music takeover) against `docs/mac-island-migration-checklist.md` coverage categories.
  - Added a concise `Phase 1 Entry Gate (Go/No-Go)` note under `Phase 0 Acceptance` in `docs/mac-island-phase0-baseline.md`.
  - Included explicit completion criteria and direct checklist section references for `State Coverage`, `Interaction Coverage`, `Animation Coverage`, `Reminder Coverage`, and `Music Coverage`.
- How it was tested:
  - Verified the new gate note is under `Phase 0 Acceptance` and includes explicit go/no-go criteria text.
  - Verified the note references checklist section anchors in `docs/mac-island-migration-checklist.md`.
  - Confirmed assigned task `feature_list.json` index 18 is now `passes: true`.
- Important follow-up notes:
  - This planning fast-path task used static document cross-checking only and intentionally did not run `init.sh`, browser MCP, or API checks.

## 2026-04-16 - Phase 1 mac-island project skeleton and Xcode container

- Task: Create the mac-island project skeleton directory and Xcode project container for a standalone macOS app.
- Execution mode:
  - Degraded single-agent mode (continued without worker by explicit human request after repeated worker timeout).
- What was done:
  - Created `mac-island/` and `MemoryFlowIsland.xcodeproj` container with:
    - `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj`
    - `mac-island/MemoryFlowIsland.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
  - Added initial target/group skeleton in `project.pbxproj` for `MemoryFlowIsland` with top-level groups:
    - `App`, `Window`, `MenuBar`, `Preferences`, `UI`, `Resources`
  - Created initial folder layout under `mac-island/MemoryFlowIsland/`:
    - `App/`, `Window/`, `MenuBar/`, `Preferences/`, `UI/`, `Resources/`
- How it was tested:
  - Full-path initialization check (frontend task contract): ran `zsh init.sh` and captured startup evidence:
    - Spring Boot started on `8080`.
    - Vite dev server started with local URL `http://localhost:3000/`.
  - Verified folder layout with `find mac-island -maxdepth 3 -type d | sort` and required directory presence check script.
  - Verified project file syntax with `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` (`OK`).
  - Verified target/group structure exists in pbxproj via `rg` on `PBXNativeTarget` and group names.
  - Verified structure consistency against `灵动岛迁移方案.md` section `推荐目录结构` (subset required by task 19).
- Important follow-up notes:
  - `xcodebuild` validation is currently unavailable in this environment because active developer directory is CommandLineTools only; Xcode app is required for `xcodebuild -list`.
  - Task index 19 in `feature_list.json` is now set to `passes: true`.

## 2026-04-16 - Phase 1 app bootstrap entry files

- Task: Add app bootstrap entry files for the native app startup path.
- Execution mode:
  - Degraded single-agent mode (continued without child workers by explicit human request).
- What was done:
  - Added bootstrap files under `mac-island/MemoryFlowIsland/App/`:
    - `MemoryFlowIslandApp.swift`
    - `AppDelegate.swift`
    - `SceneCoordinator.swift`
  - Wired launch flow so `AppDelegate` creates `SceneCoordinator` on app start and tears it down on app termination.
  - Implemented coordinator-driven startup hooks that initialize menu bar and window controller interfaces (`MenuBarControlling` and `IslandWindowControlling`) with temporary placeholders for this phase.
  - Added the three App files into `MemoryFlowIsland` target membership in `project.pbxproj` (`PBXBuildFile` + `PBXSourcesBuildPhase`).
- How it was tested:
  - Full-path startup validation: ran `zsh init.sh`; confirmed Vite ready at `http://localhost:3000/` and backend started on `8080`.
  - Project format validation: `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` returned `OK`.
  - Target membership validation: verified the three App files are present in `PBXSourcesBuildPhase` using `rg` on `project.pbxproj`.
  - Compile symbol validation: ran
    - `SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -target arm64-apple-macosx26.4 mac-island/MemoryFlowIsland/App/MemoryFlowIslandApp.swift mac-island/MemoryFlowIsland/App/AppDelegate.swift mac-island/MemoryFlowIsland/App/SceneCoordinator.swift`
    - result: exit `0`, no unresolved symbol errors.
- Important follow-up notes:
  - Placeholder menu-bar/window controller implementations are intentionally minimal and will be replaced by concrete module controllers in subsequent tasks.
  - Task index 20 in `feature_list.json` is now set to `passes: true`.

## 2026-04-16 - Phase 1 native island window shell classes

- Task: Create native island window shell classes with transparent floating window behavior.
- Execution mode:
  - Degraded single-agent mode (continued without child workers by explicit human request).
- What was done:
  - Added `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` as a transparent borderless panel shell.
  - Added `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` with lightweight `show()` / `hide()` entry methods and no business-domain coupling.
  - Wired `SceneCoordinator` to instantiate `IslandWindowController` as the default window controller.
  - Added both Window files to target membership in `project.pbxproj` (`PBXBuildFile`, `PBXGroup`, and `PBXSourcesBuildPhase`).
- How it was tested:
  - Full-path startup validation: ran `zsh init.sh`; confirmed Vite ready at `http://localhost:3000/` and backend started on `8080`.
  - Project format validation: `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` returned `OK`.
  - Style/behavior code checks:
    - Verified `IslandPanel` uses `styleMask: [.borderless, .nonactivatingPanel]`.
    - Verified floating window level `level = .statusBar` and transparent appearance settings.
    - Verified `IslandWindowController` exposes `show()` and `hide()` methods.
  - Compile symbol validation: ran
    - `SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -target arm64-apple-macosx26.4 mac-island/MemoryFlowIsland/App/MemoryFlowIslandApp.swift mac-island/MemoryFlowIsland/App/AppDelegate.swift mac-island/MemoryFlowIsland/App/SceneCoordinator.swift mac-island/MemoryFlowIsland/Window/IslandPanel.swift mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`
    - result: exit `0`, no unresolved symbol errors.
- Important follow-up notes:
  - Window shell currently focuses on container behavior only; business rendering/content is intentionally deferred to subsequent UI tasks.
  - Task index 21 in `feature_list.json` is now set to `passes: true`.

## 2026-04-16 - Phase 1 notch helper placeholders

- Task: Add notch-position helper placeholders for Phase 1 geometry readiness.
- Execution mode:
  - Single-agent execution in current thread.
- What was done:
  - Added `mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift`.
  - Added `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift`.
  - Implemented minimal helper APIs:
    - `NotchLayoutEngine.islandOrigin(screenFrame:islandSize:)`
    - `NotchLayoutEngine.islandFrame(screenFrame:islandSize:)`
    - `DisplayObserver.startObserving(onChange:)`
    - `DisplayObserver.stopObserving()`
    - `DisplayObserver.currentScreenFrame()`
  - Updated `IslandWindowController` to reference helper APIs for top-center repositioning on show and on display-parameter changes.
  - Added new Window helper files into target membership in `project.pbxproj` (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`).
- How it was tested:
  - Full-path startup validation: ran `zsh init.sh`; confirmed Vite ready at `http://localhost:3000/` and backend started on `8080`.
  - Verified helper files exist at required paths with `ls`.
  - Project format validation: `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` returned `OK`.
  - Helper/controller wiring validation: `rg` confirmed `IslandWindowController` references `NotchLayoutEngine` and `DisplayObserver` APIs.
  - Compile symbol validation: ran
    - `SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache swiftc -typecheck -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -target arm64-apple-macosx26.4 mac-island/MemoryFlowIsland/App/MemoryFlowIslandApp.swift mac-island/MemoryFlowIsland/App/AppDelegate.swift mac-island/MemoryFlowIsland/App/SceneCoordinator.swift mac-island/MemoryFlowIsland/Window/IslandPanel.swift mac-island/MemoryFlowIsland/Window/IslandWindowController.swift mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift mac-island/MemoryFlowIsland/Window/DisplayObserver.swift`
    - result: exit `0`, no unresolved symbol errors.
- Important follow-up notes:
  - The notch placement APIs are placeholders for Phase 1 geometry readiness and intentionally keep scope to screen-bounds input and top-center output.
  - Task index 22 in `feature_list.json` is now set to `passes: true`.

## 2026-04-16 - Phase 1 island placeholder view host wiring

- Task: Add SwiftUI island placeholder view and connect it to the native window host.
- Execution mode:
  - Single-agent execution in current thread.
- What was done:
  - Added `mac-island/MemoryFlowIsland/UI/IslandRootView.swift` with a simple capsule-style placeholder island UI and static text marker `MEMORYFLOW_ISLAND_PLACEHOLDER`.
  - Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to mount `IslandRootView` through `NSHostingView(rootView: IslandRootView())` in `configureContentView()`.
  - Updated `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` to include `IslandRootView.swift` in `PBXFileReference`, `UI` group children, `PBXBuildFile`, and `PBXSourcesBuildPhase` target membership.
- How it was tested:
  - Step 1 (placeholder view + static marker):
    - Verified file exists and inspected content:
      - `sed -n '1,220p' mac-island/MemoryFlowIsland/UI/IslandRootView.swift`
    - Confirmed marker text exists: `MEMORYFLOW_ISLAND_PLACEHOLDER`.
  - Step 2 (embed into native window content pipeline):
    - Verified `IslandWindowController` contains `NSHostingView(rootView: IslandRootView())` and calls `configureContentView()` during initialization.
    - Verified `project.pbxproj` includes `IslandRootView.swift` in `PBXSourcesBuildPhase`.
    - Commands:
      - `rg -n "IslandRootView.swift|IslandRootView\\(\\)|IslandRootView.swift in Sources" mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`
      - `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` -> `OK`
  - Step 3 (launch-time render path for placeholder content):
    - Verified launch pipeline references:
      - `AppDelegate.applicationDidFinishLaunching` -> `sceneCoordinator?.start()` -> `windowController.show()`
      - `IslandWindowController.init` -> `configureContentView()` -> `NSHostingView(rootView: IslandRootView())`
    - Compile/typecheck validation passed for full mac-island Swift file set including `IslandRootView.swift`:
      - `swiftc -typecheck -module-cache-path /tmp/swift-module-cache ...`
      - result: exit `0`.
    - Note:
      - `xcodebuild` launch validation is unavailable in current environment because active developer directory is CommandLineTools only (no full Xcode app).
- Important follow-up notes:
  - This task is limited to placeholder rendering host wiring only; no business data/UI migration was introduced.
  - Task index 23 in `feature_list.json` is now set to `passes: true`.

## 2026-04-16 - Phase 1 menu bar controller and base entries

- Task: Add menu bar controller and base menu entries for the native app shell.
- Execution mode:
  - Single-agent execution in current thread.
- What was done:
  - Added `mac-island/MemoryFlowIsland/MenuBar/StatusBarController.swift`.
  - Added `mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift`.
  - Implemented base menu entries with action handlers:
    - `Show/Hide Island` (toggles `IslandWindowControlling.show()/hide()` and updates menu title),
    - `Preferences` (stub handler with log output),
    - `Quit` (default terminate handler, injectable for smoke validation).
  - Updated `mac-island/MemoryFlowIsland/App/SceneCoordinator.swift` to use `StatusBarController` as default `MenuBarControlling`.
  - Updated `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` to include MenuBar files in group and `PBXSourcesBuildPhase`.
- How it was tested:
  - Full-path initialization check (frontend task contract):
    - Ran `zsh ./init.sh`.
    - Observed Vite ready (`http://localhost:3001/`) and backend running on `8080`.
  - Step 1 verification:
    - Verified both files exist:
      - `ls -la mac-island/MemoryFlowIsland/MenuBar/StatusBarController.swift mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift`
  - Step 2 verification:
    - Verified menu entries and action handlers in source:
      - `rg -n "Show Island|Hide Island|Preferences|Quit|toggleIslandMenuItemClicked|preferencesMenuItemClicked|quitMenuItemClicked" mac-island/MemoryFlowIsland/MenuBar/StatusBarController.swift mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift`
    - Verified coordinator and target membership wiring:
      - `rg -n "StatusBarController.swift|StatusMenuBuilder.swift|StatusBarController\\(windowController" mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj mac-island/MemoryFlowIsland/App/SceneCoordinator.swift`
    - Verified pbxproj syntax:
      - `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` -> `OK`
  - Step 3 verification (GUI-limited fallback chain):
    - Ran compile validation:
      - `swiftc -typecheck -module-cache-path /tmp/swift-module-cache $(find mac-island/MemoryFlowIsland -name '*.swift' | sort)` -> exit `0`
    - Ran executable smoke validation for action callability without crash:
      - Built and executed `/tmp/statusbar_action_smoke` using current MenuBar + Window + SceneCoordinator sources.
      - Script exercised `install()`, `toggleIslandMenuItemClicked`, `preferencesMenuItemClicked`, `quitMenuItemClicked`, and `uninstall()` with injected quit closure, exit `0`.
- Important follow-up notes:
  - GUI icon visibility was not captured with screenshot because this environment does not provide a GUI assertion path for the native app shell; fallback verification used source-path checks plus executable action smoke test.
  - Task index 24 in `feature_list.json` is now set to `passes: true`.
## 2026-04-27 - Main-log rollover for the Phase 4 sizing slice

- Reason for rollover:
  - `codex-progress.md` exceeded the default startup threshold for `$Auto_dev` degraded single-agent execution.
  - The current first pending task remains `Add sizing diagnostics for Phase 4 preview states.`
- Detailed records moved out of the default startup path:
  - 2026-04-26 - Activity shell width now has a content-driven sizing input.
  - 2026-04-26 - Phase 3 native geometry preview host, sizing path, and evidence set were completed.
  - 2026-04-26 - Native path factory now mirrors the Windows ear connector for both shell sides.
  - 2026-04-26 - Native path factory now mirrors the Windows right cap for compact and expanded shells.
  - 2026-04-26 - Native path factory now mirrors the Windows left cap for compact and expanded shells.
  - 2026-04-26 - Main-log rollover for the Phase 3 path-factory slice.

## 2026-04-26 - Activity shell width now has a content-driven sizing input

- Added `IslandContentWidthRequirement` and `IslandWidthConstraints` in `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift` so activity shell width can grow from content demand plus horizontal padding instead of relying only on fixed preview token width.
- `IslandShapeMetrics` now resolves body width from the maximum of token fallback width and `baseBodyWidth + leadingContentWidth + trailingContentWidth + horizontalPadding * 2`, while still clamping against the visible display width after liquid ear reach is considered.
- `IslandVisualState.previewContentWidthRequirement` currently supplies a preview-only symmetric activity stand-in (`leadingContentWidth: 36`, `trailingContentWidth: 36`, `horizontalPadding: 18`), matching the current music-style assumption that left cover and right waveform/action affordance have the same visual size; future music, reminder, and todo migration should replace this with measured or declared real content requirements.
- `IslandWindowController` remains window-focused: it derives screen/notch width constraints and passes them into `IslandShapeEngine.snapshot(...)`, without knowing activity content internals.
- Validation: full native Swift source-set typecheck passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')`.

## 2026-04-26 - Phase 3 native geometry preview host, sizing path, and evidence set were completed

- Implemented `IslandShapeEngine.swift` as the shared composition layer for body, open-stroke, cap, and ear paths, and connected it to `IslandVisualStatePreview.swift`, `IslandRootView.swift`, `IslandPanel.swift`, `IslandWindowController.swift`, and `NotchLayoutEngine.swift` so the native shell now renders all five Phase 3 preview states from geometry output rather than the old black rectangle or placeholder size preset.
- Added the native preview evidence set under `docs/evidence/mac-island-phase3/`, including the five PNG captures, `preview-board.png`, `native-path-samples.json`, `js-path-samples.json`, `path-parity-report.json`, `pixel-checks.json`, and `display-scaling-matrix.json`.
- Updated `docs/mac-island-phase3-geometry-acceptance.md`, `docs/mac-island-migration-checklist.md`, and the new `docs/mac-island-phase3-geometry-handoff.md` so the completed Phase 3 slice is source-linked, evidence-backed, and ready to hand off into Phase 4 sizing work.
- Validation: `swiftc -module-cache-path /tmp/memoryflow-phase3-cache -typecheck` passed for the native target source set; offscreen SwiftUI render harnesses generated the five preview PNGs and the preview board; JS-vs-native path sampling produced `overallPass: true` in `path-parity-report.json`; synthetic notch and flat-top `ScreenMetrics` runs produced the scaling matrix; `./init.sh` first failed because backend port `8080` was already occupied and `MEMORYFLOW_BACKEND_PORT=38081 ./init.sh` later hit sandbox bind failures (`SocketException: Operation not permitted`, `listen EPERM`), so runtime acceptance remained on the native geometry harness path.

## 2026-04-26 - Native path factory now mirrors the Windows ear connector for both shell sides

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `earPath(isLeft:tension:blendHeight:)` port plus dedicated `leftEarPath` and `rightEarPath` helpers that resolve from `IslandShapeMetrics`.
- Preserved the Windows liquid-connection math, including the fixed `40`-point ear width, the mirrored `4`-point tip extension, and the explicit `1px` body overlap so the connector does not detach from the body seam on either side.
- Validation: `./init.sh` was attempted for the full execution path and stopped because backend port `8080` was already in use by PID `59013`; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -o /tmp/island_ear_probe mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/main.swift` then printed validated bounds for `compactCollapsed`, `activityCollapsed`, `expandedMusic`, and `expandedApp` after checking mirrored ear spans and overlap sample points on both sides.

## 2026-04-26 - Native path factory now mirrors the Windows right cap for compact and expanded shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `rightCapPath(height:radius:smoothness:)` port plus a metrics overload that resolves height, radius, and smoothness from `IslandShapeMetrics`, matching the left-cap metrics contract.
- Kept the Windows fixed `60`-point cap width and mirrored the existing superellipse corner sampling on the lower-right edge so the compact and expanded right profile stays symmetric with the current native left-cap and body-path work unless future source parity requires a divergence.
- Validation: `./init.sh` first failed because backend port `8080` was already in use by PID `59013`; `MEMORYFLOW_BACKEND_PORT=38080 ./init.sh` then reached Spring Boot and Vite startup before sandbox port-binding failures (`SocketException: Operation not permitted` and `listen EPERM`) stopped the runtime path; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused native harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/memoryflow_right_cap_validation_main.swift -o /tmp/memoryflow_right_cap_validation` then printed validation lines for `compactCollapsed`, `expandedMusic`, and `expandedApp` after checking the right-cap seam probes and translated cap coverage stayed aligned with the body path.

## 2026-04-26 - Native path factory now mirrors the Windows left cap for compact and expanded shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `leftCapPath(height:radius:smoothness:)` port plus a metrics overload that resolves height, radius, and smoothness from `IslandShapeMetrics`.
- Kept the Windows fixed `60`-point cap width and reused the same superellipse sampling used by the native body path so the left edge profile stays aligned with the compact, activity, and expanded token sets instead of baking in preview-only literals.
- Validation: `./init.sh` was attempted to satisfy the full execution-path contract but stopped immediately because backend port `8080` was already in use by PID `59013`; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused native harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/memoryflow_left_cap_validation.swift -o /tmp/memoryflow_left_cap_validation` then printed `compactCollapsed: ok`, `activityCollapsed: ok`, `expandedMusic: ok`, and `expandedApp: ok` after checking the cap edge and body join stayed seam-free across compact and expanded shells.

## 2026-04-26 - Main-log rollover for the Phase 3 path-factory slice

- Reason for rollover:
  - `codex-progress.md` exceeded the default startup threshold while the default startup path only needs the current Phase 3 queue state plus the most recent path-factory records.
  - The active first pending task remains `Compose a single shape engine that returns every Phase 3 shell path from shared metrics.`
- Detailed records moved into `codex-progress-archive.md`:
  - 2026-04-26 - Native path factory now mirrors the Windows open stroke for stroke-allowed shells.
  - 2026-04-26 - Native path factory now mirrors the Windows squircle body path for compact and expanded shells.
  - 2026-04-25 - Shared shape metrics now resolve preview states into concrete geometry inputs.
  - 2026-04-25 - Preview-only native visual states were added for the five Phase 3 shells.
  - 2026-04-25 - Phase 3 geometry values now have one shared Swift token source.
  - 2026-04-25 - Phase 3 visual-geometry scaffolding landed under UI/Visual.
  - 2026-04-25 - Phase 3 checklist gates were added to the migration checklist.
  - 2026-04-25 - Phase 3 acceptance matrix now names the five preview shells and explicit non-goals.
  - 2026-04-25 - Phase 3 geometry acceptance document shell created.
  - 2026-04-25 - Path-function sources and seam constraints were mapped for the native path factory.
  - 2026-04-25 - Expanded, hover, and shadow geometry tokens were mapped for the Phase 3 native engine.
  - 2026-04-25 - Compact and activity shell token values were mapped for Phase 3 native previews.
  - 2026-04-25 - Phase 3 visual token map shell created for the native geometry migration.
  - 2026-04-25 - Hover exit now restores click-through without leaving the shell stuck interactive.
  - 2026-04-25 - Hover entry now transitions the shell into interactive mode.
  - 2026-04-25 - Hover hotspot monitoring now works while the shell stays click-through.
  - 2026-04-25 - Phase 2 window-system handoff note added for the next native shell slice.
  - 2026-04-25 - Phase 2 acceptance checklist now covers shell recovery and hover behaviors.
- Archive note:
  - Keep the three newest path-factory records in the main log because they are the closest setup context for the next `IslandShapeEngine` and preview-host tasks.
