# macOS Island Visual Token Map

This document covers only the Phase 3 visual geometry migration and excludes auth, todo data, review data, and music provider integration.

## Compact Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `collapsedWidth` branch | `front-end/src/components/DynamicIslandWidget.tsx:1483-1499` | Use the compact-collapsed preview as the non-activity baseline and keep width selection explicit instead of inferred from native content. | Branch outputs are `240` for activity, `220-300` for greeting, `230` for app todo without activity, `160` for logged-in default compact, and `180` for signed-out default compact. The Phase 3 geometry-only preview should stay on a fixed representative compact width until later state-backed work restores auth or content branches. |
| `collapsedHeight = 36` | `front-end/src/components/DynamicIslandWidget.tsx:1597-1620` and `front-end/src/components/DynamicIslandWidget.tsx:1691-1693` | Render the compact-collapsed shell at `36` points high. | The same `36`-point height drives the collapsed segmented keyframes, path generation inputs, and the collapsed visual-height branch used by the Electron shell. |
| `COLLAPSED_RADIUS_DEFAULT = 22` | `front-end/src/components/DynamicIslandWidget.tsx:37` and `front-end/src/components/DynamicIslandWidget.tsx:1479` | Use radius `22` for the baseline compact-collapsed shell. | The default compact radius remains active whenever `isActivityVisualState` is false. |
| `SQUIRCLE_SMOOTHNESS = 3.5` | `front-end/src/components/DynamicIslandWidget.tsx:18` and `front-end/src/components/DynamicIslandWidget.tsx:1480` | Use smoothness `3.5` for the baseline compact body and cap paths. | This value feeds the default compact path math until the shell enters the activity visual state. |

## Activity Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `ACTIVITY_COLLAPSED_WIDTH = 240` | `front-end/src/components/DynamicIslandWidget.tsx:53` and `front-end/src/components/DynamicIslandWidget.tsx:1483-1487` | Render the `activityCollapsed` preview shell at width `240`. | Windows routes every activity source through the same collapsed-width entry, so the native preview should treat review, todo, music, and future activity shells as one geometry family here. |
| `collapsedHeight = 36` | `front-end/src/components/DynamicIslandWidget.tsx:1597-1620` and `front-end/src/components/DynamicIslandWidget.tsx:1691-1693` | Keep the `activityCollapsed` preview shell at the same `36`-point height as compact. | Activity is distinguished by width, radius, smoothness, and ear metrics, not by a different collapsed height. |
| `COLLAPSED_RADIUS_ACTIVITY = 50` | `front-end/src/components/DynamicIslandWidget.tsx:38` and `front-end/src/components/DynamicIslandWidget.tsx:1477-1479` | Use radius `50` for the `activityCollapsed` preview shell. | The React widget swaps to the activity radius only when `showAnyActivity` makes `isActivityVisualState` true. |
| `SQUIRCLE_SMOOTHNESS_ACTIVITY = 2.3` | `front-end/src/components/DynamicIslandWidget.tsx:19` and `front-end/src/components/DynamicIslandWidget.tsx:1477-1480` | Use smoothness `2.3` for the `activityCollapsed` body and cap paths. | This lower smoothness value is part of the activity-only geometry signature that Phase 3 native previews must preserve. |

## Expanded Shell Tokens

| Token | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `expandedWidth = 460` | `front-end/src/components/DynamicIslandWidget.tsx:1463` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render both expanded preview shells at width `460`. | This is a direct Phase 3 preview token and does not depend on auth, reminder, todo, or music-provider state. |
| `expandedMusicHeight = 210` | `front-end/src/components/DynamicIslandWidget.tsx:1464` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render the `expandedMusic` preview shell at height `210`. | This height is preview-ready in Phase 3; the real music data that eventually fills the shell is deferred to later business-state work. |
| `expandedAppHeight = 320` | `front-end/src/components/DynamicIslandWidget.tsx:1465` and `front-end/src/components/DynamicIslandWidget.tsx:1754-1756` | Render the `expandedApp` preview shell at height `320`. | This height is preview-ready in Phase 3; review and todo content composition remain deferred to later migration phases. |
| `expanded radius = 48` | `front-end/src/components/DynamicIslandWidget.tsx:1783`, `front-end/src/components/DynamicIslandWidget.tsx:1811`, and `front-end/src/components/DynamicIslandWidget.tsx:1941-1943` | Use radius `48` for expanded body and cap geometry. | This is a direct geometry token for the preview shells, while any later content-driven layout inside the shell is outside Phase 3 scope. |

## Hover and Shadow Rules

| Rule | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |
| `collapsed hover scale = 1.06` | `front-end/src/components/DynamicIslandWidget.tsx:1740-1742` | Render the `hoverCollapsed` preview shell with the same compact geometry multiplied by `1.06`. | This is a direct Phase 3 preview behavior and should not depend on business content. |
| `shadow visibility gate = isExpanded || isHovered` | `front-end/src/components/DynamicIslandWidget.tsx:1504` and `front-end/src/components/DynamicIslandWidget.tsx:1730-1732` | Show the shell shadow only for hover-collapsed and expanded preview states. | Compact collapsed and activity collapsed previews should remain shadowless unless the hover gate is active. |
| `shadow fade = 260ms ease-out` | `front-end/src/components/DynamicIslandWidget.tsx:1730-1734` | Use a `260ms` `ease-out` shadow transition when hover or expanded state toggles shell shadow visibility. | This timing is preview-direct for the outer shell. Any later content-specific shadows inside expanded cards are deferred until the business-state migration reconnects real content. |

## Path Sources

| Path function | Windows source | Native role | Notes |
| --- | --- | --- | --- |

## Seam Rules

| Constraint | Windows source | Native implication | Notes |
| --- | --- | --- | --- |

## Evidence

| Evidence item | Source | Verification note |
| --- | --- | --- |
