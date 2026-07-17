# Windows Parity Gap Audit

Task: `win-parity-gap-audit`. Date: 2026-07-17.

Sources: `docs/windows-parity-contract.md`, the macOS Phase 7 behavior summary from `master` (`agent-state.md` at 9d6ca3a), and direct code inspection of `front-end/src/components/DynamicIslandWidget.tsx` and `front-end/electron/main.cjs` on this branch. Each gap cites the Windows code that defines current behavior.

Classification legend: **back-port** (bring Windows to mac behavior), **divergence** (intentional Windows difference, kept and documented), **n/a** (mac/platform-specific, no Windows action).

## Back-port gaps

### G1 — Login-free music default (basic mode)
- **mac:** music takeover, expanded music card, and controls never require login; the island is a music-only widget by default.
- **Windows today:** first entry into music mode is rejected while logged out — `if (!isLoggedInRef.current && modeRef.current !== 'music')` ignores the update (`DynamicIslandWidget.tsx:686`). The SMTC listener itself already starts unconditionally (`main.cjs:1465`), so the gate is renderer-only.
- **Acceptance:** logged-out launch + playing music in any SMTC source shows the music activity; takeover, pause fallback (30s), stop release, expanded card, and controls all work with no token present; no protected API request is issued.
- **Owner:** `win-login-free-music-default`

### G2 — Logged-out compact shows a login entry
- **mac:** Phase 7 removed the compact Login entry; the logged-out compact island stays visually quiet; browser login moved to Settings.
- **Windows today:** logged-out compact renders a login icon plus `点击登录` (`DynamicIslandWidget.tsx:2055-2059`); clicking it opens the external browser login (`toggleExpand` → `openLogin`, `DynamicIslandWidget.tsx:1181-1184`, `1140-1151`).
- **Acceptance:** logged-out compact island renders the quiet shell with no login icon/text and no login action on click (subject to G4 routing); login remains reachable from the tray (G3).
- **Owner:** `win-login-free-music-default`

### G3 — No Advanced Features toggle
- **mac:** Advanced Features setting (default disabled) gates auth, review, todo, and reminders; disabling stops protected work but preserves the stored session without logout; music and update checks never depend on it.
- **Windows today:** no such setting exists. The tray menu (`main.cjs:1572-1642`) has display-mode radios, auto-launch, website, check-updates, logout, quit — but no login entry and no capability toggle; protected polling is gated only by token presence (`DynamicIslandWidget.tsx:1294-1298`, `1350-1351`).
- **Acceptance:** tray gains an Advanced Features checkbox (default off, persisted in `app-config.json`) and a login entry visible only while enabled; disabling stops pollers and hides review/todo/reminder paths while preserving stored tokens; re-enabling restores the session without a new login when tokens are still valid.
- **Owner:** `win-advanced-capability-lifecycle`

### G4 — Login Required square presentation
- **mac:** with Advanced enabled and logged out, clicking the island opens a spring-driven square (visible width = height) showing a four-character Simplified Chinese message; outside click collapses it; browser login stays in Settings.
- **Windows today:** clicking the logged-out island immediately opens the browser login (`DynamicIslandWidget.tsx:1181-1184`); no square presentation exists.
- **Acceptance:** per `win-login-required-square` steps; the presentation only routes when Advanced is enabled and auth is logged out; basic mode never shows it.
- **Owner:** `win-login-required-square`

### G5 — Update prompt as island square with Update/Later capsules
- **mac:** update availability presents in the island square with a solid blue Update capsule and solid gray Later capsule; Later defers the **same version for 4 hours**, persisted.
- **Windows today:** availability is a native dialog with `['稍后再说', '跳过此版本', '立即更新']` (`main.cjs:1247-1257`); "稍后再说" defers **all checks for 6 hours** (`remindLaterUntil`, `main.cjs:1261`); a separate manual-check data-URL window exists (`updateCheckingWindow`, `main.cjs:928-955`).
- **Acceptance:** the native availability dialog and checking window are removed; the island square presents Update/Later; Later defers the same version for 4 hours across relaunch; manual tray checks remain allowed during deferral. The skip-version capability is retained (see D3).
- **Owner:** `win-update-prompt-and-download-in-island`

### G6 — Update download progress as island activity
- **mac:** download renders as an island activity — rotating blue left indicator, stable-width white right percentage, empty center; clamped monotonic progress; Reduce Motion fallback.
- **Windows today:** download progress shows in a separate 430x250 always-on-top data-URL window with percent/bytes/speed (`updateProgressWindow`, `main.cjs:879-919`); install prompt is another native dialog with `['稍后', '重启安装']` (`main.cjs:1309-1326`).
- **Acceptance:** progress renders in the island activity layout; the standalone progress window is removed; ready-to-install presents through the island; `quitAndInstall` behavior preserved.
- **Owner:** `win-update-prompt-and-download-in-island`

### G7 — Scheduled update checks (launch + every 24h)
- **mac:** checks run shortly after launch and every 24 hours, with an injectable clock.
- **Windows today:** one `setTimeout` check 5s after launch (`main.cjs:1420-1424`); no repeating interval; a 6-hour throttle applies (`UPDATE_THROTTLE_MS`, `main.cjs:415`, `1348`).
- **Acceptance:** a 24-hour repeating check joins the startup check; throttle/deferral interplay is deterministic and covered by the 4-hour same-version deferral from G5.
- **Owner:** `win-update-prompt-and-download-in-island`

### G8 — Reduce Motion support in the widget
- **mac:** Reduce Motion is honored across island motion, with non-animated but visibly active fallbacks.
- **Windows today:** no reduced-motion handling anywhere in the widget; `prefers-reduced-motion` is only used by web pages (`web-experience.css:379`, `DocsPage.tsx`, `HomePage.tsx`, `Reveal.tsx`), none referenced by `DynamicIslandWidget.tsx`.
- **Acceptance:** the widget observes `prefers-reduced-motion` (Windows "animation effects" setting propagates to Chromium) and renders reduced transitions for shell morphs, activity open/collapse, and update spinner fallback.
- **Owner:** `win-reduce-motion-support` (added to the queue by this audit)

### G9 — Widget summary polling interval
- **mac contract:** `GET /widget/summary` every 30 seconds; todos every 60 seconds.
- **Windows today:** one shared 60-second interval polls summary, todo stats, and todo tasks together (`DynamicIslandWidget.tsx:1216-1235`, `1350-1351`).
- **Acceptance:** summary polls at 30s, todos at 60s, both only while the capability policy allows (G3).
- **Owner:** `win-advanced-capability-lifecycle`

### G10 — Expanded collapse continuity (low priority)
- **mac:** activity-backed expanded states recover via `expanded → compact (0.32s ease) → activity (0.62s spring)` on one driver.
- **Windows today:** collapse goes straight back to the activity presentation with no compact intermediate (`collapseExpanded`, `DynamicIslandWidget.tsx:631-639`; presentation choice at `1471-1476`).
- **Acceptance:** deferred. Motion-only refinement; schedule after the functional gaps land. Not assigned to a queue task yet.

## Intentional Windows divergences (keep, documented)

- **D1 — Update engine:** `electron-updater` + NSIS instead of Sparkle/EdDSA. Platform-appropriate; the typed update-state contract (G5/G6) is engine-agnostic.
- **D2 — Region-aware update sources:** GitHub + gh-proxy mirror fallback with geo lookup (`main.cjs:96-110`, source selection logic). mac uses direct GitHub only. Keep — required for mainland-China users.
- **D3 — Skip this version:** `skipVersion` persistence (`main.cjs:1267`). mac offers Later only. Keep as a Windows capability; surface it in the island prompt as a secondary action or tray-level option when G5 lands.
- **D4 — Music source:** Windows SMTC (`@coooookies/windows-smtc-monitor`) vs macOS media remote. Behavior contract (takeover/pause/stop semantics) stays shared.
- **D5 — Settings surface:** tray menu instead of a Settings window. Advanced Features and login entries (G3) attach to the tray.
- **D6 — Widget not always-on-top:** deliberate on Windows (`alwaysOnTop: false`, `main.cjs:1691`) to avoid covering other apps; mac native window layering differs.
- **D7 — Token storage:** `localStorage` in the widget renderer vs macOS Keychain. Functional parity holds; storage hardening is a separate non-parity improvement candidate.

## Not applicable on Windows

- Notch-safe geometry and notch clearance rules (no notch; top-center anchor is the shared behavior).
- Unsigned-app Gatekeeper approval flow (right-click Open / Privacy & Security).
- Sparkle appcast, EdDSA signatures, phased-rollout metadata, minimum-macOS filtering.

## Queue impact

- `win-login-free-music-default` — confirmed; scope covers G1 + G2 (the renderer-side gate at `DynamicIslandWidget.tsx:686` is the only blocker for G1).
- `win-advanced-capability-lifecycle` — confirmed; picks up G3 + G9; tray is the settings surface (D5).
- `win-login-required-square` — confirmed (G4).
- `win-update-prompt-and-download-in-island` — confirmed; covers G5 + G6 + G7; must also remove `promptUpdateAvailable` / `promptUpdateDownloaded` dialogs and both data-URL windows; retains skip-version (D3) and region-aware sources (D2).
- `win-reduce-motion-support` — **new task added** for G8.
- G10 deferred; revisit after the queue above completes.
