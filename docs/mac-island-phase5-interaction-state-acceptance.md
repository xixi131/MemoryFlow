# Phase 5 Interaction And Mock-State Acceptance

Scope: Phase 5 uses mock data and native interaction intents to prove island state, derived visual output, and gesture behavior without real backend calls or real music provider integration.

## State Model

Each state-model row links back to the Phase 5 migration plan and the Windows-derived state evidence so native work can preserve baseline behavior before adding real data.

| Field | Acceptance expectation | Phase 5 source | Baseline source |
| --- | --- | --- | --- |
| `authState` | Supports `loggedOut` and `loggedIn`; logged-out compact remains a login-oriented branch and logged-in app state can expose app activity sources. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Startup/Auth`](mac-island-state-spec.md#startupauth) |
| `primaryMode` | Supports `app` and `music`; music activity only derives from mock music mode plus mock music payload. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `appDisplayMode` | Supports `review` and `todo`; reminder auto-open stays tied to review behavior and does not add a third display mode. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Review Rules`](mac-island-state-spec.md#review-rules) / [`Todo Rules`](mac-island-state-spec.md#todo-rules) |
| `presentationState` | Supports `collapsed`, `activity`, and `expanded`; tap, collapse, and vertical trackpad intents move between these shapes through reducer output. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `forceCompactMode` | Forces compact visual output while preserving any mock activity source so pointer or trackpad restore can reopen activity. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isHovered` | Tracks hover enter and leave for collapsed hover output; expanded presentation must not shrink solely because hover leaves. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isGestureTracking` | Records active pointer or trackpad gesture ownership so tap-sized movement, swipes, and recovery are not mixed in one update. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isModeSwitchAnimating` | Locks mode-switch changes during compact, mutate, and reopen phases so repeated intents cannot skip visual states. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isForceCompactTransitioning` | Marks force-compact open or close animation windows so activity content timing and shell state remain synchronized. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isReminderActive` | Simulates due reminder state with mock data and can open review activity only from compact app mode. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Reminder Trigger Rules`](mac-island-state-spec.md#reminder-trigger-rules) |
| `isReminderCollapsing` | Preserves segmented collapse behavior after reminder or activity expanded-close recovery. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isGreetingActive` | Allows greeting-specific compact width derivation without introducing real profile or backend reads. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Startup/Auth`](mac-island-state-spec.md#startupauth) |

## Derived State

| Output | Acceptance expectation | Phase 5 source | Baseline source |
| --- | --- | --- | --- |
| `hasMusicActivitySource` | True only when `primaryMode` is `music` and mock music data exists. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `hasAppActivitySource` | True only when `primaryMode` is `app` and mock auth is logged in. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `hasAnyActivitySource` | True when either mock music or mock app activity source exists, even if force compact is currently hiding activity content. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `showMusicActivity` | Shows mock music activity when a music source exists, the island is not forced compact, and presentation is not a conflicting app-only branch. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `showAppActivity` | Shows mock app activity when an app source exists, force compact is false, and review or todo derived content is available. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `showReminder` | Shows review reminder activity only for app review mode, logged-in mock state, and due-reminder simulation. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Reminder Trigger Rules`](mac-island-state-spec.md#reminder-trigger-rules) |
| `showTodoActivity` | Shows todo activity only for app todo mode with logged-in mock state and todo payload availability. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Todo Rules`](mac-island-state-spec.md#todo-rules) |
| `showAnyActivity` | True when either mock music or mock app activity should be visible; false in compact-only or logged-out states. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `isActivityVisualState` | True for the activity visual family, including review, todo, and music activity shell outputs. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `collapsedWidth` | Derives `240` for activity, `220...300` for greeting text, `180` logged out, `160` logged in app compact, and `230` todo compact. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `collapsedCornerRadius` | Produces the radius required by the resolved compact, hover, activity, or expanded visual state. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |
| `collapsedCornerSmoothness` | Produces the smoothness value required by the same resolved visual state and does not depend on real data providers. | [`Phase 5`](../灵动岛迁移方案.md#phase-5状态机交互意图和-mock-动画场景) | [`Visual State Machine`](mac-island-state-spec.md#visual-state-machine) |

## Interaction Intents

Windows baseline thresholds to mirror at Phase 5 start:

| Baseline control | Value | Source |
| --- | --- | --- |
| Tap movement window | `abs(diff) < 10` | [`Pointer tap`](mac-island-interaction-spec.md#pointer-gestures) |
| Pointer swipe threshold | `26` horizontal points | [`Pointer Gestures`](mac-island-interaction-spec.md#pointer-gestures) |
| Trackpad horizontal threshold | `70` accumulated delta | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) |
| Trackpad vertical threshold | `70` accumulated delta | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) |
| Trackpad reset window | `160ms` | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) |
| Trackpad cooldown window | `320ms` | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) |

| Intent | Acceptance expectation | Interaction source | Animation source |
| --- | --- | --- | --- |
| Hover enter | Sets hover state and resolves hover-collapsed output only when the island is not expanded. | [`Hover Activation`](mac-island-interaction-spec.md#hover-activation) | [`Hover Motion`](mac-island-animation-spec.md#hover-motion) |
| Hover leave | Clears hover state, restores click-through when safe, and preserves expanded presentation if expanded is active. | [`Hover Activation`](mac-island-interaction-spec.md#hover-activation) | [`Hover Motion`](mac-island-animation-spec.md#hover-motion) |
| Tap expand | Converts tap-sized pointer movement into expanded app or music presentation unless the logged-out login gate applies. | [`Pointer tap`](mac-island-interaction-spec.md#pointer-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Tap collapse | Converts tap or outside-collapse intent from expanded presentation back to activity or compact according to available mock sources. | [`Pointer tap`](mac-island-interaction-spec.md#pointer-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Pointer swipe to compact | Maps right swipe from visible activity into `forceCompactMode=true` compact output. | [`Pointer Gestures`](mac-island-interaction-spec.md#pointer-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Pointer swipe to activity | Maps left swipe from compact into `forceCompactMode=false` activity output when any mock activity source exists. | [`Pointer Gestures`](mac-island-interaction-spec.md#pointer-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Trackpad vertical close | Maps upward vertical swipe to close expanded presentation or collapse visible activity into compact. | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Trackpad vertical open | Maps downward vertical swipe to reopen activity from compact or expand visible activity. | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) | [`Expand/Collapse`](mac-island-animation-spec.md#expandcollapse) |
| Trackpad horizontal music command | Emits mock previous-track or next-track command metadata only while `primaryMode` is `music`. | [`Trackpad Gestures`](mac-island-interaction-spec.md#trackpad-gestures) | [`Mode Switch`](mac-island-animation-spec.md#mode-switch) |

## Mock Scenarios

The acceptance catalog must cover logged-out compact, logged-in review compact, logged-in todo compact, review activity, todo activity, music activity, expanded music, expanded app, reminder due, paused music timeout, activity-to-compact gesture, compact-to-activity gesture, expanded-collapse recovery, hover enter/leave, rapid tap, and horizontal music command scenarios.

## Window Wiring

Native preview wiring should translate AppKit, SwiftUI, menu, or probe actions into `IslandInteractionIntent` values first, then let derived state feed the existing native visual-state and motion request path. Phase 5 preview mode may own mock state inside the native window controller, but it must leave Phase 4 sizing and motion infrastructure intact.

## Gesture Guards

Gesture handling must keep click-through, hover hit frames, active pointer identity, trackpad reset, trackpad cooldown, mode-switch locks, and force-compact transition locks from producing overlapping reducer transitions. Guard failures should be visible as no-op reducer metadata rather than direct UI mutation.

## Preview Evidence

Evidence can be generated from static document checks, lightweight Swift typecheck probes, or native preview/menu scenarios. Pure docs rows do not require browser, backend, database, or physical-device validation; later frontend tasks should truthfully separate synthetic probe output from real-device hover, pointer, or trackpad capture.

## Non-Goals

- No backend API calls.
- No MediaRemote, Apple Music, Spotify, or IPC music provider integration.
- No Phase 6 content migration layouts.
- No Phase 7 app-data persistence behavior.
- No Phase 8 real music-provider behavior.
