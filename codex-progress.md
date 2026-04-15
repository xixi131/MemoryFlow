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
