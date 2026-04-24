# Phase 2 Window-System Handoff

## Scope

This note hands off the current Phase 2 native window shell under `mac-island/MemoryFlowIsland/Window/` and is limited to notch-aware placement, display recovery, click-through, and hover-ready shell behavior.

## Active Window-Layer Files

| File | Phase 2 role |
| --- | --- |
| `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` | Owns the floating `NSPanel` shell, visible shell sizing, panel shadow margins, and the native click-through toggle via `ignoresMouseEvents`. |
| `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` | Connects panel creation, SwiftUI hosting, top-anchor repositioning, display-change observation, and shell-level show or hide behavior. |
| `mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift` | Computes notch-aligned placement for notch displays and top-center fallback placement for flat-top displays. |
| `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` | Watches display-parameter changes and wake events so the shell can recompute placement after monitor, resolution, or sleep transitions. |
| `mac-island/MemoryFlowIsland/Window/DisplayTopEdgeClassifier.swift` | Classifies the active display as notch-bearing or flat-top from safe-area data used by the Phase 2 layout path. |
| `mac-island/MemoryFlowIsland/Window/ScreenMetrics.swift` | Normalizes per-display frame, visible-frame, safe-area, scale, and display identity data for the layout and recovery path. |

## Expected Acceptance Path

The next implementation slice should stay inside the native window shell and clear the existing Phase 2 acceptance path in this order:

1. `NotchLayoutEngine.swift` plus `IslandWindowController.swift` keep the shell stably centered against the notch-safe region on notch-equipped Macs.
2. The same layout path falls back to deterministic top-center placement on non-notch displays without drifting off the visible top edge.
3. `DisplayObserver.swift` plus `IslandWindowController.swift` recompute placement after display attach or detach, resolution changes, and wake-from-sleep recovery.
4. `IslandPanel.swift` exposes observable click-through toggling without recreating the window.
5. `IslandPanel.swift` and `IslandWindowController.swift` remain the hover-ready shell boundary for the next native activation work, without depending on review, todo, auth, or music data.

Reference acceptance targets already prepared in [docs/mac-island-migration-checklist.md](./mac-island-migration-checklist.md#phase-2-window-positioning-and-recovery) and the Phase 2 section of [灵动岛迁移方案.md](../灵动岛迁移方案.md#phase-2实现刘海定位与窗口系统).

## Explicit Non-Goals For This Slice

- No `review` or `todo` data migration belongs in this Phase 2 window-shell handoff.
- No auth flow, token storage, refresh handling, or login-state recovery belongs in this slice.
- No music takeover, provider integration, or playback-driven shell mode switching belongs in this slice.
- No Phase 6 gesture polish, animation tuning, pointer-threshold calibration, or trackpad interaction migration belongs in this slice.

## Boundary Check

- All files named in this note live under `mac-island/MemoryFlowIsland/Window/` except the acceptance checklist and architecture reference documents.
- All behaviors named here map to Phase 2 shell work only: placement, display recovery, click-through, and hover-ready activation boundaries.
- This note intentionally excludes Phase 3 state-machine files, Phase 4 business-data paths, Phase 5 auth files, and Phase 6 interaction-polish work.
