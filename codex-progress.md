## Current Summary

### Current phase
- Phase 6 native mock animation and Windows-parity queue is active.
- Completed foundations: contracts, deterministic scenarios, motion planning and driver, shell morphing, compact content, anchored sizing, single-instance helper behavior, hover, activity open/collapse, and expanded app opening.
- The native helper now forbids multiple simultaneous instances, preventing duplicate Dynamic Island panels.

### Queue snapshot
- First pending task: `mac-motion-pointer-gesture`.
- Remaining queue size: `12` Phase 6 tasks.
- Execution mode: parent-led Auto_dev; parallel only for dependency-free, disjoint write scopes.

### Runtime notes
- Full Xcode 26.6 is active. Standard validation: `xcodebuild -project mac-island/MemoryFlowIsland.xcodeproj -scheme MemoryFlowIsland -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
- Test `MemoryFlowIsland` processes must be terminated after each runtime check.
- Worktree contains user-authorized pre-existing changes; preserve them while continuing task-scoped work.

## Recent Records

### 2026-07-10 - Window and duplicate panel fix
- Pixel-aligned top-center sizing now passes 20 notch/flat display samples.
- `LSMultipleInstancesProhibited` prevents concurrent native helper processes and duplicate panels.
- Xcode Debug build and focused sizing probe passed.

### 2026-07-10 - Core motion behavior
- Implemented exact compact hover, compact-to-activity opening, and segmented activity collapse with content choreography.
- Probes cover review, todo, music, reminder, and expanded recovery paths; Xcode builds passed.

### 2026-07-10 - Expanded app opening
- Review and todo activity routes now share the expanded app shell timeline and retain distinct layouts; tap and trackpad routes converge on `460 x 320` pre-scale geometry.
- Focused motion probe and Xcode Debug build passed; no native process was left running.

### 2026-07-10 - Expanded music opening
- Music activity now reaches the `460 x 210` pre-scale expanded shell with artwork, metadata, waveform, progress, and controls gated on one mock-only timeline.
- Tap and trackpad routes were probe-verified to converge on identical expanded music content and geometry; Xcode Debug build passed with no test process left running.

### 2026-07-10 - Expanded collapse recovery
- Expanded review, todo, and music now follow the Windows two-stage recovery: `expanded -> compactCollapsed -> matching activityCollapsed`; force compact terminates at ordinary compact.
- Focused nine-route tap/outside/trackpad probe, reducer recovery probe, and Xcode Debug build passed with no native process remaining.

### 2026-07-10 - Greeting lifecycle
- Greeting now enters and exits over 0.35s around its deterministic 10-second lifecycle; fast-forward and music takeover cancel it and release the compact width branch.
- `init.sh` and an unsigned Xcode Debug build passed. The timeline probe covers deterministic samples; GUI capture remains unavailable.

### 2026-07-10 - Review/todo long press
- Leading-icon holds now follow the Windows 420ms hold, 320ms compact, 70ms wait, and 0.56s activity-reopen sequence; early release, leave, cancel, scenario replacement, and duplicates are guarded.
- The deterministic bidirectional mode-switch probe, Xcode Debug build, and helper launch smoke test passed.

### 2026-07-10 - Reminder auto-open
- Reminder due is keyed and deterministic: only an app compact state can open review activity, repeated daily keys are ignored, and new keys replay the existing activity motion.
- The focused reminder probe and Xcode Debug build passed. An unrelated legacy-wide interaction probe retains three non-reminder transition-kind expectation mismatches.

### 2026-07-10 - Music takeover
- A mock playback-start control is auth-gated, clears force compact, and opens music activity; active-music snapshots use a 0.18s content retarget rather than replaying shell takeover.
- `init.sh`, the focused music-takeover probe, and Xcode Debug build passed.

### 2026-07-10 - Music release
- Paused 30-second and stopped controls now deterministically leave music; resumed or newer snapshots cancel/restart the pending timeout and app targets retain review/todo mode plus compact intent.
- Focused release probe, `init.sh`, and Xcode Debug build passed; broad legacy reducer evidence retains an unrelated tap expectation mismatch.

### 2026-07-10 - Music waveform
- Music now renders four activity or five expanded local waveform bars with phase-shifted 2.2-second motion, theme tint, display scaling, and 0.3-second paused settling.
- Focused waveform probe, `init.sh`, and Xcode Debug build passed; ticks stop when the waveform is not playing or visible.

### 2026-07-10 - Music artwork
- Artwork now uses a matched activity-to-expanded presentation model with interpolated geometry and isolated directional metadata changes.
- Transition probe, `init.sh`, and Xcode Debug builds passed.
