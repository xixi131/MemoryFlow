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

## Hover and Shadow Rules

| Rule | Windows source | Expected Phase 3 preview usage | Notes |
| --- | --- | --- | --- |

## Path Sources

| Path function | Windows source | Native role | Notes |
| --- | --- | --- | --- |

## Seam Rules

| Constraint | Windows source | Native implication | Notes |
| --- | --- | --- | --- |

## Evidence

| Evidence item | Source | Verification note |
| --- | --- | --- |
