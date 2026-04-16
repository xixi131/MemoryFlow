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
| `appDisplayMode` defaults to `review`, or IPC sync sends any mode except `todo` | Widget mount initializes local mode and Electron emits `widget-display-mode-changed` | Collapsed activity row uses `ReviewModeIcon`; title uses `复习 {totalPendingReviews} 项`; right badge uses amber style and shows `totalPendingReviews` | Code: `front-end/src/components/DynamicIslandWidget.tsx:589`, `front-end/src/components/DynamicIslandWidget.tsx:737`, `front-end/src/components/DynamicIslandWidget.tsx:2095`, `front-end/src/components/DynamicIslandWidget.tsx:2102`, `front-end/src/components/DynamicIslandWidget.tsx:2111` |
| `mode='app'` and logged-in activity source exists and `appDisplayMode='review'` and `forceCompactMode=false` | Activity state becomes visible after entering app activity view | Review branch (`showReminder`) is selected, todo branch (`showTodoActivity`) is not selected | Code: `front-end/src/components/DynamicIslandWidget.tsx:1473`, `front-end/src/components/DynamicIslandWidget.tsx:1474`, `front-end/src/components/DynamicIslandWidget.tsx:1475` |
| Review summary API returns success (`summaryRes.code===200`) | `fetchData()` runs on startup token check, `auth-token` IPC login, and periodic refresh timer | `data` is replaced by summary payload; review pending/completed counters and subject list render from latest summary | Code: `front-end/src/components/DynamicIslandWidget.tsx:1216`, `front-end/src/components/DynamicIslandWidget.tsx:1220`, `front-end/src/components/DynamicIslandWidget.tsx:1238`, `front-end/src/components/DynamicIslandWidget.tsx:1239`, `front-end/src/components/DynamicIslandWidget.tsx:1295`, `front-end/src/components/DynamicIslandWidget.tsx:1304`, `front-end/src/components/DynamicIslandWidget.tsx:1350` |
| Island is expanded and current app display mode is not `todo` | User expands card while app display mode remains review | Expanded panel enters review layout: top cards show `待复习`=`data.totalPendingReviews` and `今日完成`=`data.totalCompletedToday` | Code: `front-end/src/components/DynamicIslandWidget.tsx:2289`, `front-end/src/components/DynamicIslandWidget.tsx:2367`, `front-end/src/components/DynamicIslandWidget.tsx:2374`, `front-end/src/components/DynamicIslandWidget.tsx:2382` |
| Subject rows include only items with `pendingReviewCount>0`; list may exceed 4 items | Review expanded list computes derived arrays (`activeSubjects`, `displaySubjects`, `hasMore`, `emptySlots`) | Grid shows up to 4 subject cards; extra count appears as `+还有 N 个待复习科目`; when not full, placeholder slots are rendered and footer can show `已显示全部` | Code: `front-end/src/components/DynamicIslandWidget.tsx:2408`, `front-end/src/components/DynamicIslandWidget.tsx:2409`, `front-end/src/components/DynamicIslandWidget.tsx:2410`, `front-end/src/components/DynamicIslandWidget.tsx:2411`, `front-end/src/components/DynamicIslandWidget.tsx:2443`, `front-end/src/components/DynamicIslandWidget.tsx:2471`, `front-end/src/components/DynamicIslandWidget.tsx:2473` |

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
