## Current Summary

### Current phase
- Phase 0 baseline capture, Phase 1 shell scaffolding, and Phase 2 native window-system work are complete enough for handoff.
- The active queue is now Phase 3 native visual geometry work under `mac-island/MemoryFlowIsland/UI/`.
- The next execution slice starts with visual-token documentation before Swift geometry implementation.

### Queue snapshot
- First pending task: `Create the Phase 3 geometry acceptance document shell for preview, path, and pixel verification.`
- Requested execution mode: degraded single-agent `$Auto_dev` loop with no sub-agents.
- Immediate follow-up tasks after the acceptance shell: fill the preview matrix and non-goal boundaries, then append Phase 3 checklist gates.

### Runtime / environment notes
- [`init.sh`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/init.sh) remains the runtime entry point when full execution-path tasks require startup.
- `xcodebuild` is unavailable in the current environment because the active developer directory is CommandLineTools only.
- For native-shell compile checks, use `swiftc -module-cache-path /tmp/... -typecheck`.
- The sandbox can still block Vite from binding `0.0.0.0:3000` with `EPERM`, so docs tasks should stay on the lightweight path.

### Archive note
- Older detailed history lives in [`codex-progress-archive.md`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/codex-progress-archive.md).
- Keep this file small enough for the default startup path: `AGENTS.md` -> `agent-state.md` -> `feature_list.json` -> `codex-progress.md`.

## Recent Key Records

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
