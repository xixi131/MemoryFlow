# Startup/Auth

| Condition | Trigger | Expected UI | Evidence |
| --- | --- | --- | --- |
| `mode='app'` and `isLoggedIn=false` | Widget startup with no `token`/`refreshToken` in local storage | Collapsed island shows `login` icon + `点击登录`; tapping expansion entry calls login flow instead of expanding card | Code: `front-end/src/components/DynamicIslandWidget.tsx` (`toggleExpand`, `openLogin`, collapsed `!isLoggedIn` branch). Runtime (browser MCP): `http://localhost:3002/#/widget` shows visible `点击登录` |
| `token` or `refreshToken` exists at startup | Initial `useEffect` on widget mount | Renderer marks session as logged-in candidate, starts startup fetch bundle (`/widget/summary`, `/todos/stats`, `/todos/tasks`) and user profile fetch (`/auth/me`) | Code: `front-end/src/components/DynamicIslandWidget.tsx` (`if (token || refreshToken)`, `fetchData`, `fetchUserName`). Runtime (browser MCP): token present in `localStorage`, authenticated browser-side fetch to `/api/widget/summary` returns `code=200` |
| Startup API auth check fails (`401/403`) | `/widget/summary` or todo startup endpoints return unauthorized | Auth storage is cleared (`token`, `refreshToken`, `tokenExpiresAt`) and widget falls back to unauthenticated collapsed presentation | Code: `front-end/src/components/DynamicIslandWidget.tsx` (401/403 handling in `fetchData`, auth clear + `setIsLoggedIn(false)`). Runtime (browser MCP): after startup cycle, login prompt remains visible in collapsed island despite local token injection, matching fallback behavior |
| Desktop deep-link auth callback arrives | Main process receives `memoryflow://...token=...` and forwards via IPC | Renderer receives `auth-token`, persists token fields, enters logged-in app flow and triggers startup data refresh | Code: `front-end/electron/main.cjs` (`handleDeepLink`, `sendTokenToRenderer`) + `front-end/src/components/DynamicIslandWidget.tsx` (`ipcRenderer.on('auth-token', ...)`) |

# Review Rules

| Condition | Trigger | Expected UI | Evidence |
| --- | --- | --- | --- |
|  |  |  |  |

# Todo Rules

| Condition | Trigger | Expected UI | Evidence |
| --- | --- | --- | --- |
|  |  |  |  |

# Visual State Machine

| Condition | Trigger | Expected UI | Evidence |
| --- | --- | --- | --- |
|  |  |  |  |

# Reminder Trigger Rules

| Condition | Trigger | Expected UI | Evidence |
| --- | --- | --- | --- |
|  |  |  |  |
