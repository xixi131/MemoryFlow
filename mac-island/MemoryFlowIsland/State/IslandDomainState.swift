import Foundation

enum IslandAuthState: String, Codable, Equatable {
    case loggedOut
    case loggedIn
}

enum IslandPrimaryMode: String, Codable, Equatable {
    case app
    case music
}

enum IslandAppDisplayMode: String, Codable, Equatable {
    case review
    case todo
}

enum IslandPresentationState: String, Codable, Equatable {
    case collapsed
    case activity
    case expanded
}

enum IslandGestureState: String, Codable, Equatable {
    case idle
    case pointerTracking
    case trackpadTracking
    case cooldown
}

struct IslandAnimationState: Codable, Equatable {
    var isModeSwitchAnimating: Bool
    var isForceCompactTransitioning: Bool
    var transitionID: String?

    static let idle = IslandAnimationState(
        isModeSwitchAnimating: false,
        isForceCompactTransitioning: false,
        transitionID: nil
    )
}

struct IslandMockReviewActivity: Codable, Equatable {
    var pendingCount: Int
    var completedTodayCount: Int
    var nextSubjectTitle: String?

    static let empty = IslandMockReviewActivity(
        pendingCount: 0,
        completedTodayCount: 0,
        nextSubjectTitle: nil
    )
}

struct IslandMockTodoActivity: Codable, Equatable {
    var pendingCount: Int
    var dueTodayCount: Int
    var overdueCount: Int
    var nextTaskTitle: String?

    static let empty = IslandMockTodoActivity(
        pendingCount: 0,
        dueTodayCount: 0,
        overdueCount: 0,
        nextTaskTitle: nil
    )
}

struct IslandMockMusicActivity: Codable, Equatable {
    var trackTitle: String
    var artistName: String
    var isPlaying: Bool
    var elapsedSeconds: TimeInterval
    var durationSeconds: TimeInterval?

    static let sample = IslandMockMusicActivity(
        trackTitle: "Mock Track",
        artistName: "MemoryFlow",
        isPlaying: true,
        elapsedSeconds: 0,
        durationSeconds: nil
    )
}

struct IslandMockActivitySources: Codable, Equatable {
    var review: IslandMockReviewActivity?
    var todo: IslandMockTodoActivity?
    var music: IslandMockMusicActivity?

    static let none = IslandMockActivitySources(
        review: nil,
        todo: nil,
        music: nil
    )
}

struct IslandDomainState: Codable, Equatable {
    var authState: IslandAuthState
    var primaryMode: IslandPrimaryMode
    var appDisplayMode: IslandAppDisplayMode
    var presentationState: IslandPresentationState
    var forceCompactMode: Bool
    var isHovered: Bool
    var gestureState: IslandGestureState
    var animationState: IslandAnimationState
    var isReminderActive: Bool
    var isReminderCollapsing: Bool
    var isGreetingActive: Bool
    var greetingText: String?
    var mockSources: IslandMockActivitySources

    var isGestureTracking: Bool {
        switch gestureState {
        case .pointerTracking, .trackpadTracking:
            return true
        case .idle, .cooldown:
            return false
        }
    }

    var isModeSwitchAnimating: Bool {
        animationState.isModeSwitchAnimating
    }

    var isForceCompactTransitioning: Bool {
        animationState.isForceCompactTransitioning
    }

    static let loggedOutCompact = IslandDomainState(
        authState: .loggedOut,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .collapsed,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: .none
    )

    static let loggedInReviewCompact = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .collapsed,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: IslandMockReviewActivity(
                pendingCount: 3,
                completedTodayCount: 2,
                nextSubjectTitle: "Review"
            ),
            todo: nil,
            music: nil
        )
    )

    static let loggedInTodoCompact = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .todo,
        presentationState: .collapsed,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: nil,
            todo: IslandMockTodoActivity(
                pendingCount: 4,
                dueTodayCount: 1,
                overdueCount: 0,
                nextTaskTitle: "Todo"
            ),
            music: nil
        )
    )

    static let loggedInReviewActivity = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: true,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: IslandMockReviewActivity(
                pendingCount: 3,
                completedTodayCount: 2,
                nextSubjectTitle: "Review"
            ),
            todo: nil,
            music: nil
        )
    )

    static let loggedInTodoActivity = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .todo,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: nil,
            todo: IslandMockTodoActivity(
                pendingCount: 4,
                dueTodayCount: 1,
                overdueCount: 0,
                nextTaskTitle: "Todo"
            ),
            music: nil
        )
    )

    static let musicCompactFallback = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .music,
        appDisplayMode: .review,
        presentationState: .activity,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: nil,
            todo: nil,
            music: .sample
        )
    )

    static let musicActivity = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .music,
        appDisplayMode: .review,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        animationState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: nil,
            todo: nil,
            music: .sample
        )
    )
}
