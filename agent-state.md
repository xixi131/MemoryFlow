# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Phase 7 implementation is complete through unsigned installation from CI artifacts. The active queue now improves the web todo workspace, adds todo statistics trends, aligns web and native todo data, adds a read-only native detail view, and reduces cross-surface synchronization latency. Windows Electron remains out of scope and must not be modified.

## Completed native modules
- Motion plans, live animation driver, top-center window anchoring, shell shape morphing, compact/activity/expanded content choreography, hover breathing, Reduce Motion, responsive layout, and rapid-retarget guards.
- Mock greeting lifecycle; reminder auto-open; review/todo long-press switching; auth-gated mock music takeover/release, waveform, artwork, controls, and trackpad track commands.
- Pointer, mouse hit-test/outside-collapse, and vertical/horizontal trackpad adapters with deterministic mock review/todo updates and rollback.

## Evidence
- Acceptance: `docs/mac-island-phase6-mock-animation-acceptance.md`.
- Frames: `docs/evidence/mac-island-phase6/visual-state-frame-sequences.{json,md}`.
- Mouse fallback: `docs/evidence/mac-island-phase6/mac-motion-e2e-mouse-fallback-probe.json`.
- Trackpad fallback: `docs/evidence/mac-island-phase6/trackpad-e2e-fallback.json` and `trackpad-e2e.md`.
- Performance: `docs/evidence/mac-island-phase6/motion-performance-evidence.{json,md}`.

## Remaining real-world work
The todo priority-label and input-treatment foundation, composer simplification, authenticated daily trend API, and native todo data fidelity are complete. The remaining todo queue continues with list cleanup, statistics UI, synchronization, native detail work, and cross-surface acceptance. The previous `mac-phase7-github-release-acceptance` task was archived unchanged rather than completed, so it can be restored later without blocking the new queue. Existing real music-provider work and untracked Xcode user data are not part of this queue.

## Queue status
`feature_list.json` preserves 9 completed Phase 7 tasks, completes four todo-improvement slices, and contains 9 pending todo-improvement tasks. Start with `todo-web-list-filter-cleanup`.

## Todo improvement task groups
- Tasks 1-4 simplify the web creation, filtering, and editing workflow while removing all list-related UI and preserving legacy backend list data.
- Tasks 5-7 add the authenticated daily trend API, route-backed Todo/Statistics sections, and responsive 7-day/30-day charts.
- Task 8 adds adaptive web synchronization with immediate lifecycle refreshes and guarded polling.
- Tasks 9-12 preserve native todo metadata, add the read-only detail view and slide motion, and add adaptive native synchronization.
- Task 13 validates the complete web-to-mac workflow and confirms Windows/Electron files remain untouched.

## Todo layering contract
- Web page and todo components render route and form state only; a dedicated todo synchronization hook owns polling, request cancellation, stale-response protection, and mutation refreshes.
- `front-end/src/services/todoApis.ts` owns HTTP request and response contracts but no view state or timers.
- Backend todo controller/service/DTO code owns the authenticated `GET /todos/stats/trends?days=7|30` aggregation; existing tables, list APIs, and priority enum values remain unchanged.
- Native `Services/Todo` owns decoding and repository work, `State/` owns selected-task intents and derived presentation, and `UI/Visual` renders list/detail content without network calls.
- `SceneCoordinator` owns native refresh triggers and capability lifecycle; `TodoPollingController` owns cadence, deduplication, and stale snapshot behavior; window code only adapts input and rendering.

## Todo product decisions
- Persist priorities as `high`, `medium`, `low`, and `none`; display them consistently as `紧急`, `重要`, `普通`, and `未设置`.
- Remove every list-related web entry while retaining backend list fields and APIs for legacy compatibility. Web updates must omit `listId` rather than clearing existing associations.
- Keep title, priority, local date, local time, description, and optional tags in the web creation flow. Time requires a date, and clearing the date clears the time.
- Use `/todo` and `/stats` as route-backed sections with one shared segmented control. Trends support 7 and 30 days and show created-versus-completed daily counts.
- Native task detail is read-only, uses the existing expanded shell size, opens from the task body, returns with a chevron button, and leaves the circular checkbox as the only completion target.
- Normal-network synchronization targets 10 seconds while the relevant surface is active and 60 seconds while inactive or hidden, with immediate refresh on entry, focus, visibility restore, activation, wake, login restoration, and successful mutations.

## Phase 7 layering contract
- `Preferences/`: persist language, Advanced Features, and user-issued update commands; views never own auth or update network logic.
- `Services/Auth`, review, and todo coordinators: remain the only owners of sessions and protected API work; SceneCoordinator starts or stops them from the advanced-capability policy.
- `Services/Update`: own Sparkle, appcast checks, prompt scheduling, deferral, byte progress, verification, and installation; this subsystem never depends on login.
- `State/`: own pure presentation intents, precedence, return state, and derived content; no UserDefaults, network, Sparkle, or browser calls.
- `UI/Visual` and `UI/Motion`: render the login/update square and update activity through existing shape and spring infrastructure; no service calls.
- `Window/IslandWindowController`: adapt pointer and window events and render state only; orchestration remains in SceneCoordinator.

## Authentication reuse boundary
- Reuse the existing browser login page, `POST /auth/login`, CAPTCHA flow, JWT implementation, and `memoryflow://callback` contract.
- Do not build a native email/password login form, copy the React login UI into SwiftUI, or modify the existing web login and backend authentication implementation.
- Native macOS authentication continues to reuse the existing web flow, callback, Keychain session storage, `/auth/me` verification, refresh/retry, and logout lifecycle.
- Phase 7 removes the Login plus logo entry from the compact island. Browser login remains available from Settings only when Advanced Features is enabled.
- Advanced Features defaults to disabled. Disabling it stops protected work but preserves the Keychain session for later verification; music and update checks never require login.

## Updater boundary
- Use Sparkle 2 as the download, EdDSA verification, atomic replacement, authorization, and relaunch engine; do not hand-roll app replacement.
- Use an app-owned `UpdateCoordinator` and custom Sparkle user driver so Settings and island presentations consume typed state without importing Sparkle types.
- Scheduled checks run after launch and every 24 hours; Later defers the same version for four hours. Keep these constants centralized and clock-injectable.
- Releases intentionally do not use Developer ID, notarization, or a Team ID. Users install the GitHub Release app and approve its first launch through macOS right-click Open or Privacy and Security.
- Update integrity relies on Sparkle EdDSA archive signatures, HTTPS GitHub Release URLs, monotonic versions, minimum-macOS filtering, phased rollout metadata, and failure evidence. Keep the EdDSA private key outside the repository.

## Backend integration contracts
- Login parity uses `/#/login?callback=desktop` and `memoryflow://callback?token=...&refreshToken=...&expiresIn=...`.
- Protected requests use Bearer auth with one refresh-and-retry path through `POST /auth/refresh`; sessions are stored in Keychain.
- Review mode consumes `GET /widget/summary` immediately and every 30 seconds.
- Todo mode consumes `GET /todos/stats` plus `GET /todos/tasks?status=todo&sortBy=due&sortOrder=asc`, keeps the first six tasks, polls every 60 seconds, and completes tasks through `PATCH /todos/tasks/{id}/status` with `{ "completed": true }`.

## Visual appearance
`IslandDebugAppearance.usesLightNonExpandedShell` is `false`; compact, hover, and activity states use the original dark shell and light foreground appearance.

## Expanded collapse continuity
Activity-backed expanded states recover through `expanded -> compact -> activity` on one display-link driver. The first leg is a dedicated 0.32s non-spring ease-in-out collapse that reaches compact exactly; its synchronous completion starts a recovery-specific 0.62s Apple-spring compact-to-activity leg, slightly calmer than the normal 0.56s activity opening without adding a delay or a second driver.
