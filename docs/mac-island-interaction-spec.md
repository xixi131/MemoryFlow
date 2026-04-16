# Hover Activation

| Interaction | Trigger Threshold | Debounce | Recovery Behavior | Evidence |
| --- | --- | --- | --- | --- |
| Pointer enters the island hit area while the widget is collapsed | No numeric threshold; hover is driven by `onMouseEnter` and the `:hover` check used by gesture finalization | None observed in code | `setIsHovered(true)` on enter; `setIsHovered(false)` on leave or when expanding; if the widget is not expanded and no pointer gesture is active, leave restores click-through | [DynamicIslandWidget.tsx](../front-end/src/components/DynamicIslandWidget.tsx#L1065-L1069), [DynamicIslandWidget.tsx](../front-end/src/components/DynamicIslandWidget.tsx#L1896-L1907) |

# Click-Through Toggle

| Interaction | Trigger Threshold | Debounce | Recovery Behavior | Evidence |
| --- | --- | --- | --- | --- |
| Renderer requests `set-ignore-mouse-events` on hover enter/leave and collapse recovery | Guarded by `isExpanded`, active pointer capture, and gesture-tracking refs; click-through is only restored when the widget is not expanded | None observed in code | `mouseenter` disables click-through, `mouseleave` restores it only when not expanded, and `collapseExpanded()` also re-enables click-through after collapsing | [DynamicIslandWidget.tsx](../front-end/src/components/DynamicIslandWidget.tsx#L617-L639), [DynamicIslandWidget.tsx](../front-end/src/components/DynamicIslandWidget.tsx#L1900-L1915), [main.cjs](../front-end/electron/main.cjs#L1329-L1334) |

# Pointer Gestures

| Interaction | Trigger Threshold | Debounce | Recovery Behavior | Evidence |
| --- | --- | --- | --- | --- |
| Template Row |  |  |  |  |

# Trackpad Gestures

| Interaction | Trigger Threshold | Debounce | Recovery Behavior | Evidence |
| --- | --- | --- | --- | --- |
| Template Row |  |  |  |  |
