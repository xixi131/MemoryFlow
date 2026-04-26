# Phase 4 Sizing And Motion Acceptance

## Scope

Phase 4 covers native sizing and motion infrastructure only, excluding real data providers and production music integration.

Phase 4 follows the sizing and motion acceptance targets in the [Phase 4 section of `灵动岛迁移方案.md`](../灵动岛迁移方案.md#phase-4窗口尺寸编排内容驱动宽度和动画基础设施) and builds on the Phase 3 geometry inputs captured in [Phase 3 geometry handoff](./mac-island-phase3-geometry-handoff.md).

## Sizing Outputs

| Status | Scenario | Acceptance target | Evidence | Expected native modules |
| --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define visible, shadow, content, and hit-test sizing outputs. | Pending | `mac-island/MemoryFlowIsland/Window/` |

## Content-Driven Width

| Status | Scenario | Acceptance target | Evidence | Expected native modules |
| --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define content-demand width behavior and fallback rules. | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Shadow Buffering

| Status | Scenario | Acceptance target | Evidence | Expected native modules |
| --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define expanded shadow buffering and clipping expectations. | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Motion Profiles

| Status | Scenario | Acceptance target | Evidence | Expected native modules |
| --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define motion quality targets and transition profiles. | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Interruptible Transitions

| Status | Scenario | Acceptance target | Evidence | Expected native modules |
| --- | --- | --- | --- | --- |
| Pending | To be filled in Phase 4 tasks | Define interruption-safe transition behavior. | Pending | `mac-island/MemoryFlowIsland/UI/Visual/`, `mac-island/MemoryFlowIsland/Window/` |

## Preview Evidence

Phase 4 acceptance must be backed by preview evidence such as native render captures, synthetic sizing matrices, and motion captures. Code inspection alone is not sufficient for sign-off.

## Non-Goals

- Real business data providers
- Production music integration
- Phase 5 state-machine and interaction-intent migration
