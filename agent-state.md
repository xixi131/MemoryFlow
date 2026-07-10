# agent-state.md

This file is the short handoff for the next agent. Keep it brief, current, and high-signal.

## Current phase
Phase 6 mock animation and content-parity queue is active. The goal is to reproduce every Windows Dynamic Island presentation, mouse interaction, trackpad interaction, and animation path in the native macOS AppKit + SwiftUI island while continuing to use deterministic mock review, todo, reminder, greeting, and music data.

The queue was generated after tracing `front-end/src/components/DynamicIslandWidget.tsx` and `front-end/electron/main.cjs`. The Windows baseline includes logged-out compact, logged-in compact, greeting, review/todo/music activity, expanded review/todo/music, reminder auto-open, music takeover, paused timeout, stopped fallback, hover, tap, pointer swipe, long-press mode switch, outside collapse, click-through recovery, vertical trackpad presentation changes, and horizontal music track commands.

The current native Phase 5 reducer, derived state, mock scenario routing, pointer/trackpad adapters, sizing engine, shape engine, panel, and click-through behavior are prerequisites. The new queue adds real animated presentation values, shape-metric interpolation, top-center anchored panel animation, content choreography, mock module layouts, velocity-preserving retargeting, Reduce Motion, and evidence.

## Queue mode
`replace-active` was used. The previous 41 completed Phase 5 tasks were preserved unchanged in `final_feature_list.json`. Phase 6 now includes deterministic scenarios, driver, shape morph, compact content, anchored sizing, duplicate-instance prevention, hover, activity open/collapse, expanded app/music opening, staged expanded collapse recovery, greeting lifecycle, long-press app-mode switching, and keyed reminder auto-open; 21 tasks remain.

## First pending task
* `mac-motion-music-takeover`: Animate mock music takeover from app presentation into music activity presentation.

## Recommended startup path
1. Read `AGENTS.md`.
2. Read this file.
3. Read the first pending item in `feature_list.json`.
4. For Windows parity, read only the matching ranges in `front-end/src/components/DynamicIslandWidget.tsx`, `front-end/electron/main.cjs`, `docs/mac-island-state-spec.md`, `docs/mac-island-interaction-spec.md`, and `docs/mac-island-animation-spec.md`.
5. For native work, start from `mac-island/MemoryFlowIsland/State/`, `Window/IslandWindowController.swift`, `Window/IslandPanel.swift`, `UI/Visual/IslandShapeEngine.swift`, `UI/Visual/IslandPathFactory.swift`, and `UI/Visual/IslandVisualStatePreview.swift`.
6. Use commits `f8be49d` and `b59f777` only as historical references for the deleted Motion implementation; adapt or recreate it against the current Phase 5 state pipeline instead of blindly restoring files.
7. Do not read `codex-progress-archive.md` during normal startup.

## Windows baseline constants
* Spring: stiffness `280`, damping `30`, mass `1.2`.
* Pointer activity swipe: `26px`; pointer tap: `10px`.
* Trackpad dominant-axis threshold: `70`; accumulation reset: `160ms`; cooldown: `320ms`.
* Activity open: `0.56s`; activity collapse: `0.85s`; collapse times: `[0, 0.45, 0.55, 1]`.
* Activity content enter: delay `0.10s`, duration `0.26s`, blur `4 -> 0`.
* Mode switch: long press `420ms`, compact phase `320ms`, reopen delay `70ms`.
* Greeting lifecycle: `10s`; paused music fallback: `30s`.
* Baseline expanded geometry: app `460 x 320`, music `460 x 210`.

## Runtime notes
* `init.sh` remains the full runtime entry point, but this phase must not require backend data because all module scenarios are mock-driven.
* Full Xcode 26.6 is active; use Xcode Debug builds and focused executable probes for native validation.
* Lightweight verification can use `swiftc -module-cache-path /tmp/... -typecheck`, focused Swift probes, deterministic frame sequences, and native preview controls.
* Real-device mouse, trackpad, 60Hz/120Hz, and spring calibration evidence must be labeled honestly when GUI capture is unavailable.

## Scope boundaries
* Do not modify or remove the Windows Electron implementation; it remains the parity reference and Windows production path.
* Do not connect backend APIs, authentication storage, Keychain, MediaRemote, Apple Music, Spotify, or real IPC data in this queue.
* Do not send real media commands or persist todo changes; use mock commands, mock clocks, simulated success, and simulated rollback.
* Current deleted files under `mac-island/MemoryFlowIsland/UI/Motion/` are part of the existing dirty worktree. Work with that state and do not restore unrelated changes automatically.
* Content must declare width requirements to the sizing engine and must never mutate the panel frame directly.
* Native test launches must be single-instance and must terminate before worker completion.
