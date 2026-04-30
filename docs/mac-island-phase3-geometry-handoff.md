# Phase 3 Geometry Handoff

## Implemented Modules

- `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift` is the token source of truth for compact, activity, expanded, hover, and shadow geometry values.
- `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift` resolves preview-state geometry inputs from `IslandVisualState` and `visualScale`.
- `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` now ports the Windows body, open-stroke, left-cap, right-cap, and ear path math.
- `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeEngine.swift` composes those paths into one preview snapshot with visible-frame and shadow-outset data.
- `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift`, `mac-island/MemoryFlowIsland/UI/IslandRootView.swift`, `mac-island/MemoryFlowIsland/Window/IslandPanel.swift`, and `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` now form the native preview host and geometry-driven sizing path.

## Accepted Preview States

- `compactCollapsed`
- `hoverCollapsed`
- `activityCollapsed`
- `expandedMusic`
- `expandedApp`

Evidence for the accepted preview set lives in [Phase 3 geometry acceptance](./mac-island-phase3-geometry-acceptance.md) and the linked assets under [`docs/evidence/mac-island-phase3/`](./evidence/mac-island-phase3/preview-board.png).

## Open Risks

- The current acceptance evidence covers native SwiftUI render-harness output plus synthetic `ScreenMetrics` matrices for notch and flat-top displays; it is truthful about the current sandbox and does not claim a physical external-display run.
- `xcodebuild` remains unavailable in this environment, so compile validation still relies on `swiftc -module-cache-path /tmp/... -typecheck`.
- `init.sh` still hits occupied-port or sandbox bind failures when it tries to bring up the backend and Vite together, so the Phase 3 signoff path remains native-geometry focused.

## Explicit Phase 4 Inputs

- The source of truth for visible-shell size is now `IslandShapeEngine.snapshot(...).visibleFrame`, not the old placeholder preset dimensions.
- The source of truth for shadow padding is now `IslandShapeEngine.snapshot(...).shadowOutsets`, which `IslandPanel` applies without adding a top shadow gap.
- `TopAttachmentMetrics.visualScale` is now the shared scale input that Phase 4 sizing work should continue using.
- Activity width now has a content-driven input model: content should declare `IslandContentWidthRequirement` (`leadingContentWidth`, `trailingContentWidth`, `horizontalPadding`) and let `IslandShapeMetrics` resolve shell width from content demand, notch/base width, token fallback width, and display maximums.
- `IslandWindowController` already advances preview states and repositions the panel from geometry output, so Phase 4 should extend that sizing path rather than reintroducing fixed placeholder window sizes.

Business data, auth, and Phase 5 state-machine migration remain out of scope for this completed slice.
