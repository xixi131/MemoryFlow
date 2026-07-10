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

struct IslandPresentationLockState: Codable, Equatable {
    var isModeSwitchLocked: Bool
    var isForceCompactLocked: Bool
    var transitionID: String?

    static let idle = IslandPresentationLockState(
        isModeSwitchLocked: false,
        isForceCompactLocked: false,
        transitionID: nil
    )
}

enum IslandTransitionLockIdentifier {
    static let trackpadGestureCooldown = "trackpadGestureCooldown"
    static let forceCompactTransition = "forceCompactTransition"
    static let modeSwitchLock = "modeSwitchLock"
}

struct IslandMockReviewActivity: Codable, Equatable {
    var pendingCount: Int
    var completedTodayCount: Int
    var nextSubjectTitle: String?
    var subjectTitles: [String] = []

    static let empty = IslandMockReviewActivity(
        pendingCount: 0,
        completedTodayCount: 0,
        nextSubjectTitle: nil
    )
}

struct IslandMockTodoTask: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let isDueToday: Bool
    let isOverdue: Bool
}

struct IslandMockTodoActivity: Codable, Equatable {
    var pendingCount: Int
    var dueTodayCount: Int
    var overdueCount: Int
    var nextTaskTitle: String?
    var tasks: [IslandMockTodoTask] = []

    static let empty = IslandMockTodoActivity(
        pendingCount: 0,
        dueTodayCount: 0,
        overdueCount: 0,
        nextTaskTitle: nil
    )
}

struct IslandMockReminderActivity: Codable, Equatable {
    var timeText: String
    var isDue: Bool
    var isDueSoon: Bool

    static let due = IslandMockReminderActivity(
        timeText: "14:30",
        isDue: true,
        isDueSoon: false
    )
}

enum IslandMockMusicPlaybackStatus: String, Codable, Equatable {
    case playing
    case paused
    case stopped
}

struct IslandMockMusicActivity: Codable, Equatable {
    var trackTitle: String
    var artistName: String
    var isPlaying: Bool
    var elapsedSeconds: TimeInterval
    var durationSeconds: TimeInterval?
    var artworkData: Data?
    var artworkPlaceholder: String
    var themeColorHex: String
    var sourceName: String?
    var playbackStatus: IslandMockMusicPlaybackStatus

    var remainingSeconds: TimeInterval? {
        guard let durationSeconds else { return nil }
        return max(0, durationSeconds - elapsedSeconds)
    }

    static let sample = IslandMockMusicActivity(
        trackTitle: "Mock Track",
        artistName: "MemoryFlow",
        isPlaying: true,
        elapsedSeconds: 0,
        durationSeconds: 240,
        artworkData: nil,
        artworkPlaceholder: "music.artwork.placeholder",
        themeColorHex: "#22d3ee",
        sourceName: "Mock",
        playbackStatus: .playing
    )

    init(
        trackTitle: String,
        artistName: String,
        isPlaying: Bool,
        elapsedSeconds: TimeInterval,
        durationSeconds: TimeInterval?,
        artworkData: Data? = nil,
        artworkPlaceholder: String = "music.artwork.placeholder",
        themeColorHex: String = "#22d3ee",
        sourceName: String? = nil,
        playbackStatus: IslandMockMusicPlaybackStatus? = nil
    ) {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.isPlaying = isPlaying
        self.elapsedSeconds = elapsedSeconds
        self.durationSeconds = durationSeconds
        self.artworkData = artworkData
        self.artworkPlaceholder = artworkPlaceholder
        self.themeColorHex = themeColorHex
        self.sourceName = sourceName
        self.playbackStatus = playbackStatus ?? (isPlaying ? .playing : .paused)
    }

    init(snapshot: MusicTrackSnapshot) {
        self.trackTitle = snapshot.title
        self.artistName = snapshot.artist
        self.isPlaying = snapshot.isPlaying
        self.elapsedSeconds = snapshot.position
        self.durationSeconds = snapshot.duration
        self.artworkData = snapshot.artworkData
        self.artworkPlaceholder = "music.artwork.placeholder"
        self.themeColorHex = snapshot.themeColorHex
        self.sourceName = snapshot.source
        self.playbackStatus = snapshot.isPlaying ? .playing : .paused
    }
}

struct IslandMockActivitySources: Codable, Equatable {
    var review: IslandMockReviewActivity?
    var todo: IslandMockTodoActivity?
    var music: IslandMockMusicActivity?
    var reminder: IslandMockReminderActivity? = nil

    static let none = IslandMockActivitySources(
        review: nil,
        todo: nil,
        music: nil,
        reminder: nil
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
    var presentationLockState: IslandPresentationLockState
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

    var isTrackpadGestureLocked: Bool {
        gestureState == .cooldown
    }

    var isModeSwitchLocked: Bool {
        presentationLockState.isModeSwitchLocked
    }

    var isForceCompactLocked: Bool {
        presentationLockState.isForceCompactLocked
    }

    static let loggedOutCompact = IslandDomainState(
        authState: .loggedOut,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .collapsed,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
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
        presentationLockState: .idle,
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
        presentationLockState: .idle,
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
        presentationLockState: .idle,
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

    static let loggedInReviewActivityPlain = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
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

    static let loggedInTodoActivity = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .todo,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
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
        presentationLockState: .idle,
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
        presentationLockState: .idle,
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

    static let musicActivityWithAppFallback = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .music,
        appDisplayMode: .review,
        presentationState: .activity,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: IslandMockReviewActivity(
                pendingCount: 3,
                completedTodayCount: 2,
                nextSubjectTitle: IslandMockScenarioMarkerText.pausedMusicTimeout
            ),
            todo: nil,
            music: .sample
        )
    )

    static let expandedAppReview = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .expanded,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
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

    static let expandedMusic = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .music,
        appDisplayMode: .review,
        presentationState: .expanded,
        forceCompactMode: false,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
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

    static let pausedMusicTimeoutCompact = IslandDomainState(
        authState: .loggedIn,
        primaryMode: .app,
        appDisplayMode: .review,
        presentationState: .collapsed,
        forceCompactMode: true,
        isHovered: false,
        gestureState: .idle,
        presentationLockState: .idle,
        isReminderActive: false,
        isReminderCollapsing: false,
        isGreetingActive: false,
        greetingText: nil,
        mockSources: IslandMockActivitySources(
            review: IslandMockReviewActivity(
                pendingCount: 3,
                completedTodayCount: 2,
                nextSubjectTitle: IslandMockScenarioMarkerText.pausedMusicTimeout
            ),
            todo: nil,
            music: nil
        )
    )
}

extension IslandMockReviewActivity {
    static let scenarioSample = IslandMockReviewActivity(
        pendingCount: 12,
        completedTodayCount: 7,
        nextSubjectTitle: "Spaced repetition",
        subjectTitles: ["Algorithms", "English", "Cognitive Science"]
    )
}

extension IslandMockTodoActivity {
    static let scenarioSample = IslandMockTodoActivity(
        pendingCount: 4,
        dueTodayCount: 2,
        overdueCount: 1,
        nextTaskTitle: "Complete chapter summary",
        tasks: [
            IslandMockTodoTask(id: "todo-1", title: "Complete chapter summary", isCompleted: false, isDueToday: true, isOverdue: false),
            IslandMockTodoTask(id: "todo-2", title: "Review flashcards", isCompleted: false, isDueToday: true, isOverdue: false),
            IslandMockTodoTask(id: "todo-3", title: "Plan tomorrow", isCompleted: false, isDueToday: false, isOverdue: true),
            IslandMockTodoTask(id: "todo-4", title: "Read research notes", isCompleted: false, isDueToday: false, isOverdue: false),
            IslandMockTodoTask(id: "todo-5", title: "Organize study desk", isCompleted: true, isDueToday: false, isOverdue: false),
            IslandMockTodoTask(id: "todo-6", title: "Send study update", isCompleted: true, isDueToday: false, isOverdue: false)
        ]
    )
}

extension IslandMockMusicActivity {
    static let scenarioPlaying = IslandMockMusicActivity(
        trackTitle: "Night Study",
        artistName: "MemoryFlow Sessions",
        isPlaying: true,
        elapsedSeconds: 97,
        durationSeconds: 248,
        artworkPlaceholder: "music.artwork.night-study",
        themeColorHex: "#14b8a6",
        sourceName: "Deterministic Mock",
        playbackStatus: .playing
    )

    static let scenarioPaused = IslandMockMusicActivity(
        trackTitle: "Night Study",
        artistName: "MemoryFlow Sessions",
        isPlaying: false,
        elapsedSeconds: 97,
        durationSeconds: 248,
        artworkPlaceholder: "music.artwork.night-study",
        themeColorHex: "#64748b",
        sourceName: "Deterministic Mock",
        playbackStatus: .paused
    )
}

extension IslandDomainState {
    static var mockGreetingCompact: IslandDomainState {
        var state = loggedInReviewCompact
        state.isGreetingActive = true
        state.greetingText = "Good afternoon, Alex"
        state.mockSources.review = .scenarioSample
        return state
    }

    static var mockReviewActivity: IslandDomainState {
        var state = loggedInReviewActivityPlain
        state.mockSources.review = .scenarioSample
        return state
    }

    static var mockTodoActivity: IslandDomainState {
        var state = loggedInTodoActivity
        state.mockSources.todo = .scenarioSample
        return state
    }

    static var mockMusicPlayingActivity: IslandDomainState {
        var state = musicActivity
        state.mockSources.music = .scenarioPlaying
        return state
    }

    static var mockMusicPausedActivity: IslandDomainState {
        var state = musicActivity
        state.mockSources.music = .scenarioPaused
        return state
    }

    static var mockExpandedReview: IslandDomainState {
        var state = expandedAppReview
        state.mockSources.review = .scenarioSample
        return state
    }

    static var mockExpandedTodo: IslandDomainState {
        var state = expandedAppReview
        state.appDisplayMode = .todo
        state.mockSources.review = nil
        state.mockSources.todo = .scenarioSample
        return state
    }

    static var mockExpandedMusic: IslandDomainState {
        var state = expandedMusic
        state.mockSources.music = .scenarioPlaying
        return state
    }

    static var mockReminderDue: IslandDomainState {
        var state = mockReviewActivity
        state.isReminderActive = true
        state.mockSources.reminder = .due
        return state
    }

    static var mockMusicStoppedFallback: IslandDomainState {
        var state = pausedMusicTimeoutCompact
        state.mockSources.review = .scenarioSample
        state.mockSources.review?.nextSubjectTitle = IslandMockScenarioMarkerText.pausedMusicTimeout
        return state
    }
}
