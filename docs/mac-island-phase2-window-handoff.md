# Phase 2 Window-System Handoff

## Scope

This note hands off the current Phase 2 native window shell under `mac-island/MemoryFlowIsland/Window/` and is limited to screen attachment, notch/menu-bar adaptation, display recovery, click-through, and hover-ready shell behavior. Final Dynamic Island visual geometry belongs to the later visual-shape phase and must be migrated from `front-end/src/components/DynamicIslandWidget.tsx`.

## Phase 2 Correction Notes

The first Phase 2 pass had several implementation mistakes that made later visual tuning unreliable:

- It classified any display with `safeAreaInsets.top > 0` as notch-bearing. That is not reliable on external displays or menu-bar top-band scenarios; the native shell now only treats a screen as notch-bearing when a concrete `notchFrame` can be derived from `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`.
- It used fixed collapsed dimensions on flat/non-notch displays. External displays now use a top-band derived from menu-bar or fallback metrics and scale the compact shell to that band instead of blindly using notch-sized geometry.
- It mixed hover visual scaling into Phase 2. The current Phase 2 shell keeps hover limited to activation/click-through behavior; final hover scale, shadow, and liquid-ear geometry are deferred to the visual migration phase.
- It rendered placeholder text and non-black strokes in the native shell. The current Phase 2 root view is a pure black frame probe so edge alignment can be verified without visual decoration noise.

## Active Window-Layer Files

| File | Phase 2 role |
| --- | --- |
| `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` | Owns the floating `NSPanel` shell, visible shell sizing, panel shadow margins, and the native click-through toggle via `ignoresMouseEvents`. |
| `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` | Connects panel creation, SwiftUI hosting, top-anchor repositioning, display-change observation, and shell-level show or hide behavior. |
| `mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift` | Computes `TopAttachmentMetrics`, notch-aligned placement, menu-bar attached placement, flat-top fallback placement, pixel alignment, and compact shell scaling for external displays. |
| `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` | Watches display-parameter changes and wake events so the shell can recompute placement after monitor, resolution, or sleep transitions. |
| `mac-island/MemoryFlowIsland/Window/DisplayTopEdgeClassifier.swift` | Classifies the active display as notch-bearing only when a derived `notchFrame` exists; otherwise it falls back to flat/top-band layout. |
| `mac-island/MemoryFlowIsland/Window/ScreenMetrics.swift` | Normalizes per-display frame, visible-frame, safe-area, scale, display identity, and derived notch frame data for layout and recovery. |
| `mac-island/MemoryFlowIsland/UI/IslandRootView.swift` | Renders a pure black Phase 2 frame probe. Final shape, ears, hover scale, shadow, and activity/expanded visuals are non-goals here. |

## Expected Acceptance Path

The Phase 2 implementation should stay inside the native window shell and clear the acceptance path in this order:

1. `ScreenMetrics.swift` derives `notchFrame` only from actual auxiliary top areas.
2. `DisplayTopEdgeClassifier.swift` treats only screens with `notchFrame` as notch-bearing.
3. `NotchLayoutEngine.swift` computes `TopAttachmentMetrics` for notch, menu-bar, and flat-top fallback displays.
4. `NotchLayoutEngine.swift` scales compact shell size to the active top band on external/non-notch displays.
5. `IslandWindowController.swift` always requests layout from the preset shell size, not from the last rendered/adapted size, so display changes can re-resolve correctly.
6. The same layout path falls back to deterministic top-center placement on non-notch displays without drifting off the visible top edge.
7. `DisplayObserver.swift` plus `IslandWindowController.swift` recompute placement after display attach or detach, resolution changes, and wake-from-sleep recovery.
8. `IslandPanel.swift` exposes observable click-through toggling without recreating the window.
9. `IslandPanel.swift` and `IslandWindowController.swift` remain the hover-ready shell boundary for the next native activation work, without depending on review, todo, auth, or music data.

Reference acceptance targets already prepared in [docs/mac-island-migration-checklist.md](./mac-island-migration-checklist.md#phase-2-window-positioning-and-recovery) and the Phase 2 section of [灵动岛迁移方案.md](../灵动岛迁移方案.md#phase-2屏幕刘海菜单栏和外接显示器自适应系统).

## Explicit Non-Goals For This Slice

- No `review` or `todo` data migration belongs in this Phase 2 window-shell handoff.
- No auth flow, token storage, refresh handling, or login-state recovery belongs in this slice.
- No music takeover, provider integration, or playback-driven shell mode switching belongs in this slice.
- No final Dynamic Island shape, liquid-ear geometry, hover scaling, shadow tuning, gesture polish, pointer-threshold calibration, or trackpad interaction migration belongs in this slice.

## Boundary Check

- Most files named in this note live under `mac-island/MemoryFlowIsland/Window/`; `IslandRootView.swift` is included only as a pure black frame probe for Phase 2 verification.
- All behaviors named here map to Phase 2 shell work only: screen attachment, placement, display recovery, click-through, and hover-ready activation boundaries.
- This note intentionally excludes Phase 3 state-machine files, Phase 4 business-data paths, Phase 5 auth files, and Phase 6 interaction-polish work.
