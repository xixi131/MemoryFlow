# Phase 4 Motion Frame Sequences

Synthetic motion-plan frame-sequence evidence derived from `IslandMotionEngine`, `IslandMotionTokens`, and the preview-only control routes. This is not a physical-device AppKit capture, GIF, or video.

## Transition Coverage

### `compactToActivity`

- Source: `compactCollapsed`
- Target: `activityCollapsed`
- Transition kind: `compactToActivity`
- Duration: `0.56s`
- Keyframe times: `0.00, 0.20, 0.34, 1.00`
- Content visible delay/duration: `0.10s / 0.26s`
- Shadow target opacity/radius/offsetY: `0.00 / 0.00 / 0.00`

### `activityToExpanded`

- Source: `activityCollapsed`
- Target: `expandedMusic`
- Transition kind: `activityToExpanded`
- Duration: `0.56s`
- Keyframe times: `0.00, 0.20, 0.34, 1.00`
- Content visible delay/duration: `0.10s / 0.26s`
- Shadow target opacity/radius/offsetY: `0.22 / 30.22 / 8.89`

### `expandedToCompact`

- Source: `expandedMusic`
- Target: `compactCollapsed`
- Transition kind: `expandedToCompact`
- Duration: `0.85s`
- Keyframe times: `0.00, 0.45, 0.55, 1.00`
- Content visible delay/duration: `0.00s / 0.15s`
- Shadow target opacity/radius/offsetY: `0.00 / 0.00 / 0.00`

### `hoverEnter`

- Source: `compactCollapsed`
- Target: `hoverCollapsed`
- Transition kind: `hoverEnter`
- Duration: `0.26s`
- Keyframe times: `0.00, 1.00`
- Content visible delay/duration: `0.00s / 0.12s`
- Shadow target opacity/radius/offsetY: `0.28 / 10.67 / 8.89`

### `hoverLeave`

- Source: `hoverCollapsed`
- Target: `compactCollapsed`
- Transition kind: `hoverLeave`
- Duration: `0.26s`
- Keyframe times: `0.00, 1.00`
- Content visible delay/duration: `0.00s / 0.12s`
- Shadow target opacity/radius/offsetY: `0.00 / 0.00 / 0.00`

## Interrupt Sequence

Synthetic preview retarget sequence derived from the Phase 4 preview-motion control routes and motion-plan retarget flag.

- `t=0.00s` `hoverEnter` routes `compactCollapsed` -> `hoverCollapsed` with `hoverEnter` and `isRetargeting=false`
- `t=0.08s` `compactToActivity` routes `compactCollapsed` -> `activityCollapsed` with `compactToActivity` and `isRetargeting=true`
- `t=0.18s` `activityToExpanded` routes `activityCollapsed` -> `expandedMusic` with `activityToExpanded` and `isRetargeting=true`

Final target state: `expandedMusic`
