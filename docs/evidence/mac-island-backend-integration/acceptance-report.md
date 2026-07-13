# macOS Native Backend Integration Acceptance

## Evidence mode

This run used controlled deterministic transports and state probes. No real user credentials were available, so the browser credential-entry portion was not performed live. The existing production browser URL, custom callback URL, Keychain API, request paths, JSON envelopes, native state mapping, timers, mutation behavior, and full app build were exercised without introducing a native login form.

## Authentication lifecycle

- Clean probe Keychain stored, loaded, and deleted an `AuthSession` successfully.
- Login opener resolved to `https://memoryflow.tanxhub.com/#/login?callback=desktop`.
- `memoryflow://callback` parameters were validated and duplicate callbacks rejected.
- Controlled `GET /api/auth/me` returned `tester@memoryflow.example` and published confirmed native login state.
- Two concurrent expired-token requests produced one `POST /api/auth/refresh`, atomically replaced the session, and retried once.
- Failed refresh returned logged-out state; temporary offline verification preserved the saved session.
- Online and offline logout both cleared credentials, snapshots, timers, and pending mutation state.

## Review synchronization

- Controlled `GET /api/widget/summary` produced 8 pending, 5 completed today, and `Algorithms` as the next subject.
- The same snapshot was verified in compact, hover, activity, and expanded review presentations.
- Immediate fetch, two 30-second ticks, overlap prevention, last-good stale delivery, recovery, logout cancellation, and relogin restart passed.

## Todo synchronization and completion

- Repository requested `/api/todos/stats` and `/api/todos/tasks?status=todo&sortBy=due&sortOrder=asc` concurrently.
- Stable server order was preserved and limited to task IDs 1 through 6.
- Counts and due flags were verified in compact, activity, and expanded todo presentations and after switching back to review mode.
- Immediate fetch, two 60-second ticks, overlap prevention, last-good recovery, and cancellation passed.
- Completion optimistically changed pending/due-today/overdue from `2/1/1` to `1/0/0`.
- Duplicate click was ignored. Success reconciled with a subsequent GET. Offline, server, and final-auth failures each restored the exact original snapshot once.

## Build and boundaries

- Full unsigned Debug Xcode build: `BUILD SUCCEEDED`.
- State evidence: `acceptance-state-evidence.json`.
- No Windows Electron, `Login.tsx`, backend authentication controller, JWT generation, CAPTCHA, or backend service implementation was modified by this acceptance task.
