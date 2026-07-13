# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
The backend-integration phase is complete. The active Phase 7 queue adds a login-free music-only default, opt-in Advanced Features, a notch-safe login-required square presentation, production update checks and island update progress. Windows Electron remains out of scope and must not be modified.

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
Phase 7 Settings/menu cleanup, Advanced Features lifecycle, login-required square, Sparkle updater core, and persistent update check/deferral policy are complete. Remaining work is the island update prompt, download activity, install/recovery, release, and production acceptance lifecycle. Existing real music-provider work in the current dirty worktree is not part of this queue.

## Queue status
`feature_list.json` contains 5 pending Phase 7 tasks. Start with `mac-phase7-update-prompt-square`, then continue in dependency order through download activity, install/recovery, release, and production acceptance. The updater acceptance target is a signed older-to-newer installation path, not only mocked UI.

## Phase 7 task groups
- Tasks 1-3 deliver Settings and menu cleanup, the basic-versus-advanced lifecycle, and the complete login-required square.
- Tasks 4-8 deliver the updater engine, check policy, prompt, download activity, and installation or recovery lifecycle.
- Task 9 delivers the signed release pipeline; Task 10 proves the full production-like experience.

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
- Production acceptance requires Developer ID signing, notarization, an HTTPS signed appcast, monotonic versions, minimum-macOS filtering, phased rollout metadata, and failure evidence.

## Backend integration contracts
- Login parity uses `/#/login?callback=desktop` and `memoryflow://callback?token=...&refreshToken=...&expiresIn=...`.
- Protected requests use Bearer auth with one refresh-and-retry path through `POST /auth/refresh`; sessions are stored in Keychain.
- Review mode consumes `GET /widget/summary` immediately and every 30 seconds.
- Todo mode consumes `GET /todos/stats` plus `GET /todos/tasks?status=todo&sortBy=due&sortOrder=asc`, keeps the first six tasks, polls every 60 seconds, and completes tasks through `PATCH /todos/tasks/{id}/status` with `{ "completed": true }`.

## Visual appearance
`IslandDebugAppearance.usesLightNonExpandedShell` is `false`; compact, hover, and activity states use the original dark shell and light foreground appearance.

## Expanded collapse continuity
Activity-backed expanded states recover through `expanded -> compact -> activity` on one display-link driver. The first leg is a dedicated 0.32s non-spring ease-in-out collapse that reaches compact exactly; its synchronous completion starts a recovery-specific 0.62s Apple-spring compact-to-activity leg, slightly calmer than the normal 0.56s activity opening without adding a delay or a second driver.
