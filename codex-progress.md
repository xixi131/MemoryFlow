## Current Summary

### Current phase
- Phase 0 baseline/spec capture is complete enough for implementation handoff.
- Phase 1 native macOS shell scaffolding queue is complete, including the acceptance-gate checklist for the shell entry slice.
- Phase 2 native macOS window-system work is now in progress, with persisted display targeting in place ahead of explicit re-anchor callbacks.

### Queue snapshot
- The completed task is `Return the island to click-through mode after hover exit.`
- The current queue has no remaining pending task.

### Runtime / environment notes
- [`init.sh`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/init.sh) is the repository runtime entry point.
- Default validation path is web unless a task explicitly needs Electron or native-shell verification.
- `xcodebuild` is unavailable in the current environment because the active developer directory is CommandLineTools only.
- For native-shell tasks, `swiftc -module-cache-path /tmp/... -typecheck` is the practical compile-level validation path in this environment.
- `init.sh` can start the backend on an alternate port, but the sandbox currently blocks Vite from binding `0.0.0.0:3000` with `EPERM`.
- Treat git commit or post-processing failures as workflow blockers, not as evidence that implementation work failed.

### Archive note
- Older detailed logs live in [`codex-progress-archive.md`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/codex-progress-archive.md).
- Keep this file to summary plus recent key records only.

## Recent Key Records

## 2026-04-25 - Hover exit now restores click-through without leaving the shell stuck interactive

- Updated `mac-island/MemoryFlowIsland/Window/IslandHoverMonitor.swift` so the monitor reports both hover-entry and hover-exit edge transitions instead of only start events.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` so hover monitoring remains active while the panel is interactive and hover-exit routes through a controller-owned recovery gate that restores click-through only after the pointer actually leaves the island hotspot.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/mf-task44-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')`, and the worker-reported hover-monitor harness printed `hover-monitor-cycles-ok` for repeated enter/exit cycles.

## 2026-04-25 - Hover entry now transitions the shell into interactive mode

- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` so hover-start routes through a dedicated controller-owned `activateInteractiveHoverMode()` path instead of keeping the activation stubbed at the callback boundary.
- Updated `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` with a small in-place `activateInteractiveHoverMode()` helper that disables click-through without recreating the panel, and adjusted `show()` so it only orders the panel front when needed instead of reopening it during hover entry.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/mf-task43-module-cache -typecheck $(find mac-island/MemoryFlowIsland -name '*.swift' -print)`, confirming the hover-entry activation path compiles cleanly across the full native source set.

## 2026-04-25 - Hover hotspot monitoring now works while the shell stays click-through

- Added `mac-island/MemoryFlowIsland/Window/IslandHoverMonitor.swift` as a small Window-layer monitor that polls `NSEvent.mouseLocation` against a hotspot rect so pointer entry can be detected even while the panel is not accepting mouse events.
- Updated `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` with a visible-shell-based hover hotspot frame, and updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` so hover monitoring starts on `show()`, stops on `hide()` and teardown, and routes hover-start callbacks into the controller.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')`, confirming the hover-monitor lifecycle compiles cleanly across the full native shell source set.

## 2026-04-25 - Phase 2 window-system handoff note added for the next native shell slice

- Added `docs/mac-island-phase2-window-handoff.md` to name the active Phase 2 Window-layer files and the expected acceptance path for notch placement, non-notch fallback, display/recovery behavior, click-through, and hover-ready shell work.
- Captured explicit non-goals for this slice: no review/todo data migration, no auth flow, no music takeover, and no Phase 6 gesture polish.
- Validation: lightweight doc checks confirmed the note points only to Phase 2 shell files and references, and that later-phase topics appear only as non-goals.

## 2026-04-25 - Phase 2 acceptance checklist now covers shell recovery and hover behaviors

- Updated `docs/mac-island-migration-checklist.md` with a new `Phase 2 Window Positioning and Recovery` section containing prepared checklist items for notch placement, non-notch fallback, display attach/detach recovery, resolution-change recovery, wake recovery, click-through toggling, and hover activation.
- Kept each item scoped to one observable window-shell behavior with a concrete pass condition and evidence links into the migration plan or native Window-layer files.
- Validation: lightweight checklist review confirmed all seven requested behaviors are present and remain scoped to Phase 2 shell work only.

## 2026-04-25 - Native click-through toggle landed for the island panel

- Updated `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` with an in-place click-through surface that exposes current `ignoresMouseEvents` state and toggles it without recreating the panel.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` with `isPanelClickThroughEnabled` and `setPanelClickThroughEnabled(_:)` so later hover-monitor work can coordinate click-through entirely inside the native shell layer.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swiftcheck.9l9h9X -typecheck` over the full `mac-island/MemoryFlowIsland` Swift source set, and the worker-reported runtime toggle check printed `click-through-toggle-ok` while the panel stayed visible.

## 2026-04-25 - Expanded shell shadow now has native panel breathing room

- Updated `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` to split visible shell size from the outer panel frame, adding a native-shell `shellShadowMargin` and a `panelFrame(forVisibleShellFrame:)` helper so expanded shells reserve transparent space for rounded edges and shadow.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to keep placement math centered on the visible shell while applying the larger padded panel frame, and updated `mac-island/MemoryFlowIsland/UI/IslandRootView.swift` to align its inset with the shared margin.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')`; a follow-up search confirmed there are no remaining references to the old `frameSize` accessor in `mac-island/MemoryFlowIsland`.

## 2026-04-25 - Placeholder shell size presets now switch through the controller path

- Extended `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` with explicit `IslandShellSizePreset` placeholder sizes for compact (`360x96`) and expanded (`460x320`) shell frames.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to expose `setShellSizePreset(_:)` and keep both preset switching and display-change recovery on the existing placement path, so frame changes stay centered without introducing Phase 3 business state.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')`; the worker also reported an ad hoc controller check where compact-to-expanded preset switching kept `midXDelta=0.0`.

## 2026-04-25 - Wake recovery now reuses the display-change re-anchor path

- Updated `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` so `NSWorkspace.didWakeNotification` emits through the same typed `ChangeSignal` channel as screen-parameter changes, with start/stop observation now managing both notification registrations symmetrically.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to stop observers on app termination and controller teardown, and to route wake recovery through the existing `repositionToTopCenter(reapplyLatestLayoutResult: true)` path instead of introducing a second re-anchor flow.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g '*.swift')`, confirming the wake-notification observer path compiles cleanly across the full native source set.

## 2026-04-25 - Island panel now stays floating without taking app focus

- Updated `mac-island/MemoryFlowIsland/Window/IslandPanel.swift` to keep the native shell nonactivating while adding `fullSizeContentView`, all-spaces/fullscreen-safe collection behavior, and shell flags such as `ignoresCycle`, `isExcludedFromWindowsMenu`, and disabled panel movement.
- Left the controller show path untouched so the island still appears via `orderFrontRegardless()` instead of a key-window or app-activation flow, keeping the shell compatible with later hover work.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/Window/IslandPanel.swift`, and a code-path check confirmed `IslandWindowController.show()` does not call `makeKeyAndOrderFront` or `NSApp.activate`.

## 2026-04-25 - Display-change re-anchor now reuses one native reposition path

- Updated `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` so screen-parameter notifications emit a typed change signal instead of a bare callback, giving the native shell one explicit display-change event path.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to route that signal through a single handler and reapply the latest layout size when screen arrangement or resolution changes trigger a fresh placement.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland -g'*.swift')`, and path-shape verification via `rg -n "repositionToTopCenter|handleDisplayChange|screenParametersChanged"` confirmed display-change events land in one reposition entry point.

## 2026-04-24 - Display-target persistence landed for screen-parameter changes

- Updated `mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` so the Window/display layer resolves a preferred screen by the last applied `displayIdentity` when that screen still exists, and only falls back to the current screen when the previous target disappears.
- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to pass the last applied display identity back through the resolver during repositioning instead of always following the current main screen.
- Validation: native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` across the full `mac-island/MemoryFlowIsland` Swift source set plus a compiled fixture harness that simulated both a screen reorder and a display detach, confirming the preferred target stayed on display `2` when present and fell back to display `1` when it disappeared.

## 2026-04-24 - Island show path now applies the placement result on the target display

- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` so `show()` resolves `ScreenMetrics`, applies `NotchLayoutEngine.placementResult`, and stores the last applied display identity and frame for later re-anchor work.
- Added an injectable screen-metrics resolver to the controller so native placement flow can be smoke-tested without changing the controller’s production entry path.
- Validation: `MEMORYFLOW_BACKEND_PORT=18080 ./init.sh` ran successfully outside the sandbox, with the frontend falling forward to port `3001`; native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` across the full `mac-island/MemoryFlowIsland` Swift source set plus a compiled AppKit harness that called `show()` twice and verified the controller reused the same placement path without duplicating content setup.

## 2026-04-24 - Flat-top fallback placement landed for the native island shell

- Updated `mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift` so flat-top displays use a dedicated visible-area fallback calculation instead of sharing the notch path.
- Added a shared `IslandPlacementResult` path in the layout engine so both notch-bearing and flat-top displays now resolve through the same placement result type.
- Validation: `MEMORYFLOW_BACKEND_PORT=18080 ./init.sh` was exercised and again stopped at the known sandbox-only Vite bind failure (`EPERM` on `0.0.0.0:3000`); native validation passed via `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` across the full `mac-island/MemoryFlowIsland` Swift source set plus a compiled flat-top fixture harness that verified the resulting frame stays fully inside `visibleFrame`.

## 2026-04-24 - Notch-safe top-region centering landed for the native island shell

- Updated `mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift` so notch-bearing displays derive the island `x` origin from a computed top safe region instead of the raw `visibleFrame` midpoint.
- Kept the Phase 2 layout margins explicit in the engine with separate `phase2NotchTopMargin` and `phase2FlatTopMargin` constants while leaving the flat-top fallback path scoped for the next queue item.
- Validation: `init.sh` was exercised but stopped because backend port `8080` was already occupied in the current environment, so native validation used the documented compile path: `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` across the full `mac-island/MemoryFlowIsland` Swift source set plus a compiled fixture harness that asserted a notch-bearing `ScreenMetrics` sample returns the centered frame derived from the top safe region.

## 2026-04-23 - Display top-edge classification landed for Phase 2 notch routing

- Added `mac-island/MemoryFlowIsland/Window/DisplayTopEdgeClassifier.swift` with a reusable `notchBearing` / `flatTop` classification for `ScreenMetrics`.
- Extended `ScreenMetrics` with a direct initializer for compile-time fixtures, and updated `NotchLayoutEngine` to route `ScreenMetrics` placement through the new classifier instead of leaving that decision in `IslandWindowController`.
- Added `DisplayTopEdgeClassifier.swift` to `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` so the classifier is part of the native app target.
- Validation: `MEMORYFLOW_BACKEND_PORT=18080 ./init.sh` was exercised and again hit the known sandbox-only Vite bind failure (`EPERM` on `0.0.0.0:3000`) after backend startup; native validation passed via `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` and `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` on the full native Swift source set plus a fixture harness that compiled both notch and flat-top `ScreenMetrics` through the placement path.

## 2026-04-23 - Window-layer screen metrics model landed for Phase 2 positioning

- Added `mac-island/MemoryFlowIsland/Window/ScreenMetrics.swift` with frame, visible frame, safe-area insets, backing scale, and stable display identity derived from `NSScreen`.
- Updated `DisplayObserver` to return `ScreenMetrics` for a window-aware current screen lookup, and updated `IslandWindowController` plus `NotchLayoutEngine` to consume the model without controller-side `NSScreen` parsing.
- Added `ScreenMetrics.swift` to `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` so the model is part of the native app target.
- Validation: `init.sh` was exercised, recovered with `MEMORYFLOW_BACKEND_PORT=18080`, and then hit an environment-only Vite bind failure (`EPERM` on `0.0.0.0:3000`); native validation passed via `plutil -lint mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` and `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` across the app/window/menu/preferences/UI Swift sources including the new metrics model.

## 2026-04-23 - Phase 1 acceptance-gate checklist items added for native shell readiness

- Appended a `Phase 1 Shell Readiness` section to `docs/mac-island-migration-checklist.md`.
- Added prepared checklist items for standalone app launch wiring, menu bar icon/menu shell presence, and basic top island window show-path readiness.
- Validation: planning fast-path checks confirmed the checklist was added to the existing migration tracking doc, each item includes an explicit pass condition scoped to Phase 1 shell goals, and the evidence references point to existing docs/code paths under `mac-island/`.

## 2026-04-23 - Phase 1 scaffold handoff note added for native shell modules

- Added `docs/mac-island-phase1-scaffold-handoff.md` to describe the generated `App`, `Window`, `MenuBar`, `Preferences`, `UI`, and `Resources` modules under `mac-island/`.
- Documented explicit Phase 1 non-goals: no `review` or `todo` feature migration, no auth or API integration, and no music provider migration in the native shell yet.
- Validation: docs fast-path checks confirmed the note exists under `docs/`, all referenced module paths match the current project skeleton, and the note stays scoped to shell modules that already exist in `mac-island/`.

## 2026-04-23 - Native app resources and bundle metadata placeholders landed

- Added `Resources/Info.plist` and placeholder `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` so the macOS shell now has explicit bundle metadata and a resource catalog root.
- Updated `mac-island/MemoryFlowIsland.xcodeproj/project.pbxproj` to register `Assets.xcassets` in the target resources phase, disable autogenerated plist output, and point both build configurations at `MemoryFlowIsland/Resources/Info.plist`.
- Validation: `init.sh` startup path ran successfully, `project.pbxproj` and `Info.plist` passed `plutil -lint`, asset catalog JSON files passed `jq empty`, full `mac-island/MemoryFlowIsland` Swift sources typechecked, and static project checks confirmed `INFOPLIST_FILE`, `ASSETCATALOG_COMPILER_APPICON_NAME`, bundle identifier, and version settings all reference the new resource files.

## 2026-04-23 - Preferences window skeleton wired into the native menu bar

- Added `Preferences/PreferencesWindowController.swift` and `Preferences/PreferencesView.swift` to provide a reusable native preferences window skeleton.
- Updated `SceneCoordinator` and `StatusBarController` so the `Preferences` menu action opens the shared preferences controller instance instead of the old stub handler.
- Validation: `init.sh` was exercised successfully outside the sandbox, `project.pbxproj` passed `plutil -lint`, full `mac-island/MemoryFlowIsland` Swift sources typechecked with local module cache overrides, and a compiled smoke executable verified repeated Preferences actions reused the injected controller path without duplicate lifecycle issues.

## 2026-04-16 - Phase 1 gate confirmed and native shell queue opened

- Added the Phase 1 entry gate note to `docs/mac-island-phase0-baseline.md` after cross-checking Phase 0 checklist coverage.
- Result: the queue legitimately moved from Windows-behavior capture into native shell implementation tasks.
- Validation: checklist section references and gate wording were verified in docs; task 18 is marked complete in `feature_list.json`.

## 2026-04-16 - Native app container and bootstrap scaffold landed

- Created `mac-island/MemoryFlowIsland.xcodeproj` and the base module folders `App/`, `Window/`, `MenuBar/`, `Preferences/`, `UI/`, and `Resources/`.
- Added bootstrap entry files `MemoryFlowIslandApp.swift`, `AppDelegate.swift`, and `SceneCoordinator.swift` so the native shell has a launch path and module wiring point.
- Validation: `init.sh` startup path was exercised, `project.pbxproj` passed `plutil -lint`, and targeted `swiftc -typecheck` checks passed.

## 2026-04-16 - Window shell and geometry placeholders landed

- Added `IslandPanel.swift` and `IslandWindowController.swift` for a transparent floating shell with `show()` / `hide()` entry points.
- Added `NotchLayoutEngine.swift` and `DisplayObserver.swift` as geometry/display placeholders and wired them into the window controller.
- Validation: pbxproj membership and symbol references were checked, and the assembled Swift set typechecked successfully.

## 2026-04-16 - Placeholder UI and menu bar shell reached preferences handoff

- Added `UI/IslandRootView.swift` and hosted it through `NSHostingView(rootView: IslandRootView())` inside `IslandWindowController`.
- Added `MenuBar/StatusBarController.swift` and `MenuBar/StatusMenuBuilder.swift` with `Show/Hide Island`, `Preferences`, and `Quit` actions.
- Validation: pbxproj wiring passed lint, full Swift sources typechecked, and a smoke executable exercised the menu actions without crash.
- Follow-up: the next implementation step is to replace the stub `Preferences` action with a real preferences window controller lifecycle.
