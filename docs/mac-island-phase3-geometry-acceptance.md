# Phase 3 Geometry Acceptance

## Preview Matrix

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |
| Native preview is switched to compact collapsed shell | The preview shows one compact black shell with the documented compact width branch, `36`-point height, default radius, and default smoothness, with no business content required. | [Phase 3 token map](./mac-island-visual-token-map.md), [Phase 3 migration scope](../灵动岛迁移方案.md) | Prepared |
| Native preview is switched to hover compact shell | The compact shell remains black but applies the Windows hover-only geometry effect, including the `1.06` hover scale and the allowed hover shadow behavior. | [Phase 3 token map](./mac-island-visual-token-map.md), [Phase 3 migration scope](../灵动岛迁移方案.md) | Prepared |
| Native preview is switched to activity compact shell | The preview shows the activity compact geometry as a visibly wider shell with the activity radius and smoothness profile, without pulling in review, todo, or music business data. | [Phase 3 token map](./mac-island-visual-token-map.md), [Phase 3 migration scope](../灵动岛迁移方案.md) | Prepared |
| Native preview is switched to expanded music shell | The preview shows the expanded music shell at width `460` and height `210`, with the documented expanded radius and allowed shell stroke or shadow rules only. | [Phase 3 token map](./mac-island-visual-token-map.md), [Phase 3 migration scope](../灵动岛迁移方案.md) | Prepared |
| Native preview is switched to expanded app shell | The preview shows the expanded app shell at width `460` and height `320`, with geometry-only rendering that stays independent from review and todo content migration. | [Phase 3 token map](./mac-island-visual-token-map.md), [Phase 3 migration scope](../灵动岛迁移方案.md) | Prepared |

## Path Parity

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |

## Pixel Edge Checks

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |

## External Display Scaling

| Condition | Expected Result | Evidence | Status |
| --- | --- | --- | --- |

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
