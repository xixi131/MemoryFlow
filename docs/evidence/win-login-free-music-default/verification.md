# win-login-free-music-default Verification

Date: 2026-07-17. Method: the widget route (`#/widget`) was driven in headless Chromium via Playwright against the Vite dev server, with `window.require('electron')` shimmed (`verify-widget.mjs`) so music IPC events (`music-data-update`) can be emitted and `shell.openExternal` calls captured. Re-run: `npm i playwright && node verify-widget.mjs` with `npx vite --port 3000` serving `front-end/`.

Raw assertion output: `results.json`. Screenshots: `music-activity.png` (logged-out music takeover), `music-expanded.png` (logged-out expanded music card), `logged-in.png` (logged-in review activity after left-swipe).

## Logged-out (basic mode)

| Check | Result |
| --- | --- |
| Compact shell is the quiet empty shell at the shared base width | 160x36, no `点击登录` text or login icon (`hasLoginText: false`) |
| Click on the island does nothing | no expansion (164x37 is hover breathing), `shell.openExternal` never called |
| No protected API traffic | zero requests to `/widget/summary`, `/todos/*`, `/auth/*` (`loggedOutProtectedApiCalls: []`) |
| Music `Playing` takes over without a session | activity shell 240x36 with cover thumb + waveform |
| Tap expands the music card without a session | 460x210, song title and artist rendered, progress advancing |
| Music `Stopped` releases takeover | returns to quiet shell 160x36; an expanded card collapses instead of exposing the app panel |

## Logged-in (regression sanity, mocked API)

| Check | Result |
| --- | --- |
| Greeting lifecycle | greeting shown at width 220 (`午安，同学`), clears after 10s |
| Default presentation | compact 160x36 (`forceCompactMode` default, per contract) |
| Left-swipe opens review activity | 240x36 showing `复习 3 项` from mocked `/widget/summary` |

## Type safety

`tsc --noEmit` error lists before and after the change are identical (23 lines, all pre-existing in `fetchData`/`TodoPage`); zero new errors.

## Known scope notes

- The login entry is intentionally gone from the island; it returns via the tray in `win-advanced-capability-lifecycle` (gap G3).
- Relaunch persistence needs no new code: the logged-out presentation is fully derived from the absence of stored tokens, and `widgetDisplayMode` persistence is unchanged.
