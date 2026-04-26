# Phase 4 Sizing And Motion Acceptance

## Scope

Phase 4 covers native sizing and motion infrastructure only, excluding real data providers and production music integration.

Phase 4 follows the sizing and motion acceptance targets in the [Phase 4 section of `灵动岛迁移方案.md`](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) and builds on the Phase 3 geometry inputs captured in [Phase 3 geometry handoff](./mac-island-phase3-geometry-handoff.md).

## Sizing Outputs

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Prepared | `visibleFrame` output | `IslandWindowSizingEngine` returns a visible shell frame that stays attached to the current top band or notch anchor instead of falling back to a fixed desktop preset. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending Phase 4 sizing evidence | `IslandWindowSizingEngine`, `IslandShapeEngine`, `IslandWindowController` |
| Prepared | `shadowFrame` output | Expanded and hover-capable layouts return a shadow frame that can extend laterally and downward without adding a transparent gap above the shell. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending Phase 4 shadow evidence | `IslandWindowSizingEngine`, `IslandPanel`, `IslandWindowController` |
| Prepared | `contentFrame` output | The sizing path returns a content frame aligned to the visible shell so preview or future real content can lay out without re-deriving shell geometry in view code. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending Phase 4 sizing evidence | `IslandWindowSizingEngine`, `IslandShapeEngine`, `IslandRootView` |
| Prepared | `hitTestFrame` output | The sizing path returns a hit-test frame that matches the intended interactive area for hover or tap work without drifting away from the top attachment. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending Phase 4 interaction evidence | `IslandWindowSizingEngine`, `IslandHoverMonitor`, `IslandWindowController` |

### Top Attachment And Display Behavior

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Prepared | Notch display sizing | Phase 4 sizing keeps the shell centered on the notch-derived top attachment while resolving visible, shadow, content, and hit-test frames from the same sizing result. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending notch-display sizing matrix | `IslandWindowSizingEngine`, `NotchLayoutEngine`, `ScreenMetrics`, `IslandWindowController` |
| Prepared | Flat-top display sizing | Phase 4 sizing respects menu-bar or flat-top attachment metrics and does not assume notch-only geometry when returning window frames. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending flat-top sizing matrix | `IslandWindowSizingEngine`, `NotchLayoutEngine`, `DisplayTopEdgeClassifier`, `ScreenMetrics` |
| Prepared | External display sizing | Phase 4 sizing keeps the shell inside the available top band on external displays and avoids the old fixed-height behavior that could push the window past the menu bar. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending external-display sizing matrix | `IslandWindowSizingEngine`, `NotchLayoutEngine`, `ScreenMetrics`, `IslandWindowController` |
| Prepared | Resolution-change recovery | After display scale or resolution changes, the next sizing result reuses fresh top attachment metrics instead of stale window dimensions so the shell remains anchored correctly. | [Phase 4 sizing output contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending resolution-change sizing evidence | `IslandWindowSizingEngine`, `DisplayObserver`, `ScreenMetrics`, `IslandWindowController` |

## Content-Driven Width

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Prepared | Activity width from content demand | Activity width is derived from content demand rather than a single preview preset, using declared leading and trailing content widths plus horizontal padding. | [Phase 4 content-driven width contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending activity sizing matrix | `IslandContentWidthRequirement`, `IslandShapeMetrics`, `IslandWindowSizingEngine` |
| Prepared | Padding-aware width resolution | Width resolution includes horizontal padding on both sides so the shell size accounts for the full content envelope instead of raw content boxes only. | [Phase 4 content-driven width contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending activity sizing matrix | `IslandContentWidthRequirement`, `IslandShapeMetrics`, `IslandWindowSizingEngine` |
| Prepared | Notch or base width floor | The resolved activity width uses the larger of the token fallback width and the content-demand width added to the notch or base body width floor. | [Phase 4 content-driven width contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending activity sizing matrix | `IslandWidthConstraints`, `IslandShapeMetrics`, `IslandWindowSizingEngine` |
| Prepared | Display-maximum clamping | The resolved activity width is clamped by display-aware width constraints so the shell does not extend past the current top-band bounds. | [Phase 4 content-driven width contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending multi-display sizing matrix | `IslandWidthConstraints`, `ScreenMetrics`, `IslandWindowSizingEngine` |
| Prepared | Fixed-width fallback only | Fixed `ACTIVITY_COLLAPSED_WIDTH`-style values are allowed only as fallback tokens and are explicitly rejected as the primary sizing strategy for Phase 4 activity width. | [Phase 4 content-driven width contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending activity sizing matrix | `IslandVisualTokens`, `IslandShapeMetrics`, `IslandWindowSizingEngine` |

## Shadow Buffering

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Prepared | Expanded bottom shadow buffer | Expanded states return enough downward shadow buffer for the blur tail to fade naturally without a hard cutoff at the window edge. | [Phase 4 shadow-buffer contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending expanded shadow captures | `IslandShapeEngine`, `IslandWindowSizingEngine`, `IslandPanel` |
| Prepared | Expanded side shadow buffer | Expanded states preserve matching left and right shadow spread so side shadows fade evenly and do not clip at the window boundary. | [Phase 4 shadow-buffer contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending expanded shadow captures | `IslandShapeEngine`, `IslandWindowSizingEngine`, `IslandPanel` |
| Prepared | State-specific shadow buffering | Expanded-only shadow buffers do not leak into compact or activity layouts, so smaller states do not inherit oversized transparent margins. | [Phase 4 shadow-buffer contract](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) | Pending compact/activity sizing matrix and shadow captures | `IslandShapeEngine`, `IslandVisualState`, `IslandWindowSizingEngine` |

## Motion Profiles

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define motion quality targets and transition profiles. | Pending | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Interruptible Transitions

| Status | Scenario | Acceptance target | Plan reference | Evidence | Expected native modules |
| --- | --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define interruption-safe transition behavior. | Pending | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Preview Evidence

Phase 4 acceptance must be backed by preview evidence such as native render captures, synthetic sizing matrices, and motion captures. Code inspection alone is not sufficient for sign-off.

## Non-Goals

- Real business data providers
- Production music integration
- Phase 5 state-machine and interaction-intent migration
