## Current Summary

### Current phase
- Phase 0 baseline capture, Phase 1 shell scaffolding, and Phase 2 native window-system work are complete enough for handoff.
- The current Phase 3 native visual geometry queue is complete under `mac-island/MemoryFlowIsland/UI/`.
- The current Phase 4 shell slice now includes motion-driven shadow transitions, preview content-visibility timing inputs, and interruptible preview-transition bookkeeping on top of the earlier sizing and motion foundation.

### Queue snapshot
- First pending task: `Add Phase 4 preview controls for core motion paths.`
- Requested execution mode for this slice: degraded single-agent `$Auto_dev` execution without sub-agents.
- Recommended next queue theme: expose local preview controls for the core motion paths, then capture shadow-specific evidence for expanded states.

### Runtime / environment notes
- [`init.sh`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/init.sh) remains the runtime entry point when full execution-path tasks require startup.
- `xcodebuild` is unavailable in the current environment because the active developer directory is CommandLineTools only.
- For native-shell compile checks, use `swiftc -module-cache-path /tmp/... -typecheck`.
- The sandbox can block Spring Boot or Vite port binding with occupied-port errors, `SocketException: Operation not permitted`, or `listen EPERM`, so the accepted Phase 3 evidence path is still the Swift render/typecheck harness plus synthetic `ScreenMetrics` matrices.

### Archive note
- Older detailed history lives in [`codex-progress-archive.md`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/codex-progress-archive.md).
- Keep this file small enough for the default startup path: `AGENTS.md` -> `agent-state.md` -> `feature_list.json` -> `codex-progress.md`.

## Recent Key Records

## 2026-04-27 - Phase 4 shadow motion, preview content timing, and interruptible preview-state storage landed

- Routed SwiftUI shell-shadow transitions through the Phase 4 motion path by extending `IslandMotionTokens.swift` and `IslandMotionEngine.swift` with shadow fade tokens plus structured preview content-visibility inputs, then updated `IslandVisualStatePreview.swift` so shadow opacity/radius/offset animate from motion-plan timing rather than the generic shell spring.
- Added `mac-island/MemoryFlowIsland/UI/Motion/IslandPreviewContentVisibility.swift` as the small timing-input model for preview content opacity/blur/delay, and connected it to a transparent placeholder layer in `IslandVisualStatePreview.swift` so Phase 4 can validate content timing without introducing real business content or changing shell-only rendering.
- Added `mac-island/MemoryFlowIsland/UI/Motion/IslandPreviewTransitionState.swift` and wired `IslandWindowController.swift` to store current/target preview states, cancel stale completion work items, clear motion plans after settle, and retarget in-flight preview transitions when a new tap or hover request arrives before the prior animation finishes.
- Hover entry and exit now use the same preview-state request path for compact/hover preview states, which gives Phase 4 one shared interruptible seam instead of separate ad-hoc hover-only state changes.
- Validation: `./init.sh` was attempted for the required full execution path and again stopped immediately because backend port `8080` was already occupied by PID `59013`; repository-wide Swift typecheck passed with `swiftc -module-cache-path /tmp/memoryflow-phase4-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')`; and a focused harness compiled plus ran successfully, confirming shadow-motion tokens drive hover and expanded shadow values, content-visibility hidden defaults remain transparent with zero shell blur, retargeted `activityToExpanded` motion plans keep `isRetargeting == true`, and `IslandPreviewTransitionState` can retarget `compact -> hover -> activity -> expandedMusic` before settling cleanly on the latest target.

## 2026-04-27 - Phase 4 diagnostics, sizing matrix evidence, shadow tokenization, and motion foundation landed

- Extended `IslandWindowSizingDiagnostics` and `IslandWindowSizingResult` so preview validation can surface state, visual scale, horizontal scale, visible size, shadow size, content size, and hit-frame details through one concise debug summary; `IslandWindowController` now gates those logs behind `MEMORYFLOW_ISLAND_SIZING_DIAGNOSTICS=1` instead of printing on every production-path layout.
- Added `mac-island/MemoryFlowIsland/Window/IslandSizingMatrixProbe.swift` and generated `docs/evidence/mac-island-phase4/sizing-matrix.json`, covering compact, activity, expanded music, and expanded app sizing on synthetic notch and flat-top displays with explicit `visibleFrame`, `shadowFrame`, `contentFrame`, and `hitTestFrame` values in every row.
- Moved Phase 4 expanded shadow buffers into `IslandVisualTokens.shadow`, increased the expanded buffer envelope, and corrected `IslandShapeEngine.snapshot(...)` so `visibleFrame` sits above the bottom shadow buffer instead of collapsing the downward inset to zero before it reaches `IslandPanel`.
- Added `mac-island/MemoryFlowIsland/UI/Motion/IslandMotionTokens.swift`, `IslandTransitionKind.swift`, and `IslandMotionEngine.swift` as the first native motion layer; `IslandWindowController` now derives a motion plan before preview-state changes, passes it into `IslandRootView`, and lets the plan decide animated panel timing instead of relying on the old fixed controller duration.
- Validation: `./init.sh` was attempted again for the full execution-path contract and stopped immediately because backend port `8080` was already occupied by PID `59013`; repository-wide Swift typecheck passed with `swiftc -module-cache-path /tmp/memoryflow-phase4-cache -typecheck $(rg --files mac-island/MemoryFlowIsland | rg '\.swift$')`; and a focused Phase 4 harness compiled plus ran successfully, regenerating `docs/evidence/mac-island-phase4/sizing-matrix.json`, confirming diagnostics fields for compact/activity/expanded results, verifying expanded shadow buffers exceed hover buffers while compact/activity remain zero-buffer states, confirming `compactToActivity` and `activityToExpanded` motion plans compile, and validating the synthetic preview sequence `compactCollapsed -> hoverCollapsed -> activityCollapsed -> expandedMusic -> expandedApp`.

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
