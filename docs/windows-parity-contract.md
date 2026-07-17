# Windows Parity Contract

## Scope

This is the shared behavior contract between the Windows Electron island
(`front-end/src/components/DynamicIslandWidget.tsx`,
`front-end/electron/main.cjs`) and the macOS native island (maintained on
`master`). It was originally derived from the Windows implementation as the
macOS migration baseline; on the `MemoryFlow_Windows` branch it now serves the
reverse role: **Windows changes that alter any state, constant, or sequence in
this contract must be intentional, documented divergences or must be synced
with the macOS implementation.** Line references point at the Windows sources
in this repository.

## State Matrix

| Windows state | Entry condition and presentation contract | Parity evidence |
| --- | --- | --- |
| Logged-out compact | `mode='app'`, `isLoggedIn=false`, and not expanded. The compact shell uses its logged-out width (`180`) and renders the login icon with `点击登录`; a tap starts login rather than opening a panel. | [DynamicIslandWidget.tsx:1181](../front-end/src/components/DynamicIslandWidget.tsx#L1181), [DynamicIslandWidget.tsx:1497](../front-end/src/components/DynamicIslandWidget.tsx#L1497), [DynamicIslandWidget.tsx:2055](../front-end/src/components/DynamicIslandWidget.tsx#L2055) |
| Logged-in compact | `mode='app'`, `isLoggedIn=true`, `forceCompactMode=true`, and not expanded. It is the non-activity compact family with base width `160`; an activity source can later reopen it. | [DynamicIslandWidget.tsx:1467](../front-end/src/components/DynamicIslandWidget.tsx#L1467), [DynamicIslandWidget.tsx:1472](../front-end/src/components/DynamicIslandWidget.tsx#L1472), [DynamicIslandWidget.tsx:1497](../front-end/src/components/DynamicIslandWidget.tsx#L1497), [DynamicIslandWidget.tsx:1592](../front-end/src/components/DynamicIslandWidget.tsx#L1592) |
| Greeting | A signed-in app greeting has text plus `isGreetingActive=true`; its compact width is clamped to `220..300`, content enters vertically, and it self-clears after 10 seconds. Music takes precedence by clearing the greeting. | [DynamicIslandWidget.tsx:1166](../front-end/src/components/DynamicIslandWidget.tsx#L1166), [DynamicIslandWidget.tsx:1488](../front-end/src/components/DynamicIslandWidget.tsx#L1488), [DynamicIslandWidget.tsx:2060](../front-end/src/components/DynamicIslandWidget.tsx#L2060), [DynamicIslandWidget.tsx:1368](../front-end/src/components/DynamicIslandWidget.tsx#L1368) |
| Review activity | Signed-in app mode with `appDisplayMode='review'` and `forceCompactMode=false`. This is the review/reminder branch of the shared activity shell. | [DynamicIslandWidget.tsx:1469](../front-end/src/components/DynamicIslandWidget.tsx#L1469), [DynamicIslandWidget.tsx:1473](../front-end/src/components/DynamicIslandWidget.tsx#L1473), [DynamicIslandWidget.tsx:1475](../front-end/src/components/DynamicIslandWidget.tsx#L1475), [DynamicIslandWidget.tsx:2075](../front-end/src/components/DynamicIslandWidget.tsx#L2075) |
| Todo activity | Signed-in app mode with `appDisplayMode='todo'` and `forceCompactMode=false`. It uses the same activity shell as review, but selects the todo content branch. | [DynamicIslandWidget.tsx:737](../front-end/src/components/DynamicIslandWidget.tsx#L737), [DynamicIslandWidget.tsx:1474](../front-end/src/components/DynamicIslandWidget.tsx#L1474), [DynamicIslandWidget.tsx:1475](../front-end/src/components/DynamicIslandWidget.tsx#L1475), [DynamicIslandWidget.tsx:2075](../front-end/src/components/DynamicIslandWidget.tsx#L2075) |
| Music activity | A `Playing` or `Paused` music IPC update takes over when the session is logged in (or already in music mode), assigns `musicData`, clears forced compact mode, and selects `mode='music'`. | [DynamicIslandWidget.tsx:667](../front-end/src/components/DynamicIslandWidget.tsx#L667), [DynamicIslandWidget.tsx:683](../front-end/src/components/DynamicIslandWidget.tsx#L683), [DynamicIslandWidget.tsx:695](../front-end/src/components/DynamicIslandWidget.tsx#L695), [DynamicIslandWidget.tsx:1468](../front-end/src/components/DynamicIslandWidget.tsx#L1468), [DynamicIslandWidget.tsx:1472](../front-end/src/components/DynamicIslandWidget.tsx#L1472) |
| Expanded review | An eligible tap toggles `isExpanded`; with app display mode other than todo, the expanded card uses the fixed app geometry `460 x 320` and renders the review layout. | [DynamicIslandWidget.tsx:1124](../front-end/src/components/DynamicIslandWidget.tsx#L1124), [DynamicIslandWidget.tsx:1462](../front-end/src/components/DynamicIslandWidget.tsx#L1462), [DynamicIslandWidget.tsx:1465](../front-end/src/components/DynamicIslandWidget.tsx#L1465), [DynamicIslandWidget.tsx:2289](../front-end/src/components/DynamicIslandWidget.tsx#L2289) |
| Expanded todo | The same expanded app geometry (`460 x 320`) applies when `appDisplayMode='todo'`; the todo-specific expanded branch renders its counters and task rows. | [DynamicIslandWidget.tsx:737](../front-end/src/components/DynamicIslandWidget.tsx#L737), [DynamicIslandWidget.tsx:1462](../front-end/src/components/DynamicIslandWidget.tsx#L1462), [DynamicIslandWidget.tsx:1465](../front-end/src/components/DynamicIslandWidget.tsx#L1465), [DynamicIslandWidget.tsx:2296](../front-end/src/components/DynamicIslandWidget.tsx#L2296) |
| Expanded music | An eligible tap while music activity is visible toggles the expanded state; the music card uses fixed geometry `460 x 210`. | [DynamicIslandWidget.tsx:1124](../front-end/src/components/DynamicIslandWidget.tsx#L1124), [DynamicIslandWidget.tsx:1462](../front-end/src/components/DynamicIslandWidget.tsx#L1462), [DynamicIslandWidget.tsx:1464](../front-end/src/components/DynamicIslandWidget.tsx#L1464), [DynamicIslandWidget.tsx:2040](../front-end/src/components/DynamicIslandWidget.tsx#L2040) |
| Reminder due | The 10-second time check observes the due edge once per day key. While in compact app mode and not expanded, it opens the existing review activity presentation; it is not an independent display mode. | [DynamicIslandWidget.tsx:1416](../front-end/src/components/DynamicIslandWidget.tsx#L1416), [DynamicIslandWidget.tsx:1438](../front-end/src/components/DynamicIslandWidget.tsx#L1438), [DynamicIslandWidget.tsx:1442](../front-end/src/components/DynamicIslandWidget.tsx#L1442), [DynamicIslandWidget.tsx:1450](../front-end/src/components/DynamicIslandWidget.tsx#L1450), [DynamicIslandWidget.tsx:1473](../front-end/src/components/DynamicIslandWidget.tsx#L1473) |
| Music paused | A `Paused` update remains in the music activity presentation and starts a 30-second fallback timer; when it fires the widget returns to app mode and clears music data. | [DynamicIslandWidget.tsx:683](../front-end/src/components/DynamicIslandWidget.tsx#L683), [DynamicIslandWidget.tsx:706](../front-end/src/components/DynamicIslandWidget.tsx#L706), [DynamicIslandWidget.tsx:708](../front-end/src/components/DynamicIslandWidget.tsx#L708) |
| Music stopped | A `Stopped` update immediately returns the widget to app mode and clears music data, restoring the applicable app compact/activity state. | [DynamicIslandWidget.tsx:713](../front-end/src/components/DynamicIslandWidget.tsx#L713), [DynamicIslandWidget.tsx:715](../front-end/src/components/DynamicIslandWidget.tsx#L715) |

The Electron bridge persists and resends the review/todo display mode, anchors its
transparent widget at the top center, and sends a collapse event on window blur.
Native code may implement equivalent behavior through its own boundaries, not by
editing the Windows bridge. [main.cjs:1168](../front-end/electron/main.cjs#L1168)
[main.cjs:1292](../front-end/electron/main.cjs#L1292)
[main.cjs:1407](../front-end/electron/main.cjs#L1407)

## Exact Windows Constants

| Contract value | Windows source |
| --- | --- |
| Shell spring: stiffness `280`, damping `30`, mass `1.2` | [DynamicIslandWidget.tsx:6](../front-end/src/components/DynamicIslandWidget.tsx#L6) |
| Pointer activity swipe threshold: `26px` | [DynamicIslandWidget.tsx:926](../front-end/src/components/DynamicIslandWidget.tsx#L926) |
| Pointer tap threshold: `10px` | [DynamicIslandWidget.tsx:927](../front-end/src/components/DynamicIslandWidget.tsx#L927) |
| Trackpad dominant-axis threshold: `70`; accumulation reset: `160ms`; cooldown: `320ms` | [DynamicIslandWidget.tsx:931](../front-end/src/components/DynamicIslandWidget.tsx#L931), [DynamicIslandWidget.tsx:974](../front-end/src/components/DynamicIslandWidget.tsx#L974) |
| Activity open: `0.56s`; activity collapse: `0.85s`; segmented times: `[0, 0.45, 0.55, 1]` | [DynamicIslandWidget.tsx:47](../front-end/src/components/DynamicIslandWidget.tsx#L47), [DynamicIslandWidget.tsx:49](../front-end/src/components/DynamicIslandWidget.tsx#L49), [DynamicIslandWidget.tsx:50](../front-end/src/components/DynamicIslandWidget.tsx#L50) |

## Mode Switch Sequence

The collapsed app-activity left icon arms a long press for **`420ms`**. Once
armed, the current activity enters forced compact mode for a **`320ms`** compact
phase. The display mode changes, a **`70ms`** reopen delay runs, then the target
activity reopens through the normal activity-open transition. These timing values
and their implementation sequence are the native parity contract.

* Constants: [DynamicIslandWidget.tsx:928](../front-end/src/components/DynamicIslandWidget.tsx#L928)
* Arming timer: [DynamicIslandWidget.tsx:1042](../front-end/src/components/DynamicIslandWidget.tsx#L1042)
* Compact -> mode mutation -> delayed activity reopen: [DynamicIslandWidget.tsx:1013](../front-end/src/components/DynamicIslandWidget.tsx#L1013)
* Activity-open duration selection: [DynamicIslandWidget.tsx:985](../front-end/src/components/DynamicIslandWidget.tsx#L985)
