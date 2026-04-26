# macOS Island Visual Token Map

This document covers only the Phase 3 visual geometry migration and excludes auth, todo data, review data, and music provider integration.

## Compact Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `collapsedWidth` branch | `front-end/src/components/DynamicIslandWidget.tsx:1483-1499` | Use the compact-collapsed preview as the non-activity baseline and keep width selection explicit instead of inferred from native content. | Branch outputs are `240` for activity, `220-300` for greeting, `230` for app todo without activity, `160` for logged-in default compact, and `180` for signed-out default compact. The Phase 3 geometry-only preview should stay on a fixed representative compact width until later state-backed work restores auth or content branches. |
| `compact preview width = 160` | `front-end/src/components/DynamicIslandWidget.tsx:1497` | Use `160` as the representative compact-collapsed preview width for the Phase 3 geometry-only shell. | This picks the logged-in default compact branch as the stable preview baseline while keeping the other Windows width branches documented for later state-driven work. |
| `collapsedHeight = 36` | `front-end/src/components/DynamicIslandWidget.tsx:1597-1620` and `front-end/src/components/DynamicIslandWidget.tsx:1691-1693` | Render the compact-collapsed shell at `36` points high. | The same `36`-point height drives the collapsed segmented keyframes, path generation inputs, and the collapsed visual-height branch used by the Electron shell. |
| `COLLAPSED_RADIUS_DEFAULT = 22` | `front-end/src/components/DynamicIslandWidget.tsx:37` and `front-end/src/components/DynamicIslandWidget.tsx:1479` | Use radius `22` for the baseline compact-collapsed shell. | The default compact radius remains active whenever `isActivityVisualState` is false. |
| `SQUIRCLE_SMOOTHNESS = 3.5` | `front-end/src/components/DynamicIslandWidget.tsx:18` and `front-end/src/components/DynamicIslandWidget.tsx:1480` | Use smoothness `3.5` for the baseline compact body and cap paths. | This value feeds the default compact path math until the shell enters the activity visual state. |
| `EAR_TENSION_IDLE = 0.4` | `front-end/src/components/DynamicIslandWidget.tsx:23` and `front-end/src/components/DynamicIslandWidget.tsx:1822-1824` | Use ear tension `0.4` for the compact-collapsed preview shell. | This is the default compact ear opening strength before activity or expanded geometry takes over. |
| `EAR_BLEND_HEIGHT_IDLE = 11` | `front-end/src/components/DynamicIslandWidget.tsx:24` and `front-end/src/components/DynamicIslandWidget.tsx:1822-1824` | Use ear blend height `11` for the compact-collapsed preview shell. | This keeps the compact ear join shallow in the baseline preview geometry. |

## Activity Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `ACTIVITY_COLLAPSED_WIDTH = 240` | `front-end/src/components/DynamicIslandWidget.tsx:53` and `front-end/src/components/DynamicIslandWidget.tsx:1483-1487` | Render the `activityCollapsed` preview shell at width `240`. | Windows routes every activity source through the same collapsed-width entry, so the native preview should treat review, todo, music, and future activity shells as one geometry family here. |
| `collapsedHeight = 36` | `front-end/src/components/DynamicIslandWidget.tsx:1597-1620` and `front-end/src/components/DynamicIslandWidget.tsx:1691-1693` | Keep the `activityCollapsed` preview shell at the same `36`-point height as compact. | Activity is distinguished by width, radius, smoothness, and ear metrics, not by a different collapsed height. |
| `COLLAPSED_RADIUS_ACTIVITY = 50` | `front-end/src/components/DynamicIslandWidget.tsx:38` and `front-end/src/components/DynamicIslandWidget.tsx:1477-1479` | Use radius `50` for the `activityCollapsed` preview shell. | The React widget swaps to the activity radius only when `showAnyActivity` makes `isActivityVisualState` true. |
| `SQUIRCLE_SMOOTHNESS_ACTIVITY = 2.3` | `front-end/src/components/DynamicIslandWidget.tsx:19` and `front-end/src/components/DynamicIslandWidget.tsx:1477-1480` | Use smoothness `2.3` for the `activityCollapsed` body and cap paths. | This lower smoothness value is part of the activity-only geometry signature that Phase 3 native previews must preserve. |
| `EAR_TENSION_ACTIVITY = 0.3` | `front-end/src/components/DynamicIslandWidget.tsx:28` and `front-end/src/components/DynamicIslandWidget.tsx:1829-1832` | Use ear tension `0.3` for the `activityCollapsed` preview shell. | The activity shell keeps a flatter liquid connector than the idle shell. |
| `EAR_BLEND_HEIGHT_ACTIVITY = 22` | `front-end/src/components/DynamicIslandWidget.tsx:29` and `front-end/src/components/DynamicIslandWidget.tsx:1829-1832` | Use ear blend height `22` for the `activityCollapsed` preview shell. | This deeper blend height is part of the activity-only ear profile that should stay visually distinct from compact. |

## Expanded Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `expandedWidth = 460` | `front-end/src/components/DynamicIslandWidget.tsx:1463` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render both expanded preview shells at width `460`. | This is a direct Phase 3 preview token and does not depend on auth, reminder, todo, or music-provider state. |
| `expandedMusicHeight = 210` | `front-end/src/components/DynamicIslandWidget.tsx:1464` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render the `expandedMusic` preview shell at height `210`. | This height is preview-ready in Phase 3; the real music data that eventually fills the shell is deferred to later business-state work. |
| `expandedAppHeight = 320` | `front-end/src/components/DynamicIslandWidget.tsx:1465` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render the `expandedApp` preview shell at height `320`. | This height is preview-ready in Phase 3; review and todo content composition remain deferred to later migration phases. |
| `expanded radius = 48` | `front-end/src/components/DynamicIslandWidget.tsx:1783`, `front-end/src/components/DynamicIslandWidget.tsx:1811`, and `front-end/src/components/DynamicIslandWidget.tsx:1941-1943` | Use radius `48` for expanded body and cap geometry. | This is a direct geometry token for the preview shells, while any later content-driven layout inside the shell is outside Phase 3 scope. |
| `EAR_TENSION_EXPANDED = 0.7` | `front-end/src/components/DynamicIslandWidget.tsx:33` and `front-end/src/components/DynamicIslandWidget.tsx:1826-1828` | Use ear tension `0.7` for both expanded preview shells. | The expanded shell keeps the strongest liquid-connection tension. |
| `EAR_BLEND_HEIGHT_EXPANDED = 32` | `front-end/src/components/DynamicIslandWidget.tsx:34` and `front-end/src/components/DynamicIslandWidget.tsx:1826-1828` | Use ear blend height `32` for both expanded preview shells. | This is the largest ear blend height in the Windows baseline and should remain shared by expanded music and expanded app previews. |

## Hover and Shadow Rules

| Rule | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `collapsed hover scale = 1.06` | `front-end/src/components/DynamicIslandWidget.tsx:1740-1742` | Render the `hoverCollapsed` preview shell with the same compact geometry multiplied by `1.06`. | This is a direct Phase 3 preview behavior and should not depend on business content. |
| `shadow visibility gate = isExpanded || isHovered` | `front-end/src/components/DynamicIslandWidget.tsx:1504` and `front-end/src/components/DynamicIslandWidget.tsx:1730-1732` | Show the shell shadow only for hover-collapsed and expanded preview states. | Compact collapsed and activity collapsed previews should remain shadowless unless the hover gate is active. |
| `shadow fade = 260ms ease-out` | `front-end/src/components/DynamicIslandWidget.tsx:1730-1734` | Use a `260ms` `ease-out` shadow transition when hover or expanded state toggles shell shadow visibility. | This timing is preview-direct for the outer shell. Any later content-specific shadows inside expanded cards are deferred until the business-state migration reconnects real content. |
| `stroke visibility = expanded shells only in Phase 3 previews` | `灵动岛迁移方案.md:747-748` and `front-end/src/components/DynamicIslandWidget.tsx:1950-1988` | Allow the inner stroke only for expanded preview shells and keep compact or activity previews fully black. | The Windows source provides the open-stroke path, but the Phase 3 preview boundary keeps non-expanded shells free of visible edge lines. |

## Path Sources

| Path function | Windows source | Native role | Notes |
| --- | --- | --- | --- |
| `generateSquirclePath(width, height, radius, smoothness)` | `front-end/src/components/DynamicIslandWidget.tsx:226-265` and `front-end/src/components/DynamicIslandWidget.tsx:1931-1943` | Primary filled body path for collapsed and expanded shell backgrounds. | Inputs are width, height, radius, and smoothness. The top edge stays flat while the lower corners are sampled as a superellipse, so the native path factory cannot replace this with a generic rounded capsule without changing the shell profile. |
| `generateOpenSquirclePath(width, height, radius, smoothness)` | `front-end/src/components/DynamicIslandWidget.tsx:268-305` and `front-end/src/components/DynamicIslandWidget.tsx:1967-1988` | Inner open stroke path for the states where Windows draws the clipped lower-edge highlight. | Uses the same geometry inputs as the filled body path but intentionally leaves the top edge open. The native version must stay aligned with the filled body path so any allowed stroke rides the same lower perimeter without introducing a top edge line. |
| `generateLeftCapPath(height, radius, smoothness)` | `front-end/src/components/DynamicIslandWidget.tsx:308-330` and `front-end/src/components/DynamicIslandWidget.tsx:1773-1783` | Left cap background path that closes the shell edge outside the center body span. | Inputs are height, radius, and smoothness over a fixed `60`-point cap width. The lower-left corner curvature has to match the body geometry so the left cap and the middle path read as one shell. |
| `generateRightCapPath(height, radius, smoothness)` | `front-end/src/components/DynamicIslandWidget.tsx:333-355` and `front-end/src/components/DynamicIslandWidget.tsx:1801-1811` | Right cap background path that mirrors the left edge treatment. | Inputs are height, radius, and smoothness over the same fixed `60`-point cap width. The lower-right corner curvature has to stay seam-free against the center body path in compact and expanded shells. |
| `generateEarPath(isLeft, tension, blendHeight)` | `front-end/src/components/DynamicIslandWidget.tsx:71-99` and `front-end/src/components/DynamicIslandWidget.tsx:1837-1866` | Liquid ear connector sizing source for the left and right shell attachments. | Inputs are side, tension, and blend height. The native path now intentionally keeps the same state-driven reach/depth tokens but renders the visible edge as a sampled continuous-corner curve tied to the shell smoothness, so the Mac connector reads closer to the lower superellipse corners instead of a separate cubic patch. |

## Seam Rules

| Constraint | Windows source | Native implication | Notes |
| --- | --- | --- | --- |
| Ear-to-body overlap must be at least `1px` | `front-end/src/components/DynamicIslandWidget.tsx:79-97` | Keep internal ear fill overlapping the body join instead of exposing an exact-edge seam. | Windows puts the visible curve start inside the island body as a gap fix. The native path factory keeps the overlap in the closed interior fill, while the visible outer curve starts at the real body edge so the connector does not show a small straight segment before the liquid curve begins. |
| Capsule replacement is not acceptable for shell geometry | `灵动岛迁移方案.md:744-746` and `front-end/src/components/DynamicIslandWidget.tsx:226-355` | Port the actual path math for the body and cap shapes instead of substituting a generic rounded capsule. | Phase 3 requires path parity with the Windows baseline, so any native simplification that collapses the shell into a `Capsule` would break the documented superellipse bottom edges and cap joins. |
| Stroke may appear only where the Windows source already draws it | `灵动岛迁移方案.md:747-748` and `front-end/src/components/DynamicIslandWidget.tsx:1950-1988` | Limit native stroke rendering to the same shell states and perimeter segments as the Windows widget. | The open stroke path is a lower-edge overlay, not a universal outline. Compact shells that are meant to stay fully black must not gain a new visible border during Phase 3. |

## Evidence

| Evidence item | Source | Verification note |
| --- | --- | --- |
