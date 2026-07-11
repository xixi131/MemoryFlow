# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
The native activity-state notch-clearance phase is complete. The next phase connects the macOS native island to the existing MemoryFlow backend in three ordered groups: authentication, real review data, and real todo data plus completion. Windows Electron remains the read-only behavior and API-contract baseline.

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
The active queue now covers browser-based desktop login callback, Keychain session storage, refresh/logout, review summary polling every 30 seconds, Windows-compatible todo querying every 60 seconds, and persisted todo completion. Physical-device calibration, performance capture, and remaining real music-provider work stay outside this phase.

## Queue status
The active backend-integration queue contains 7 pending delivery slices: 2 authentication tasks, 2 review tasks, 2 todo tasks, and 1 lifecycle acceptance task. The first pending task is `mac-auth-existing-web-login-callback`. Read `front-end/src/pages/Login.tsx`, `front-end/src/services/api.ts`, the native auth services, and the relevant native State/App composition files only as needed. Preserve the current native UI and state machine; reuse the browser login and callback contract, and keep tokens and backend DTOs out of SwiftUI and reducers.

## Authentication reuse boundary
- Reuse the existing browser login page, `POST /auth/login`, CAPTCHA flow, JWT implementation, and `memoryflow://callback` contract.
- Do not build a native email/password login form, copy the React login UI into SwiftUI, or modify the existing web login and backend authentication implementation.
- Native macOS work is limited to the Login plus logo entry state, opening the existing web flow, receiving the callback, Keychain session storage, `/auth/me` verification, refresh/retry, and logout lifecycle.

## Backend integration contracts
- Login parity uses `/#/login?callback=desktop` and `memoryflow://callback?token=...&refreshToken=...&expiresIn=...`.
- Protected requests use Bearer auth with one refresh-and-retry path through `POST /auth/refresh`; sessions are stored in Keychain.
- Review mode consumes `GET /widget/summary` immediately and every 30 seconds.
- Todo mode consumes `GET /todos/stats` plus `GET /todos/tasks?status=todo&sortBy=due&sortOrder=asc`, keeps the first six tasks, polls every 60 seconds, and completes tasks through `PATCH /todos/tasks/{id}/status` with `{ "completed": true }`.

## Visual appearance
`IslandDebugAppearance.usesLightNonExpandedShell` is `false`; compact, hover, and activity states use the original dark shell and light foreground appearance.

## Expanded collapse continuity
Activity-backed expanded states recover through `expanded -> compact -> activity` on one display-link driver. The first leg is a dedicated 0.32s non-spring ease-in-out collapse that reaches compact exactly; its synchronous completion starts a recovery-specific 0.62s Apple-spring compact-to-activity leg, slightly calmer than the normal 0.56s activity opening without adding a delay or a second driver.
