## Current Summary

### Current phase
- Phase 6 native mock animation and Windows-parity queue is active.
- Completed foundations: contracts, deterministic scenarios, motion planning and driver, shell morphing, compact content, anchored sizing, single-instance helper behavior, hover, activity open/collapse, and expanded app opening.
- The native helper now forbids multiple simultaneous instances, preventing duplicate Dynamic Island panels.

### Queue snapshot
- First pending task: `mac-motion-handoff`.
- Remaining queue size: `1` Phase 6 task.

### 2026-07-10 - Phase 6 E2E evidence
- Generated 55 deterministic visual-state frames across 11 mock scenarios, with shape, shadow, content-phase, and rejection metadata.
- Mouse and trackpad fallback probes cover native routing and guard behavior; both explicitly record that physical GUI capture remains pending.

### 2026-07-10 - Phase 6 mock animation handoff
- Phase 6 is complete: native deterministic mock motion now covers compact, greeting, review/todo/reminder, music, expanded states, input adapters, content choreography, and motion accessibility.
- Acceptance and deterministic evidence are in `docs/mac-island-phase6-mock-animation-acceptance.md` and `docs/evidence/mac-island-phase6/`; mouse/trackpad evidence is explicitly fallback-only, not physical GUI capture.
- Future work remains physical-device calibration/profiling and real backend, auth, persistence, provider, Keychain, and IPC integration.
- Execution mode: parent-led Auto_dev; parallel only for dependency-free, disjoint write scopes.

### Runtime notes
- Full Xcode 26.6 is active. Standard validation: `xcodebuild -project mac-island/MemoryFlowIsland.xcodeproj -scheme MemoryFlowIsland -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
- Test `MemoryFlowIsland` processes must be terminated after each runtime check.
- Worktree contains user-authorized pre-existing changes; preserve them while continuing task-scoped work.

## Recent Records

### 2026-07-10 - Window and duplicate panel fix
- Pixel-aligned top-center sizing now passes 20 notch/flat display samples.
- `LSMultipleInstancesProhibited` prevents concurrent native helper processes and duplicate panels.
- Xcode Debug build and focused sizing probe passed.

### 2026-07-10 - Core motion behavior
- Implemented exact compact hover, compact-to-activity opening, and segmented activity collapse with content choreography.
- Probes cover review, todo, music, reminder, and expanded recovery paths; Xcode builds passed.

### 2026-07-10 - Expanded app opening
- Review and todo activity routes now share the expanded app shell timeline and retain distinct layouts; tap and trackpad routes converge on `460 x 320` pre-scale geometry.
- Focused motion probe and Xcode Debug build passed; no native process was left running.

### 2026-07-10 - Expanded music opening
- Music activity now reaches the `460 x 210` pre-scale expanded shell with artwork, metadata, waveform, progress, and controls gated on one mock-only timeline.
- Tap and trackpad routes were probe-verified to converge on identical expanded music content and geometry; Xcode Debug build passed with no test process left running.

### 2026-07-10 - Expanded collapse recovery
- Expanded review, todo, and music now follow the Windows two-stage recovery: `expanded -> compactCollapsed -> matching activityCollapsed`; force compact terminates at ordinary compact.
- Focused nine-route tap/outside/trackpad probe, reducer recovery probe, and Xcode Debug build passed with no native process remaining.

### 2026-07-10 - Greeting lifecycle
- Greeting now enters and exits over 0.35s around its deterministic 10-second lifecycle; fast-forward and music takeover cancel it and release the compact width branch.
- `init.sh` and an unsigned Xcode Debug build passed. The timeline probe covers deterministic samples; GUI capture remains unavailable.

### 2026-07-10 - Review/todo long press
- Leading-icon holds now follow the Windows 420ms hold, 320ms compact, 70ms wait, and 0.56s activity-reopen sequence; early release, leave, cancel, scenario replacement, and duplicates are guarded.
- The deterministic bidirectional mode-switch probe, Xcode Debug build, and helper launch smoke test passed.

### 2026-07-10 - Reminder auto-open
- Reminder due is keyed and deterministic: only an app compact state can open review activity, repeated daily keys are ignored, and new keys replay the existing activity motion.
- The focused reminder probe and Xcode Debug build passed. An unrelated legacy-wide interaction probe retains three non-reminder transition-kind expectation mismatches.

### 2026-07-10 - Music takeover
- A mock playback-start control is auth-gated, clears force compact, and opens music activity; active-music snapshots use a 0.18s content retarget rather than replaying shell takeover.
- `init.sh`, the focused music-takeover probe, and Xcode Debug build passed.

### 2026-07-10 - Music release
- Paused 30-second and stopped controls now deterministically leave music; resumed or newer snapshots cancel/restart the pending timeout and app targets retain review/todo mode plus compact intent.
- Focused release probe, `init.sh`, and Xcode Debug build passed; broad legacy reducer evidence retains an unrelated tap expectation mismatch.

### 2026-07-10 - Music waveform
- Music now renders four activity or five expanded local waveform bars with phase-shifted 2.2-second motion, theme tint, display scaling, and 0.3-second paused settling.
- Focused waveform probe, `init.sh`, and Xcode Debug build passed; ticks stop when the waveform is not playing or visible.

### 2026-07-10 - Music artwork
- Artwork now uses a matched activity-to-expanded presentation model with interpolated geometry and isolated directional metadata changes.
- Transition probe, `init.sh`, and Xcode Debug builds passed.

### 2026-07-11 - Global Apple spring API
- Added one cached SwiftUI `Animation.spring(response: 0.35, dampingFraction: 0.70)` and the generic `.applyAppleSpring(value:)` modifier for Equatable state.
- Full native Swift typecheck and focused Bool/enum compile probes passed; the API is documented for one-time outer-shell attachment and in-flight retargeting.

### 2026-07-11 - Apple spring shell integration
- Attached the shared spring once to the black SwiftUI shell layer while excluding the content overlay and stabilizing the key for display-link-owned geometry samples.
- Full native typecheck and the rapid-retarget probe passed, covering forward/reverse keys, inherited velocity, snap prevention, stale completion rejection, bounded deltas, and final convergence.

### 2026-07-11 - Activity notch-clearance layout
- Added a shared native activity-clearance calculation that derives centered activity width from the physical-notch or compact center span plus balanced leading and trailing content reach and shared padding.
- Compact notch matching remains unchanged; focused notched and flat-display probes passed at 450pt and 411pt activity widths, along with the full native Swift typecheck.

### 2026-07-11 - Three-mode activity notch-clearance integration
- Unified review, todo, music, reminder, and activity-hover sizing around two shared 32pt square slots with 6pt notch spacing.
- Each side-region centers its content with balanced horizontal and vertical breathing room. Review and todo render icon-left/count-right; music renders cover-left/waveform-right. A three-segment HStack keeps both sides present around the empty notch center. Production-derived probes passed for all three modes on notched and flat displays (286pt on the 210pt-notch fixture), and the full native Swift typecheck passed.
- Visual calibration is complete and `IslandDebugAppearance.usesLightNonExpandedShell` is disabled, restoring the original dark compact, hover, and activity appearance.
- Expanded review, todo, and music collapse recovery now retargets to activity at 92% of the collapse with the driver still running, preserving the live frame and velocity instead of settling at compact. The continuity driver probe and all 9 tap/outside/trackpad recovery routes pass.

### 2026-07-11 - Native authentication adapter foundation
- Added a typed native API transport, secure Keychain and in-memory auth session stores, authenticated-user models, and an injectable `AuthCoordinator` composed by `SceneCoordinator`.
- The unsigned native Xcode build, authenticated `/auth/me` transport probe, Keychain round-trip probe, project lint, and diff checks passed without changing Windows, Electron, web-login, or backend files.

### 2026-07-11 - Existing web login callback
- Connected the logged-out native Login prompt to the existing browser login flow, registered the `memoryflow` callback scheme, persisted validated callback sessions, and mapped verified `/auth/me` users into native greeting state.
- The full native build and deterministic browser/callback probe passed, including exact login URL, Bearer verification, nickname/email mapping, malformed input handling, and duplicate callback rejection.

### 2026-07-11 - Native authentication session lifecycle
- Added verified startup restoration, shared coalesced refresh with one protected-request retry, offline-aware credential handling, and menu-bar Logout with unconditional local cleanup and future review/todo cancellation hooks.
- Deterministic startup, concurrent refresh, failed refresh, offline restoration, offline logout, and normal logout probes passed with the full native build; task-owned runtime processes were stopped afterward.

### 2026-07-11 - Live native review summary
- Added `/widget/summary` DTOs, a UI-independent `ReviewSnapshot`, an authenticated review repository, immediate post-login loading, and production review rendering across compact, hover, activity, and expanded states.
- The full native build and controlled endpoint probe passed for pending/completed counts, subject titles, next-subject mapping, zero-safe values, and the exact `/api/widget/summary` request path.

### 2026-07-11 - Thirty-second review synchronization
- Added an injectable 30-second review polling controller with immediate authenticated fetch, overlap prevention, main-actor delivery, stale last-good snapshots, refresh-failure invalidation, and logout/relogin lifecycle handling.
- Deterministic timing and failure probes passed for two ticks, slow requests, offline recovery, failed refresh, cancellation, restart, and live review presentations; the full native build passed.

### 2026-07-11 - Live todo preview and sixty-second sync
- Added concurrent authenticated todo stats/tasks loading with the Windows-compatible due query, stable first-six `TodoSnapshot` mapping, native compact/activity/expanded rendering, and an independent 60-second poller.
- The full native build and controlled probes passed for query semantics, counts, order/limit, due labels, mode switching, two ticks, overlap prevention, last-good recovery, and lifecycle cancellation.

### 2026-07-11 - Persisted native todo completion
- Routed native todo row completion through a per-task mutation controller and authenticated PATCH repository operation with exact optimistic aggregate updates, success refresh reconciliation, and one-time snapshot rollback.
- The full native build and deterministic probes passed for success persistence, duplicate clicks, offline/server failures, final authorization failure, exact rollback, and subsequent GET confirmation.

### 2026-07-11 - Backend integration acceptance
- Recorded controlled deterministic evidence for the reused browser callback, confirmed session, review and todo synchronization, persisted todo completion, token refresh, and complete logout cleanup under `docs/evidence/mac-island-backend-integration`.
- The full native build and focused lifecycle probes passed; evidence is explicitly labeled controlled-synthetic because no real user credentials were available for live browser credential entry.

### 2026-07-13 - Phase 7 Settings and menu cleanup
- Added persistent localized Advanced Features settings with conditional account controls and removed the obsolete production Phase 5 Interactions menu wiring while preserving probe fixtures and unrelated commands.
- The native settings/menu probe, full Swift source typecheck, and unsigned Debug build passed; Windows and Electron files were unchanged and no native validation process remained running.

### 2026-07-13 - Advanced capability lifecycle
- Made Advanced Features the SceneCoordinator-owned gate for authentication and protected review, todo, and reminder work while leaving music and updates available in basic mode.
- Deterministic lifecycle evidence and the integrated Debug build passed; disabling preserves the saved session and active music, clears protected state, and stops protected work without duplicate timers.

### 2026-07-13 - Signed Sparkle updater core
- Added Sparkle 2.9.4 with a custom user driver, typed login-independent coordinator states, HTTPS/public-key configuration, callback guards, and public-only signed appcast fixtures.
- Signed current/newer, malformed, non-HTTPS, invalid-signature, duplicate, stale-session, and regressive-progress probes passed with the integrated native build and full Swift source typecheck.

### 2026-07-13 - Login-required square
- Removed compact login UI and added a pure advanced-only login-required presentation with the exact four-character `需要登录` message in a notch-safe square.
- Deterministic wide/narrow geometry, repeat/outside/login/music routes, reverse spring, Reduce Motion, integrated Debug build, and full Swift source typecheck passed.

### 2026-07-13 - Update check and deferral policy
- Added a persistent login-independent launch/24-hour/wake scheduler, typed Settings update states, offline retry, and four-hour same-version deferral with manual bypass and newer-version cleanup.
- Deterministic relaunch/cadence/termination policy probes, integrated Debug build, and full Swift source typecheck passed without starting authentication or protected traffic.

### 2026-07-13 - Update prompt square
- Routed updater availability through pure island intents and added a notch-safe square prompt with accessible solid blue Update and solid gray Later capsules.
- Music return, outside-click safety, Reduce Motion, repeated callbacks, four-hour relaunch deferral, manual checks during deferral, integrated build, and deterministic UI/update probes passed.

### 2026-07-13 - Update download activity
- Gated island activity on Sparkle download-start confirmation and added duplicate/stale/retry-safe progress normalization with unknown-length support.
- Signed setup/failure/retry and 0-100 probes plus the blue left spinner, stable white right percentage, empty notch, restoration, Reduce Motion, and integrated build passed.

### 2026-07-13 - Unsigned GitHub CI/CD release foundation
- Added one local and CI release path for ad-hoc MemoryFlow Island builds, Sparkle ZIP packaging, SHA-256, EdDSA-signed appcasts, monotonic version guards, and ordered GitHub Release publication.
- A v1.1.0 build 10 dry-run produced and verified a 2,685,138-byte app archive with GitHub URLs, no Team ID or notarization, valid archive/appcast signatures, and no private-key leakage.

### 2026-07-13 - Unsigned Sparkle install from CI artifacts
- Generated real ad-hoc 1.0.0 build 100 and 1.0.1 build 101 candidates through the shared release command and verified a 2,689,109-byte Sparkle download, EdDSA validation, atomic replacement, old-process termination, and same-path relaunch into build 101.
- Recheck suppression, future checks, tampered-signature, malformed-feed, HTTP, offline, disk, cancellation, explicit retry, duplicate, stale-callback, timer, deferral, and user-approved unsigned launch paths passed; all task-started processes were stopped.

### 2026-07-16 - Todo priority labels and controls
- Centralized todo priority presentation as `紧急`, `重要`, `普通`, and `未设置` without changing API enum values, and applied todo-scoped white bordered light controls, restrained dark controls, 8px radii, and consistent focus, placeholder, and disabled styling.
- The web build and diff checks passed. Chrome verification covered desktop and mobile light/dark layouts, complete priority options, visible focus rings, expected computed colors, and zero horizontal overflow; the temporary local preview gate was fully removed afterward.

### 2026-07-16 - Native todo data fidelity
- Preserved web todo descriptions, actual priority, due date, and due time through native decoding, snapshots, optimistic completion/rollback, domain presentation, and rendered task slots.
- Deterministic probes covered all four priority labels and completed, overdue, today, tomorrow, later-date, date-only, and no-date due states. The integrated Xcode build and live todo probes passed, Windows/Electron files remained unchanged, and task-started processes were cleaned up.

### 2026-07-16 - Authenticated todo daily trends
- Added authenticated 7-day and 30-day todo creation/completion trends with user-isolated MySQL date aggregation, local-calendar half-open boundaries, ascending ISO dates, and zero-filled missing days.
- Five service/controller tests passed. Live authenticated requests returned 7 and 30 points, invalid ranges returned HTTP 400, unauthenticated access was rejected, and three-user database verification confirmed aggregation remained scoped by `user_id`.

### 2026-07-16 - Web todo composer simplification
- Removed list controls and `listId` from task creation, preserved priority/description/tags, and enforced date-before-time behavior. Web build, authenticated minimal/metadata creates, API refreshes, and persisted field checks passed; native picker UI testing was user-waived.

### 2026-07-16 - Native todo detail and adaptive sync
- Added reducer-owned read-only detail plus 10s active/60s background synchronization. Detail, data-fidelity, live-sync probes and the unsigned Debug build passed.
