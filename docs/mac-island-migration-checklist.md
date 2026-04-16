# State Coverage

| Item | Expected Behavior | Evidence Link | Status |
| --- | --- | --- | --- |
| Startup auth gate and fallback | Pass when startup token/auth branches consistently map to login prompt vs authenticated data fetch path, including unauthorized fallback clear behavior. | [Startup/Auth row: no token shows login](./mac-island-state-spec.md#startupauth), [Startup/Auth row: token triggers startup fetch](./mac-island-state-spec.md#startupauth), [Startup/Auth row: 401/403 fallback clears auth](./mac-island-state-spec.md#startupauth) | Prepared |
| Review and todo data branches | Pass when review-mode and todo-mode UI rules are source-backed, including review summary rendering and todo endpoint-driven badge/list updates. | [Review Rules row: default review activity branch](./mac-island-state-spec.md#review-rules), [Todo Rules row: `/todos/stats` updates badges](./mac-island-state-spec.md#todo-rules), [Todo Rules row: `/todos/tasks` drives expanded list](./mac-island-state-spec.md#todo-rules) | Prepared |
| Visual state transitions | Pass when compact/activity/expanded transition triggers are explicitly documented, including the reminder auto-open as a trigger path (not a standalone mode). | [Visual State Machine row: compact -> activity on swipe](./mac-island-state-spec.md#visual-state-machine), [Visual State Machine row: tap -> expanded](./mac-island-state-spec.md#visual-state-machine), [Visual State Machine row: reminder trigger path](./mac-island-state-spec.md#visual-state-machine) | Prepared |

# Interaction Coverage

| Item | Expected Behavior | Evidence Link | Status |
| --- | --- | --- | --- |
| Hover and click-through guard chain | Pass when hover enter/leave and collapse recovery rules define when click-through is disabled/restored, with renderer-to-main IPC evidence. | [Hover Activation row: enter/leave hover state](./mac-island-interaction-spec.md#hover-activation), [Click-Through Toggle row: `set-ignore-mouse-events` guards](./mac-island-interaction-spec.md#click-through-toggle) | Prepared |
| Pointer gesture thresholds | Pass when swipe/tap thresholds and pointer-id lock lifecycle are documented with deterministic recovery/reset behavior. | [Pointer Gestures row: swipe thresholds (+/-26)](./mac-island-interaction-spec.md#pointer-gestures), [Pointer Gestures row: tap threshold (10)](./mac-island-interaction-spec.md#pointer-gestures), [Pointer Gestures row: active pointer lock/reset](./mac-island-interaction-spec.md#pointer-gestures) | Prepared |
| Trackpad gesture accumulation and cooldown | Pass when accumulation window, direction thresholds, and lock cooldown are documented for collapse/reopen/expand gesture branches. | [Trackpad Gestures row: 160ms accumulation reset](./mac-island-interaction-spec.md#trackpad-gestures), [Trackpad Gestures row: vertical swipe collapse/reopen](./mac-island-interaction-spec.md#trackpad-gestures), [Trackpad Gestures row: 320ms cooldown lock](./mac-island-interaction-spec.md#trackpad-gestures) | Prepared |

# Animation Coverage

| Item | Expected Behavior | Evidence Link | Status |
| --- | --- | --- | --- |
| Expand/collapse shell timing | Pass when segmented collapse/open durations and easing are documented with their trigger flags and visible shell behavior. | [Expand/Collapse row: segmented collapse `0.85s`](./mac-island-animation-spec.md#expandcollapse), [Expand/Collapse row: activity open `0.56s`](./mac-island-animation-spec.md#expandcollapse) | Prepared |
| Mode switch sequence choreography | Pass when long-press arming, compact phase, reopen delay, and lock window are documented as one guarded switch sequence. | [Mode Switch row: long-press `420ms`](./mac-island-animation-spec.md#mode-switch), [Mode Switch row: compact phase `320ms`](./mac-island-animation-spec.md#mode-switch), [Mode Switch row: lock window `1240ms`](./mac-island-animation-spec.md#mode-switch) | Prepared |
| Hover motion feedback | Pass when hover scale and hover shadow transitions include explicit trigger/easing behavior and source-backed timing definitions (or explicit no-fixed-duration note). | [Hover Motion row: collapsed hover scale spring](./mac-island-animation-spec.md#hover-motion), [Hover Motion row: shadow fade `260ms`](./mac-island-animation-spec.md#hover-motion) | Prepared |

# Reminder Coverage

| Item | Expected Behavior | Evidence Link | Status |
| --- | --- | --- | --- |
| Reminder due trigger guards | Pass when invalid reminder handling and first-due-time guard chain are documented, including one-per-day auto-open conditions. | [Reminder Trigger Rules row: invalid/missing reminder time](./mac-island-state-spec.md#reminder-trigger-rules), [Reminder Trigger Rules row: due-time guard chain + one-per-day key](./mac-island-state-spec.md#reminder-trigger-rules) | Prepared |
| Reminder-driven motion path | Pass when reminder auto-open and post-expanded reminder collapse animation windows are documented with concrete durations/easing and trigger flags. | [Reminder-Triggered Motion row: auto-open `0.56s`](./mac-island-animation-spec.md#reminder-triggered-motion), [Reminder-Triggered Motion row: segmented close `0.85s`](./mac-island-animation-spec.md#reminder-triggered-motion) | Prepared |

# Music Coverage

| Item | Expected Behavior | Evidence Link | Status |
| --- | --- | --- | --- |
| End-to-end music event pipeline | Pass when worker -> service -> renderer event flow is documented, including dedupe and renderer binding behavior for payload updates. | [Providers/Inputs row: worker SMTC/poll emit](./mac-island-music-spec.md#providersinputs), [Providers/Inputs row: service dedupe + IPC forward](./mac-island-music-spec.md#providersinputs), [Providers/Inputs row: renderer `music-data-update` handling](./mac-island-music-spec.md#providersinputs) | Prepared |
| Music takeover and exit rules | Pass when takeover guards, paused timeout fallback, and stopped immediate exit behavior are documented with state transitions to/from app mode. | [Mode Switching row: playing/paused takeover](./mac-island-music-spec.md#mode-switching), [Mode Switching row: paused 30s fallback](./mac-island-music-spec.md#mode-switching), [Mode Switching row: stopped immediate app restore](./mac-island-music-spec.md#mode-switching) | Prepared |
| Playback rendering and degraded fallback | Pass when playback state mapping/progress UI and degraded fallback scenarios (media key channel, theme extraction, missing session/cover, IPC unavailable) are documented with user-visible outcomes. | [Playback States row: status normalization](./mac-island-music-spec.md#playback-states), [Playback States row: timeline drift correction](./mac-island-music-spec.md#playback-states), [Degraded Fallback rows](./mac-island-music-spec.md#degraded-fallback) | Prepared |
