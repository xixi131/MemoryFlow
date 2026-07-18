import Foundation

struct IslandMockScenario: Equatable, Identifiable {
    let id: String
    let menuTitle: String
    let initialState: IslandDomainState
    let expectedDerivedVisualState: IslandVisualState

    // Selection only replaces preview state through the reducer; it never starts media providers.
    static let phase5Catalog: [IslandMockScenario] = [
        IslandMockScenario(
            id: "logged-out-compact",
            menuTitle: "Logged Out Compact",
            initialState: .loggedOutCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "logged-in-review-compact",
            menuTitle: "Logged In Compact",
            initialState: .loggedInReviewCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "greeting",
            menuTitle: "Greeting",
            initialState: .mockGreetingCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "review-activity",
            menuTitle: "Review Activity",
            initialState: .mockReviewActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "todo-activity",
            menuTitle: "Todo Activity",
            initialState: .mockTodoActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "music-playing",
            menuTitle: "Music Playing",
            initialState: .mockMusicPlayingActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "music-paused",
            menuTitle: "Music Paused",
            initialState: .mockMusicPausedActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "expanded-review",
            menuTitle: "Expanded Review",
            initialState: .mockExpandedReview,
            expectedDerivedVisualState: .expandedApp
        ),
        IslandMockScenario(
            id: "expanded-review-scroll",
            menuTitle: "Scrollable Review",
            initialState: .mockExpandedScrollableReview,
            expectedDerivedVisualState: .expandedApp
        ),
        IslandMockScenario(
            id: "expanded-todo",
            menuTitle: "Expanded Todo",
            initialState: .mockExpandedTodo,
            expectedDerivedVisualState: .expandedApp
        ),
        IslandMockScenario(
            id: "expanded-music",
            menuTitle: "Expanded Music",
            initialState: .mockExpandedMusic,
            expectedDerivedVisualState: .expandedMusic
        ),
        IslandMockScenario(
            id: "reminder-due",
            menuTitle: "Reminder Due",
            initialState: .mockReminderDue,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "music-stopped-fallback",
            menuTitle: "Music Stopped Fallback",
            initialState: .mockMusicStoppedFallback,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "update-download-activity",
            menuTitle: "Update Download (42%)",
            initialState: .mockUpdateDownloadActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "update-download-indeterminate",
            menuTitle: "Update Download (--%%)",
            initialState: .mockUpdateDownloadIndeterminate,
            expectedDerivedVisualState: .activityCollapsed
        )
    ]

    static func scenario(id: String) -> IslandMockScenario? {
        phase5Catalog.first { $0.id == id }
    }
}
