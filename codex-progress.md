## Current Summary

### Current phase
- Phase 0 baseline/spec capture is complete enough for implementation handoff.
- Phase 1 native macOS shell scaffolding queue is complete, including the acceptance-gate checklist for the shell entry slice.
- Phase 2 native macOS window-system work is now in progress, with notch-safe centering on notch displays in place ahead of the non-notch fallback path.

### Queue snapshot
- The completed task is `Center the island shell against the notch-safe top region on notch displays.`
- The next pending task is `Place the island shell in a stable top-center fallback on non-notch displays.`

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
