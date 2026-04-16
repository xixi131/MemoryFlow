# Expand/Collapse

| Animation Step | Duration | Easing | Trigger | Observed Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Activity segmented collapse (shape + size) | `0.85s` (`ACTIVITY_COLLAPSE_DURATION_SECONDS`) | `easeInOut` with keyframe times `[0, 0.45, 0.55, 1]` | `isActivitySegmentedTransition` becomes true during reminder collapse or force-compact close path | Island collapses in segmented phases (mid-width hold, then final compact width), with synchronized SVG path morphing | `front-end/src/components/DynamicIslandWidget.tsx:47`, `front-end/src/components/DynamicIslandWidget.tsx:49`, `front-end/src/components/DynamicIslandWidget.tsx:1592`, `front-end/src/components/DynamicIslandWidget.tsx:1749`, `front-end/src/components/DynamicIslandWidget.tsx:1938` |
| Activity open into compact activity state (shape + size) | `0.56s` (`ACTIVITY_OPEN_DURATION_SECONDS`) | `easeInOut` | `setForceCompactModeWithTransition(false)` sets `isActivityOpenTransition` | Island animates from base compact shape into activity compact shape (container width/height and squircle paths open together) | `front-end/src/components/DynamicIslandWidget.tsx:50`, `front-end/src/components/DynamicIslandWidget.tsx:985`, `front-end/src/components/DynamicIslandWidget.tsx:995`, `front-end/src/components/DynamicIslandWidget.tsx:1590`, `front-end/src/components/DynamicIslandWidget.tsx:1745`, `front-end/src/components/DynamicIslandWidget.tsx:1936` |
| Collapsed-content defer + fade on close | `delay 0.47s` then `0.38s` fade/blur transition | default Framer timing (`transition` without explicit ease) | Collapsed-content layer is rendered while `!isExpanded`; delay applied only when segmented collapse is active | Text/icons do not immediately pop during collapse; content appears after segmented shell motion settles | `front-end/src/components/DynamicIslandWidget.tsx:48`, `front-end/src/components/DynamicIslandWidget.tsx:1622`, `front-end/src/components/DynamicIslandWidget.tsx:2010` |
| Activity content reveal after reopen | `delay 0.1s` + `0.26s` | `easeOut` | `isActivityOpenTransition` true on music/app activity collapsed content blocks | Activity inner content fades/blurs in shortly after shell expand, avoiding premature content pop-in | `front-end/src/components/DynamicIslandWidget.tsx:51`, `front-end/src/components/DynamicIslandWidget.tsx:52`, `front-end/src/components/DynamicIslandWidget.tsx:2021`, `front-end/src/components/DynamicIslandWidget.tsx:2074` |
| Shadow filter transition during expand/collapse state changes | `260ms` | `ease-out` | `shouldShowShadow` style branch changes while container animates between `expanded` and `collapsed` variants | Drop shadow smoothly appears/disappears instead of hard toggle during state transitions | `front-end/src/components/DynamicIslandWidget.tsx:1730`, `front-end/src/components/DynamicIslandWidget.tsx:1733`, `front-end/src/components/DynamicIslandWidget.tsx:1737` |

# Mode Switch

| Animation Step | Duration | Easing | Trigger | Observed Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Long-press arming before switch sequence | `420ms` (`MODE_SWITCH_LONG_PRESS_MS`) | timer gate (N/A) | Pointer-down on activity left icon while collapsed app activity is visible | Prevents accidental mode flips; only sustained press enters mode-switch animation sequence | `front-end/src/components/DynamicIslandWidget.tsx:928`, `front-end/src/components/DynamicIslandWidget.tsx:1042`, `front-end/src/components/DynamicIslandWidget.tsx:1048` |
| Compact phase before mode mutation | `320ms` (`MODE_SWITCH_COMPACT_PHASE_MS`) | uses close-path easing from collapse animation (`easeInOut` in shell transitions) | `triggerActivityModeSwitch()` starts by forcing compact mode | Current activity view first collapses, then mode enum flips (`review` <-> `todo`) and is synced to Electron main | `front-end/src/components/DynamicIslandWidget.tsx:929`, `front-end/src/components/DynamicIslandWidget.tsx:1013`, `front-end/src/components/DynamicIslandWidget.tsx:1022`, `front-end/src/components/DynamicIslandWidget.tsx:1026`, `front-end/src/components/DynamicIslandWidget.tsx:1006` |
| Reopen delay and activity reopen | `70ms` delay (`MODE_SWITCH_REOPEN_DELAY_MS`) + `0.56s` reopen animation | `easeInOut` for reopen shell motion | After compact phase callback, a delayed `setForceCompactModeWithTransition(false)` runs | Widget reopens into the new app mode activity card after a short pause, keeping switch readable | `front-end/src/components/DynamicIslandWidget.tsx:930`, `front-end/src/components/DynamicIslandWidget.tsx:1030`, `front-end/src/components/DynamicIslandWidget.tsx:1032`, `front-end/src/components/DynamicIslandWidget.tsx:50`, `front-end/src/components/DynamicIslandWidget.tsx:1745` |
| Mode-switch animation lock window | `1240ms` (`320 + 70 + 850`) | timer lock (N/A) | `isModeSwitchAnimating` is set true at sequence start and reset by unlock timer | Input is gated while collapse/switch/reopen sequence runs, avoiding overlapping mode-switch triggers | `front-end/src/components/DynamicIslandWidget.tsx:1020`, `front-end/src/components/DynamicIslandWidget.tsx:1035`, `front-end/src/components/DynamicIslandWidget.tsx:1036` |

# Hover Motion

| Animation Step | Duration | Easing | Trigger | Observed Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Template Row |  |  |  |  |  |

# Reminder-Triggered Motion

| Animation Step | Duration | Easing | Trigger | Observed Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Template Row |  |  |  |  |  |
