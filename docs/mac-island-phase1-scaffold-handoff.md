# Phase 1 Scaffold Handoff

## Scope

This note records the current native macOS shell scaffold under `mac-island/` and is limited to Phase 1 shell modules only.

## Generated Native Modules

| Module | Current files | Current responsibility |
| --- | --- | --- |
| App | `mac-island/MemoryFlowIsland/App/MemoryFlowIslandApp.swift`<br>`mac-island/MemoryFlowIsland/App/AppDelegate.swift`<br>`mac-island/MemoryFlowIsland/App/SceneCoordinator.swift` | Boot the native app, bridge app lifecycle into the shell, and coordinate the menu bar plus island window controllers. |
| Window | `mac-island/MemoryFlowIsland/Window/IslandPanel.swift`<br>`mac-island/MemoryFlowIsland/Window/IslandWindowController.swift`<br>`mac-island/MemoryFlowIsland/Window/NotchLayoutEngine.swift`<br>`mac-island/MemoryFlowIsland/Window/DisplayObserver.swift` | Provide the transparent floating shell, placeholder top-center placement helpers, and display-change observation hooks for future notch-aware layout work. |
| MenuBar | `mac-island/MemoryFlowIsland/MenuBar/StatusBarController.swift`<br>`mac-island/MemoryFlowIsland/MenuBar/StatusMenuBuilder.swift` | Install the status item and expose the shell-level menu actions for show or hide, preferences, and quit. |
| Preferences | `mac-island/MemoryFlowIsland/Preferences/PreferencesWindowController.swift`<br>`mac-island/MemoryFlowIsland/Preferences/PreferencesView.swift` | Host the reusable native preferences window skeleton and its placeholder SwiftUI content. |
| UI | `mac-island/MemoryFlowIsland/UI/IslandRootView.swift` | Render the placeholder SwiftUI island content mounted into the native window host. |
| Resources | `mac-island/MemoryFlowIsland/Resources/Info.plist`<br>`mac-island/MemoryFlowIsland/Resources/Assets.xcassets` | Hold the minimal bundle metadata and placeholder asset catalog required for standalone app packaging and menu bar presentation. |

## Explicit Non-Goals For This Phase

- No `review` or `todo` feature migration is included in the current Phase 1 shell scaffold.
- No auth or API integration is included; there is no native replacement yet for `/auth/me`, `/auth/refresh`, `/widget/summary`, `/todos/stats`, or `/todos/tasks`.
- No music provider migration is included; the native shell does not yet add `MusicCoordinator`, provider adapters, or playback-driven UI takeover.

## Current Boundary Notes

- The current scaffold matches the generated shell modules that now exist under `App/`, `Window/`, `MenuBar/`, `Preferences/`, `UI/`, and `Resources/`.
- Recommended future directories from `灵动岛迁移方案.md`, such as `State/`, `Models/`, and `Services/`, are intentionally not created yet because they belong to later migration phases.
- The Windows Electron implementation remains the behavior baseline while this Phase 1 native shell stays focused on window, menu bar, preferences, and packaging structure only.
