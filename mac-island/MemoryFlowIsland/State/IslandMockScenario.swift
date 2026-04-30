import Foundation

struct IslandMockScenario: Equatable, Identifiable {
    let id: String
    let menuTitle: String
    let initialState: IslandDomainState
    let expectedDerivedVisualState: IslandVisualState

    static let phase5Catalog: [IslandMockScenario] = [
        IslandMockScenario(
            id: "logged-out-compact",
            menuTitle: "Logged Out Compact",
            initialState: .loggedOutCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "logged-in-review-compact",
            menuTitle: "Review Compact",
            initialState: .loggedInReviewCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "logged-in-todo-compact",
            menuTitle: "Todo Compact",
            initialState: .loggedInTodoCompact,
            expectedDerivedVisualState: .compactCollapsed
        ),
        IslandMockScenario(
            id: "review-activity",
            menuTitle: "Review Activity",
            initialState: .loggedInReviewActivityPlain,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "todo-activity",
            menuTitle: "Todo Activity",
            initialState: .loggedInTodoActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "music-activity",
            menuTitle: "Music Activity",
            initialState: .musicActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "expanded-music",
            menuTitle: "Expanded Music",
            initialState: .expandedMusic,
            expectedDerivedVisualState: .expandedMusic
        ),
        IslandMockScenario(
            id: "expanded-app",
            menuTitle: "Expanded App",
            initialState: .expandedAppReview,
            expectedDerivedVisualState: .expandedApp
        ),
        IslandMockScenario(
            id: "reminder-due",
            menuTitle: "Reminder Due",
            initialState: .loggedInReviewActivity,
            expectedDerivedVisualState: .activityCollapsed
        ),
        IslandMockScenario(
            id: "paused-music-timeout",
            menuTitle: "Paused Music Timeout",
            initialState: .pausedMusicTimeoutCompact,
            expectedDerivedVisualState: .compactCollapsed
        )
    ]

    static func scenario(id: String) -> IslandMockScenario? {
        phase5Catalog.first { $0.id == id }
    }
}
