# Phase 3 Geometry Acceptance

## Preview Matrix

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Native preview is switched to compact collapsed shell | The preview shows one compact black shell with the documented compact width branch, `36`-point height, default radius, and default smoothness, with no business content required. | [compact-collapsed.png](./evidence/mac-island-phase3/compact-collapsed.png), [preview-board.png](./evidence/mac-island-phase3/preview-board.png), [Phase 3 token map](./mac-island-visual-token-map.md) | Passed |
| Native preview is switched to hover compact shell | The compact shell remains black but applies the Windows hover-only geometry effect, including the `1.06` hover scale and the allowed hover shadow behavior. | [hover-compact.png](./evidence/mac-island-phase3/hover-compact.png), [preview-board.png](./evidence/mac-island-phase3/preview-board.png), [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json) | Passed |
| Native preview is switched to activity compact shell | The preview shows the activity compact geometry as a visibly wider shell with the activity radius and smoothness profile, without pulling in review, todo, or music business data. | [activity-compact.png](./evidence/mac-island-phase3/activity-compact.png), [preview-board.png](./evidence/mac-island-phase3/preview-board.png), [Phase 3 token map](./mac-island-visual-token-map.md) | Passed |
| Native preview is switched to expanded music shell | The preview shows the expanded music shell at width `460` and height `210`, with the documented expanded radius and allowed shell stroke or shadow rules only. | [expanded-music.png](./evidence/mac-island-phase3/expanded-music.png), [preview-board.png](./evidence/mac-island-phase3/preview-board.png), [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json) | Passed |
| Native preview is switched to expanded app shell | The preview shows the expanded app shell at width `460` and height `320`, with geometry-only rendering that stays independent from review and todo content migration. | [expanded-app.png](./evidence/mac-island-phase3/expanded-app.png), [preview-board.png](./evidence/mac-island-phase3/preview-board.png), [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json) | Passed |

## Path Parity

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Native body, open-stroke, and cap paths are sampled for compact, activity, and expanded inputs | The sampled native `CGPath` output matches the JS baseline generated from the Windows formulas for body, open-stroke, left-cap, and right-cap paths. | [path-parity-report.json](./evidence/mac-island-phase3/path-parity-report.json), [native-path-samples.json](./evidence/mac-island-phase3/native-path-samples.json), [js-path-samples.json](./evidence/mac-island-phase3/js-path-samples.json) | Passed |
| Native left and right ear connector paths are sampled for compact, activity, and expanded inputs | Phase 3 originally matched the JS baseline exactly; the Mac connector is now intentionally superseded by a continuous-corner variant that keeps the same state-driven reach/depth tokens but improves the visible body join. | [Phase 3 token map](./mac-island-visual-token-map.md#path-sources), [IslandPathFactory.swift](../mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift) | Superseded by Mac connector polish |

## Pixel Edge Checks

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Compact, hover, activity, and expanded preview captures keep a continuous black top edge | The visible shell top edge stays opaque black across the rendered body span for all five preview states. | [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json), [preview-board.png](./evidence/mac-island-phase3/preview-board.png) | Passed |
| Compact collapsed and activity compact captures contain no unsupported non-black border | The compact-only states remain fully black with no white stroke or translucent edge artifact. | [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json), [compact-collapsed.png](./evidence/mac-island-phase3/compact-collapsed.png), [activity-compact.png](./evidence/mac-island-phase3/activity-compact.png) | Passed |
| Ear joins stay opaque where the left and right connectors meet the body | The rendered PNGs show no transparent seam at either ear join in any preview state. | [pixel-checks.json](./evidence/mac-island-phase3/pixel-checks.json), [preview-board.png](./evidence/mac-island-phase3/preview-board.png) | Passed |

## External Display Scaling

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| The top-band sizing path resolves a valid preview scale for a notch-bearing profile | The internal-notch `ScreenMetrics` harness keeps all five preview states centered on the top band and preserves the documented shadow gate when Phase 3 geometry is attached. | [display-scaling-matrix.json](./evidence/mac-island-phase3/display-scaling-matrix.json), [IslandWindowController.swift](../mac-island/MemoryFlowIsland/Window/IslandWindowController.swift), [NotchLayoutEngine.swift](../mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift) | Passed (synthetic harness) |
| The top-band sizing path resolves a clamped preview scale for a flat external-display profile | The external-flat `ScreenMetrics` harness clamps `visualScale` to `0.78`, keeps every preview shell centered, and avoids hard-coding one desktop size. | [display-scaling-matrix.json](./evidence/mac-island-phase3/display-scaling-matrix.json), [NotchLayoutEngine.swift](../mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift) | Passed (synthetic harness) |
| The preview host can switch between all five states after geometry is attached to the Phase 2 shell window | The root view and window controller now cycle through compact, hover, activity, expanded music, and expanded app without touching business data layers, while resizing the panel from geometry output rather than placeholder presets. | [IslandRootView.swift](../mac-island/MemoryFlowIsland/UI/IslandRootView.swift), [IslandVisualStatePreview.swift](../mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift), [IslandWindowController.swift](../mac-island/MemoryFlowIsland/Window/IslandWindowController.swift) | Passed |

## Non-Goals

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Acceptance review asks for auth sync or login-state wiring | Treat auth sync as out of scope for Phase 3 geometry acceptance and do not require it for preview-shell signoff. | [Phase 3 migration scope](../灵动岛迁移方案.md), [Phase 3 token map](./mac-island-visual-token-map.md) | Prepared |
| Acceptance review asks for review data rendering | Treat review data migration as a later-phase concern and do not block Phase 3 geometry acceptance on live review content. | [Phase 3 migration scope](../灵动岛迁移方案.md), [Phase 3 token map](./mac-island-visual-token-map.md) | Prepared |
| Acceptance review asks for todo data rendering | Treat todo data migration as a later-phase concern and do not block Phase 3 geometry acceptance on todo endpoint wiring or list rendering. | [Phase 3 migration scope](../灵动岛迁移方案.md), [Phase 3 token map](./mac-island-visual-token-map.md) | Prepared |
| Acceptance review asks for real music provider integration | Treat real music provider integration as out of scope for Phase 3 and allow music-shell signoff from geometry-only preview evidence. | [Phase 3 migration scope](../灵动岛迁移方案.md), [Phase 3 token map](./mac-island-visual-token-map.md) | Prepared |
| Acceptance review asks for Phase 5 state-machine behavior | Treat Phase 5 state-machine work as explicitly deferred and do not use it as a prerequisite for Phase 3 geometry acceptance. | [Phase 3 migration scope](../灵动岛迁移方案.md), [Phase 3 token map](./mac-island-visual-token-map.md) | Prepared |

## Evidence

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Phase 3 preview board exists for a fast visual read | One composite PNG shows all five preview shells rendered from the native SwiftUI preview host on a shared blue backdrop. | [preview-board.png](./evidence/mac-island-phase3/preview-board.png) | Ready |
| Path parity evidence is archived in machine-readable form | Native path samples, JS baseline samples, and the parity report are all linked from the acceptance record. | [native-path-samples.json](./evidence/mac-island-phase3/native-path-samples.json), [js-path-samples.json](./evidence/mac-island-phase3/js-path-samples.json), [path-parity-report.json](./evidence/mac-island-phase3/path-parity-report.json) | Ready |
| Phase 3 handoff note exists for the next queue slice | The handoff note summarizes the source-of-truth modules, accepted preview states, and the Phase 4 sizing inputs left by this slice. | [Phase 3 handoff note](./mac-island-phase3-geometry-handoff.md) | Ready |
