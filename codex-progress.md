## Current Summary

### Current phase
- Phase 0 baseline capture, Phase 1 shell scaffolding, and Phase 2 native window-system work are complete enough for handoff.
- The current Phase 3 native visual geometry queue is complete under `mac-island/MemoryFlowIsland/UI/`.
- The first Phase 4 sizing slice is now in place: `IslandWindowSizingEngine` owns snapshot resolution, content-aware width constraints, shadow-aware display clamping, and controller-facing sizing results.

### Queue snapshot
- First pending task: `Add sizing diagnostics for Phase 4 preview states.`
- Requested execution mode for this slice: degraded single-agent `$Auto_dev` execution without sub-agents.
- Recommended next queue theme: expose preview-safe sizing diagnostics, then extend the synthetic harness into a Phase 4 sizing matrix.

### Runtime / environment notes
- [`init.sh`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/init.sh) remains the runtime entry point when full execution-path tasks require startup.
- `xcodebuild` is unavailable in the current environment because the active developer directory is CommandLineTools only.
- For native-shell compile checks, use `swiftc -module-cache-path /tmp/... -typecheck`.
- The sandbox can block Spring Boot or Vite port binding with occupied-port errors, `SocketException: Operation not permitted`, or `listen EPERM`, so the accepted Phase 3 evidence path is still the Swift render/typecheck harness plus synthetic `ScreenMetrics` matrices.

### Archive note
- Older detailed history lives in [`codex-progress-archive.md`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/codex-progress-archive.md).
- Keep this file small enough for the default startup path: `AGENTS.md` -> `agent-state.md` -> `feature_list.json` -> `codex-progress.md`.

## Recent Key Records

## 2026-04-27 - Phase 4 sizing engine, clamping path, and controller wiring landed

- Added `mac-island/MemoryFlowIsland/Window/IslandWindowSizingEngine.swift` as the Phase 4 sizing boundary that accepts `IslandVisualState`, `TopAttachmentMetrics`, and `IslandWidthConstraints`, resolves `IslandShapeEngine.snapshot(...)`, and returns screen-space `visibleFrame`, `shadowFrame`, `contentFrame`, and `hitTestFrame` results without mutating window state.
- Extended `IslandWindowSizingResult.swift` with a derived `shadowOutsets` helper so `IslandPanel` can consume Phase 4 sizing output directly, and added both sizing files into `mac-island/MemoryFlowIsland.xcodeproj` so Xcode builds do not silently miss the new window-layer source set.
- Reworked `IslandWindowController.swift` so preview sizing now flows through `IslandWindowSizingEngine`, root-view width constraints mirror the resolved sizing inputs, and panel placement comes from the sizing result instead of the old inline snapshot-plus-placement assembly.
- Validation: `./init.sh` was attempted for the full execution path and stopped immediately because backend port `8080` was already occupied by PID `59013`; `swiftc -module-cache-path /tmp/memoryflow-phase4-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')` passed; and a focused native harness compiled plus ran successfully, printing non-empty compact/activity/expanded sizing and confirming a synthetic `320`-point display keeps the expanded shadow frame within bounds while preserving center anchoring.

## 2026-04-27 - Phase 4 window sizing result model landed

- Added `mac-island/MemoryFlowIsland/Window/IslandWindowSizingResult.swift` with `IslandWindowSizingResult` and `IslandWindowSizingDiagnostics` to hold `visibleFrame`, `shadowFrame`, `contentFrame`, `hitTestFrame`, and sizing-input diagnostics in the native window layer.
- Kept the new model independent from SwiftUI view code and business-data providers by limiting it to CoreGraphics plus existing Phase 4 sizing inputs (`IslandVisualState`, `IslandContentWidthRequirement`).
- Attempted the required full-path runtime startup with `./init.sh`, which stopped immediately because backend port `8080` was already occupied by PID `59013`, matching the known environment caveat for this repository.
- Validation: full native Swift source-set typecheck passed with `swiftc -module-cache-path /tmp/memoryflow-phase4-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')`.

## 2026-04-27 - Phase 4 acceptance rows now define motion quality and interruptibility

- Filled the `Motion Profiles` section in `docs/mac-island-phase4-sizing-motion-acceptance.md` with prepared rows for compact-to-activity, activity-to-expanded, expanded-to-collapsed, hover enter, hover leave, spring-like elasticity, and content fade or blur timing.
- Filled the `Interruptible Transitions` section with a prepared row that requires retargeting from the live presentation state rather than restarting from stale values.
- Mapped the motion rows to the planned native modules such as `IslandMotionEngine`, `IslandWindowSizingEngine`, `IslandWindowController`, `IslandHoverMonitor`, and content-visibility hooks.
- Validation: confirmed every requested motion scenario is present and that the new motion plus interruptibility rows require preview evidence instead of code inspection alone.

## 2026-04-27 - Phase 4 acceptance rows now define content-driven width and shadow buffering

- Filled the `Content-Driven Width` section in `docs/mac-island-phase4-sizing-motion-acceptance.md` with prepared rows for content-demand sizing, padding-aware resolution, notch/base-width floor behavior, display-maximum clamping, and fixed-width fallback rules.
- Filled the `Shadow Buffering` section with prepared rows for expanded bottom buffering, expanded side buffering, and state-specific shadow-buffer isolation.
- Linked the new rows back to the Phase 4 plan and mapped them to the current or planned native sizing modules, including `IslandContentWidthRequirement`, `IslandWidthConstraints`, `IslandShapeMetrics`, `IslandShapeEngine`, `IslandWindowSizingEngine`, and `IslandPanel`.
- Validation: confirmed the new width rows include an explicit rejection of fixed activity width as the primary Phase 4 strategy and that all requested shadow-buffer scenarios are present.

## 2026-04-27 - Phase 4 sizing acceptance rows now define outputs and top attachment behavior

- Filled the `Sizing Outputs` section in `docs/mac-island-phase4-sizing-motion-acceptance.md` with explicit prepared rows for `visibleFrame`, `shadowFrame`, `contentFrame`, and `hitTestFrame`.
- Added a `Top Attachment And Display Behavior` subsection with prepared acceptance rows for notch displays, flat-top displays, external displays, and resolution-change recovery.
- Linked every new sizing row back to the Phase 4 section of `灵动岛迁移方案.md` and mapped each row to the expected native modules such as `IslandWindowSizingEngine`, `NotchLayoutEngine`, `ScreenMetrics`, `IslandWindowController`, and related shell helpers.
- Validation: confirmed all eight new scenarios are present in the acceptance doc and that each one carries a Phase 4 plan link.

## 2026-04-27 - Phase 4 sizing and motion acceptance shell created

- Created `docs/mac-island-phase4-sizing-motion-acceptance.md` with the required Phase 4 sections: Sizing Outputs, Content-Driven Width, Shadow Buffering, Motion Profiles, Interruptible Transitions, Preview Evidence, and Non-Goals.
- Added an explicit scope note that Phase 4 is limited to native sizing and motion infrastructure and excludes real data providers plus production music integration.
- Seeded the acceptance doc with section-local placeholder tables so the next Phase 4 doc tasks can add sizing, width, shadow, and motion rows without restructuring the document.
- Validation: confirmed the document exists at the repository path, all level-2 headings are unique, and the file opens cleanly from the repository root.

## 2026-04-27 - Phase 4+ plan retargeted toward Alcove/iPhone-like motion quality

- Updated `灵动岛迁移方案.md` so Phase 4 is no longer only window sizing; it now covers sizing, content-driven width, shadow buffering, and a dedicated motion infrastructure for shell frame/path/shadow/content choreography.
- Moved interaction-intent and mock animation concerns forward into Phase 5 so hover, tap, swipe, long-press, gesture locks, and interruptible transitions are validated before real content and provider work.
- Phase 6 now requires content modules to declare width requirements and animation entry/exit behavior instead of directly changing shell size.
- Phase 8 now treats `ACTIVITY_COLLAPSED_WIDTH` as a fallback token only; music activity width must derive from symmetric content demand, padding, notch/base width, and display maximums.
- Phase 9 is now a real-device calibration and performance QA phase, with acceptance tied to native-looking, Alcove-like, iPhone Dynamic Island style elastic motion rather than basic click/swipe functionality.

## 2026-04-26 - Activity shell width now has a content-driven sizing input

- Added `IslandContentWidthRequirement` and `IslandWidthConstraints` in `mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift` so activity shell width can grow from content demand plus horizontal padding instead of relying only on fixed preview token width.
- `IslandShapeMetrics` now resolves body width from the maximum of token fallback width and `baseBodyWidth + leadingContentWidth + trailingContentWidth + horizontalPadding * 2`, while still clamping against the visible display width after liquid ear reach is considered.
- `IslandVisualState.previewContentWidthRequirement` currently supplies a preview-only symmetric activity stand-in (`leadingContentWidth: 36`, `trailingContentWidth: 36`, `horizontalPadding: 18`), matching the current music-style assumption that left cover and right waveform/action affordance have the same visual size; future music, reminder, and todo migration should replace this with measured or declared real content requirements.
- `IslandWindowController` remains window-focused: it derives screen/notch width constraints and passes them into `IslandShapeEngine.snapshot(...)`, without knowing activity content internals.
- Validation: full native Swift source-set typecheck passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')`.

## 2026-04-26 - Phase 3 native geometry preview host, sizing path, and evidence set were completed

- Implemented `IslandShapeEngine.swift` as the shared composition layer for body, open-stroke, cap, and ear paths, and connected it to `IslandVisualStatePreview.swift`, `IslandRootView.swift`, `IslandPanel.swift`, `IslandWindowController.swift`, and `NotchLayoutEngine.swift` so the native shell now renders all five Phase 3 preview states from geometry output rather than the old black rectangle or placeholder size preset.
- Added the native preview evidence set under `docs/evidence/mac-island-phase3/`, including the five PNG captures, `preview-board.png`, `native-path-samples.json`, `js-path-samples.json`, `path-parity-report.json`, `pixel-checks.json`, and `display-scaling-matrix.json`.
- Updated `docs/mac-island-phase3-geometry-acceptance.md`, `docs/mac-island-migration-checklist.md`, and the new `docs/mac-island-phase3-geometry-handoff.md` so the completed Phase 3 slice is source-linked, evidence-backed, and ready to hand off into Phase 4 sizing work.
- Validation: `swiftc -module-cache-path /tmp/memoryflow-phase3-cache -typecheck` passed for the native target source set; offscreen SwiftUI render harnesses generated the five preview PNGs and the preview board; JS-vs-native path sampling produced `overallPass: true` in `path-parity-report.json`; synthetic notch and flat-top `ScreenMetrics` runs produced the scaling matrix; `./init.sh` first failed because backend port `8080` was already occupied and `MEMORYFLOW_BACKEND_PORT=38081 ./init.sh` later hit sandbox bind failures (`SocketException: Operation not permitted`, `listen EPERM`), so runtime acceptance remained on the native geometry harness path.

## 2026-04-26 - Native path factory now mirrors the Windows ear connector for both shell sides

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `earPath(isLeft:tension:blendHeight:)` port plus dedicated `leftEarPath` and `rightEarPath` helpers that resolve from `IslandShapeMetrics`.
- Preserved the Windows liquid-connection math, including the fixed `40`-point ear width, the mirrored `4`-point tip extension, and the explicit `1px` body overlap so the connector does not detach from the body seam on either side.
- Validation: `./init.sh` was attempted for the full execution path and stopped because backend port `8080` was already in use by PID `59013`; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -o /tmp/island_ear_probe mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/main.swift` then printed validated bounds for `compactCollapsed`, `activityCollapsed`, `expandedMusic`, and `expandedApp` after checking mirrored ear spans and overlap sample points on both sides.

## 2026-04-26 - Native path factory now mirrors the Windows right cap for compact and expanded shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `rightCapPath(height:radius:smoothness:)` port plus a metrics overload that resolves height, radius, and smoothness from `IslandShapeMetrics`, matching the left-cap metrics contract.
- Kept the Windows fixed `60`-point cap width and mirrored the existing superellipse corner sampling on the lower-right edge so the compact and expanded right profile stays symmetric with the current native left-cap and body-path work unless future source parity requires a divergence.
- Validation: `./init.sh` first failed because backend port `8080` was already in use by PID `59013`; `MEMORYFLOW_BACKEND_PORT=38080 ./init.sh` then reached Spring Boot and Vite startup before sandbox port-binding failures (`SocketException: Operation not permitted` and `listen EPERM`) stopped the runtime path; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused native harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/memoryflow_right_cap_validation_main.swift -o /tmp/memoryflow_right_cap_validation` then printed validation lines for `compactCollapsed`, `expandedMusic`, and `expandedApp` after checking the right-cap seam probes and translated cap coverage stayed aligned with the body path.

## 2026-04-26 - Native path factory now mirrors the Windows left cap for compact and expanded shells

- Implemented `mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` with a CGPath-based `leftCapPath(height:radius:smoothness:)` port plus a metrics overload that resolves height, radius, and smoothness from `IslandShapeMetrics`.
- Kept the Windows fixed `60`-point cap width and reused the same superellipse sampling used by the native body path so the left edge profile stays aligned with the compact, activity, and expanded token sets instead of baking in preview-only literals.
- Validation: `./init.sh` was attempted to satisfy the full execution-path contract but stopped immediately because backend port `8080` was already in use by PID `59013`; `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift` passed; and a focused native harness compiled with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache mac-island/MemoryFlowIsland/UI/Visual/IslandVisualTokens.swift mac-island/MemoryFlowIsland/UI/Visual/IslandVisualState.swift mac-island/MemoryFlowIsland/UI/Visual/IslandShapeMetrics.swift mac-island/MemoryFlowIsland/UI/Visual/IslandPathFactory.swift /tmp/memoryflow_left_cap_validation.swift -o /tmp/memoryflow_left_cap_validation` then printed `compactCollapsed: ok`, `activityCollapsed: ok`, `expandedMusic: ok`, and `expandedApp: ok` after checking the cap edge and body join stayed seam-free across compact and expanded shells.

## 2026-04-26 - Main-log rollover for the Phase 3 path-factory slice

- Reason for rollover:
  - `codex-progress.md` exceeded the default startup threshold while the default startup path only needs the current Phase 3 queue state plus the most recent path-factory records.
  - The active first pending task remains `Compose a single shape engine that returns every Phase 3 shell path from shared metrics.`
- Detailed records moved into `codex-progress-archive.md`:
  - 2026-04-26 - Native path factory now mirrors the Windows open stroke for stroke-allowed shells.
  - 2026-04-26 - Native path factory now mirrors the Windows squircle body path for compact and expanded shells.
  - 2026-04-25 - Shared shape metrics now resolve preview states into concrete geometry inputs.
  - 2026-04-25 - Preview-only native visual states were added for the five Phase 3 shells.
  - 2026-04-25 - Phase 3 geometry values now have one shared Swift token source.
  - 2026-04-25 - Phase 3 visual-geometry scaffolding landed under UI/Visual.
  - 2026-04-25 - Phase 3 checklist gates were added to the migration checklist.
  - 2026-04-25 - Phase 3 acceptance matrix now names the five preview shells and explicit non-goals.
  - 2026-04-25 - Phase 3 geometry acceptance document shell created.
  - 2026-04-25 - Path-function sources and seam constraints were mapped for the native path factory.
  - 2026-04-25 - Expanded, hover, and shadow geometry tokens were mapped for the Phase 3 native engine.
  - 2026-04-25 - Compact and activity shell token values were mapped for Phase 3 native previews.
  - 2026-04-25 - Phase 3 visual token map shell created for the native geometry migration.
  - 2026-04-25 - Hover exit now restores click-through without leaving the shell stuck interactive.
  - 2026-04-25 - Hover entry now transitions the shell into interactive mode.
  - 2026-04-25 - Hover hotspot monitoring now works while the shell stays click-through.
  - 2026-04-25 - Phase 2 window-system handoff note added for the next native shell slice.
  - 2026-04-25 - Phase 2 acceptance checklist now covers shell recovery and hover behaviors.
- Archive note:
  - Keep the three newest path-factory records in the main log because they are the closest setup context for the next `IslandShapeEngine` and preview-host tasks.
