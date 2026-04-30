## Current Summary

### Current phase
- Phase 0 to Phase 3 are complete enough for handoff.
- Phase 4 native sizing, shadow, motion, preview-control, and synthetic evidence coverage is complete and archived into `feature_list_summary.json`.
- The active queue is now Phase 5: native state machine, interaction intents, mock scenarios, and visible mouse/trackpad preview behavior.
- Phase 5 tasks 1-27 are complete, including reminder/paused timer intents, the mock scenario catalog, Phase 5 evidence generation, reducer-backed preview routing, native pointer/trackpad classification, preview-only scenario menu selection, and preview-only interaction demo menu controls.

### Queue snapshot
- First pending task: `Add minimal mock content markers so Phase 5 state changes are visible.`
- Remaining queue size: `14` tasks.
- Execution mode: parent-led `$Auto_dev` with parallel dependency analysis and subagent scouting, finalized in the main thread.

### Runtime / environment notes
- [`init.sh`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/init.sh) remains the runtime entry point for heavy execution-path tasks.
- `xcodebuild` is unavailable because the active developer directory is CommandLineTools only.
- Native validation still relies on `swiftc -module-cache-path /tmp/... -typecheck` plus focused synthetic harnesses.
- Sandbox/runtime caveat: backend port `8080` may already be occupied, and local bind attempts can fail with `SocketException: Operation not permitted` or `listen EPERM`.

### Archive note
- Older detailed history has been rolled into [`codex-progress-archive.md`](/Users/tangxitao/code/Project/AI-coding/MemoryFlow-trae/codex-progress-archive.md).
- Default startup path remains `AGENTS.md` -> `agent-state.md` -> `feature_list.json` -> `codex-progress.md`.

## Recent Key Records

## 2026-04-30 - Phase 5 interaction demo controls exposed in the status menu

- Added `IslandPhase5InteractionDemoControl` for the nine preview-only menu intents: hover enter, hover leave, tap, pointer swipe left, pointer swipe right, trackpad up, trackpad down, horizontal previous, and horizontal next.
- Updated `StatusMenuBuilder.swift`, `StatusBarController.swift`, and `IslandWindowController.swift` so the `Phase 5 Interactions` submenu is shown only when Phase 5 preview interaction routing is available, and each item dispatches through the same `dispatchPhase5Intent(...)` reducer path used by real hover, tap, pointer, and wheel preview interactions.
- Extended `IslandPhase5Probe.swift` and `docs/evidence/mac-island-phase5/generate-phase5-evidence.swift`, generating `docs/evidence/mac-island-phase5/interaction-demo-menu-probe.json` to compare each menu-triggered control against the equivalent direct reducer sequence.
- Validation: `./init.sh` stopped because backend port `8080` was already occupied by PID `59013`, so native verification used the documented fallback. `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck $(find mac-island/MemoryFlowIsland -name '*.swift' -print) docs/evidence/mac-island-phase5/generate-phase5-evidence.swift` passed. The focused evidence generator compiled and ran to regenerate Phase 5 evidence, and `jq 'all(.[]; .matchesReducerSequence == true)' docs/evidence/mac-island-phase5/interaction-demo-menu-probe.json` returned `true` for all nine interaction demo controls.

## 2026-04-30 - Phase 5 preview controller now routes native tap, hover, pointer, and wheel input

- Updated `mac-island/MemoryFlowIsland/Window/IslandWindowController.swift` to own a Phase 5 preview state container, derive `IslandDerivedState` into the existing sizing and motion pipeline, route hover/tap/pointer/wheel intents through `IslandPresentationReducer` when `MEMORYFLOW_ISLAND_PHASE5_PREVIEW` is enabled, and preserve the legacy direct preview cycle behind `MEMORYFLOW_ISLAND_LEGACY_PREVIEW_INTERACTIONS=1`.
- Added `mac-island/MemoryFlowIsland/Window/IslandInteractionHostingView.swift`, `IslandPhase5PreviewStateContainer.swift`, and `IslandPreviewInteractionAdapters.swift` so native AppKit mouse and scroll events can classify pointer taps/swipes plus trackpad vertical/horizontal gestures without editing the shared `State/` surface.
- Updated `mac-island/MemoryFlowIsland/UI/Visual/IslandVisualStatePreview.swift` so SwiftUI tap handling is only attached when the legacy direct preview interaction path is active, avoiding duplicate gesture routing once the controller owns native input.
- Validation: `./init.sh`, `MEMORYFLOW_BACKEND_PORT=18080 ./init.sh`, and `MEMORYFLOW_BACKEND_PORT=28080 ./init.sh` all stopped immediately because those backend ports were already occupied, so native verification used the documented fallback. `find mac-island/MemoryFlowIsland -name '*.swift' -print0 | xargs -0 swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` passed for the full native source set. `/private/tmp/mf_phase5_preview_probe` emitted `/private/tmp/mf_phase5_preview_probe.json` covering tap expand/collapse, hover enter/leave, pointer tap classification, pointer collapse/restore, horizontal music-wheel classification, and wheel cooldown suppression. `/private/tmp/mf_phase5_layout_probe` emitted `/private/tmp/mf_phase5_layout_probe.json`, showing Phase 5 compact startup resolves to `compactCollapsed` and hover enter/leave keeps the top anchor stable (`maxY = 982` across compact and hover rows).

## 2026-04-30 - Phase 5 reminder, scenarios, probes, and scenario menu routing landed

- Updated `mac-island/MemoryFlowIsland/State/IslandInteractionIntent.swift`, `IslandDomainState.swift`, `IslandMockScenario.swift`, `IslandPresentationReducer.swift`, and new `IslandPhase5Probe.swift` so the reducer now handles `reminderDue`, `pausedMusicTimeout`, and reducer-backed mock scenario selection while the scenario catalog and Phase 5 probe cover all 10 requested mock states plus hover/tap/pointer/trackpad/reminder/paused/rapid sequence coverage.
- Updated `mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift` and `StatusBarController.swift` so `MEMORYFLOW_ISLAND_PHASE5_SCENARIOS=1` exposes a preview-only `Phase 5 Scenarios` submenu that dispatches reducer-backed scenario selection for logged-out, review activity, todo activity, music activity, expanded music, and expanded app shells.
- Added `docs/evidence/mac-island-phase5/generate-phase5-evidence.swift` and generated `scenario-matrix.json`, `interaction-sequences.json`, `preview-interaction-probe.json`, and `scenario-selection-probe.json` under `docs/evidence/mac-island-phase5/`.
- Validation: `find mac-island/MemoryFlowIsland -name '*.swift' -print0 | xargs -0 swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` passed for the full native source set, then `find mac-island/MemoryFlowIsland -name '*.swift' ! -name 'MemoryFlowIslandApp.swift' -print0 | xargs -0 swiftc -module-cache-path /tmp/memoryflow-swift-module-cache docs/evidence/mac-island-phase5/generate-phase5-evidence.swift -o /tmp/memoryflow-phase5-evidence && /tmp/memoryflow-phase5-evidence` regenerated the Phase 5 evidence set.

## 2026-04-27 - Phase 5 reducer now guards gesture cooldown and animation locks

- Updated `mac-island/MemoryFlowIsland/State/IslandDomainState.swift` with shared lock identifiers plus a reducer-visible trackpad cooldown helper, so the pure Phase 5 state can represent cooldown and animation-lock windows without timers.
- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so successful trackpad gestures enter cooldown, force-compact transitions enter an animation lock, `transitionComplete(...)` clears those locks, and repeated tap/pointer/trackpad intents are ignored with explicit guard reasons while mode-switch or force-compact locks are active.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` with guarded tap, hover, pointer, and rapid trackpad sequences that prove repeated intents do not skip visual states before cooldown or force-compact unlock completes.
- Validation: `./init.sh` first failed because backend port `8080` was already occupied by PID `59013`, then `MEMORYFLOW_BACKEND_PORT=38080 ./init.sh` reached Maven startup but failed in the sandbox on `~/.m2/repository/.../resolver-status.properties` writes; per the documented fallback, lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the State + Visual dependency slice, then `/tmp/memoryflow_reducer_probe_runner` executed `IslandDerivedStateProbe.validateRepresentativeStates()`, `IslandPresentationReducerProbe.validateNoOpRows()`, `validateCompactDerivationRows()`, `validateActivityDerivationRows()`, `validateMusicDerivationRows()`, `validateMusicCommandRows()`, `validateTapTransitionSequences()`, `validateHoverTransitionSequences()`, `validatePointerTransitionSequences()`, and `validateTrackpadTransitionSequences()`.

## 2026-04-27 - Phase 5 reducer now emits mock horizontal music commands

- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so `horizontalMusicCommand` emits mock previous/next command metadata and matching transition reasons only when `primaryMode == .music`, while leaving app-mode horizontal swipes ignored and side-effect free.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` so reducer probe rows now capture optional mock music command metadata, validate both music horizontal command rows, and preserve the existing app-mode ignored swipe coverage.
- Validation: `./init.sh` stopped because backend port `8080` is already occupied by PID `59013`; `rg` found no `MediaRemote`, `Apple Music`, `Spotify`, `IPC`, or provider references in `mac-island/MemoryFlowIsland/State`; lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the State + Motion + Visual + `IslandWindowSizingResult` dependency slice, then `/tmp/memoryflow-phase5-horizontal-music-probe` executed `IslandPresentationReducerProbe.validateMusicCommandRows()` and `IslandPresentationReducerProbe.validateNoOpRows()` and emitted the expected JSON rows for music previous/next commands and the app-mode ignored horizontal swipe.

## 2026-04-27 - Phase 5 reducer now drives trackpad vertical open and close

- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so trackpad swipe up closes expanded presentation back to activity or compact as appropriate, and collapses visible activity into compact; trackpad swipe down reopens activity from compact or expands a visible activity card.
- Added explicit vertical-trackpad transition reasons while preserving the reducer's existing tap, hover, and pointer behavior.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` with reducer-backed sequences for expanded close, activity close, compact reopen, and activity expand using review activity mock states.
- Validation: `./init.sh` stopped because backend port `8080` is already occupied by PID `59013`; lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the Visual + State dependency slice, then `/tmp/memoryflow-phase5-trackpad-probe` executed `IslandPresentationReducerProbe.validateTrackpadTransitionSequences()` and `IslandPresentationReducerProbe.validatePointerTransitionSequences()` and emitted the expected JSON rows for expanded close, activity close, activity reopen, and activity expand.

## 2026-04-27 - Phase 5 reducer now drives pointer swipe compact/activity recovery

- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so pointer swipe right forces compact when activity content is currently visible, and pointer swipe left reopens activity when an activity source exists and the island is compact.
- Added explicit pointer transition reasons while preserving the reducer's no-op behavior for unrelated swipe cases.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` with a reducer-backed review activity sequence that swipes right into compact and swipes left back into activity, verifying both directions in one focused path.
- Validation: `./init.sh` stopped because backend port `8080` is already occupied by PID `59013`; lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the Visual + State dependency slice, then `/tmp/memoryflow-phase5-pointer-probe` executed `IslandPresentationReducerProbe.validatePointerTransitionSequences()` and `IslandPresentationReducerProbe.validateHoverTransitionSequences()` and emitted the expected JSON rows for review activity collapse and compact activity restore.

## 2026-04-27 - Phase 5 reducer now drives hover enter and leave state

- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so `hoverEnter` sets `isHovered` for non-expanded states, `hoverLeave` clears `isHovered`, compact hover derives to `hoverCollapsed`, and expanded presentation stays expanded when hover leaves.
- Added explicit hover transition reasons while leaving unrelated intents unchanged and preserving the existing tap/expand/collapse behavior.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` with reducer-backed hover sequences for compact hover enter/leave plus expanded app/music hover leave recovery.
- Validation: `./init.sh` stopped because backend port `8080` is already occupied by PID `59013`; lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the Visual + State dependency slice, then `/tmp/memoryflow-phase5-hover-probe` executed `IslandPresentationReducerProbe.validateHoverTransitionSequences()` and `IslandPresentationReducerProbe.validateTapTransitionSequences()` and emitted the expected JSON rows for compact hover enter/leave and expanded hover leave scenarios.

## 2026-04-27 - Phase 5 reducer now drives tap expand and collapse recovery

- Updated `mac-island/MemoryFlowIsland/State/IslandPresentationReducer.swift` so `.tap` expands collapsed/activity states into app or music expanded presentation for logged-in mock states, and `.tap` or `.outsideCollapse` collapses expanded states back to `activity` or `collapsed` depending on activity-source availability and `forceCompactMode`.
- Added explicit transition reasons for tap-driven app/music expansion and compact/activity collapse recovery, while preserving no-op behavior for unrelated intents and the logged-out login gate.
- Extended `mac-island/MemoryFlowIsland/State/IslandPresentationReducerProbe.swift` with reducer sequence coverage for review compact/activity and music compact/activity flows, proving compact -> expanded -> compact recovery and activity -> expanded -> activity recovery through the pure reducer path.
- Validation: `./init.sh` stopped because backend port `8080` is already occupied by PID `59013`; lightweight native validation passed with `swiftc -module-cache-path /tmp/memoryflow-swift-module-cache -typecheck` over the Visual + State dependency slice, then `/tmp/memoryflow-phase5-tap-probe` executed `IslandPresentationReducerProbe.validateTapTransitionSequences()`, `IslandPresentationReducerProbe.validateCompactDerivationRows()`, `IslandPresentationReducerProbe.validateActivityDerivationRows()`, and `IslandPresentationReducerProbe.validateMusicDerivationRows()` and emitted the expected JSON rows for app/music expansion plus activity/compact recovery.
