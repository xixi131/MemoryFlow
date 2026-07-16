# agent-state.md

## Current phase
Phase 7 settings, login-required, updater, unsigned release/install, native Todo fidelity/detail/sync, the complete web Todo/Statistics surface, and cross-surface acceptance are complete. Windows/Electron remained out of scope.

## Queue status
- Active queue: 22 tasks, 22 complete, 0 pending.
- First pending: none.

## Recommended next reads
1. `AGENTS.md`
2. The assigned task in `feature_list.json`
3. `front-end/src/pages/TodoPage.tsx`, route configuration, and `front-end/src/services/todoApis.ts`
4. Read backend trend DTO/controller code only for chart contract questions.
5. Read native Todo sync/detail code only for final cross-surface acceptance.

## Current contracts
- `/todo` and `/stats` must be route-backed sections in one shared workspace shell with browser-history support.
- Statistics owns totals and the authenticated 7/30-day created-versus-completed trend.
- Web synchronization belongs in one hook: 10 seconds visible, 60 seconds hidden, immediate refresh on route entry, focus, visibility restore, and successful mutation; stale requests must not replace newer data.
- Persist priorities as `high`, `medium`, `low`, `none`; display `紧急`, `重要`, `普通`, `未设置`.
- Web create/update payloads omit `listId`; backend legacy list associations remain intact.
- Native Todo detail is read-only, uses the stable expanded shell, and keeps checkbox completion separate from body detail navigation.

## Validation and environment
- The user explicitly waived UI/visual testing for this queue. Continue with builds, APIs, database/source contracts, deterministic probes, and responsive structure checks that do not require visual acceptance.
- Use an alternate backend port when `8080` is occupied and clean up task-started runtimes.
- Preserve untracked Xcode `xcuserdata` and unrelated worktree changes.
- Keep Windows/Electron files unchanged; use them as read-only parity references only when needed.

## Evidence pointers
- Native Phase 6 acceptance: `docs/mac-island-phase6-mock-animation-acceptance.md`.
- Native backend integration: `docs/evidence/mac-island-backend-integration/`.
- Older execution history: `codex-progress-archive.md`.
