import CoreGraphics
import Foundation

struct IslandDerivedStateProbeRow: Codable, Equatable {
    let scenarioID: String
    let visualState: String
    let collapsedWidth: Double
    let collapsedCornerRadius: Double
    let collapsedCornerSmoothness: Double
    let showsMusicActivity: Bool
    let showsReviewActivity: Bool
    let showsTodoActivity: Bool
    let showsReminder: Bool
    let showsAppActivity: Bool
    let showsAnyActivity: Bool
    let contentExtensionWidth: Double
}

enum IslandDerivedStateProbe {
    static func representativeRows() -> [IslandDerivedStateProbeRow] {
        representativeStates.map { scenarioID, state in
            let derivedState = IslandDerivedState.derive(from: state)
            return IslandDerivedStateProbeRow(
                scenarioID: scenarioID,
                visualState: derivedState.visualState.rawValue,
                collapsedWidth: scalar(derivedState.collapsedWidth),
                collapsedCornerRadius: scalar(derivedState.collapsedCornerRadius),
                collapsedCornerSmoothness: scalar(derivedState.collapsedCornerSmoothness),
                showsMusicActivity: derivedState.showMusicActivity,
                showsReviewActivity: derivedState.showReviewActivity,
                showsTodoActivity: derivedState.showTodoActivity,
                showsReminder: derivedState.showReminder,
                showsAppActivity: derivedState.showAppActivity,
                showsAnyActivity: derivedState.showAnyActivity,
                contentExtensionWidth: scalar(
                    derivedState.contentWidthRequirement.requiredExtensionWidth
                )
            )
        }
    }

    @discardableResult
    static func validateRepresentativeStates() throws -> [IslandDerivedStateProbeRow] {
        let rows = representativeRows()
        let expectedRows = [
            IslandDerivedStateProbeRow(
                scenarioID: "logged-out-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 180,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-review-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 160,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-review-activity",
                visualState: "activityCollapsed",
                collapsedWidth: 240,
                collapsedCornerRadius: 40,
                collapsedCornerSmoothness: 2.8,
                showsMusicActivity: false,
                showsReviewActivity: true,
                showsTodoActivity: false,
                showsReminder: true,
                showsAppActivity: true,
                showsAnyActivity: true,
                contentExtensionWidth: 108
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "logged-in-todo-compact",
                visualState: "compactCollapsed",
                collapsedWidth: 230,
                collapsedCornerRadius: 50,
                collapsedCornerSmoothness: 3.3,
                showsMusicActivity: false,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: false,
                contentExtensionWidth: 0
            ),
            IslandDerivedStateProbeRow(
                scenarioID: "music-activity",
                visualState: "activityCollapsed",
                collapsedWidth: 240,
                collapsedCornerRadius: 40,
                collapsedCornerSmoothness: 2.8,
                showsMusicActivity: true,
                showsReviewActivity: false,
                showsTodoActivity: false,
                showsReminder: false,
                showsAppActivity: false,
                showsAnyActivity: true,
                contentExtensionWidth: 108
            )
        ]

        guard rows == expectedRows else {
            throw ProbeValidationError.unexpectedRows(
                expected: expectedRows,
                actual: rows
            )
        }

        return rows
    }

    private static let representativeStates: [(String, IslandDomainState)] = [
        ("logged-out-compact", .loggedOutCompact),
        ("logged-in-review-compact", .loggedInReviewCompact),
        (
            "logged-in-review-activity",
            IslandDomainState(
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
        ),
        ("logged-in-todo-compact", .loggedInTodoCompact),
        ("music-activity", .musicActivity)
    ]

    private static func scalar(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }
}

enum ProbeValidationError: Error, CustomStringConvertible {
    case unexpectedRows(expected: [IslandDerivedStateProbeRow], actual: [IslandDerivedStateProbeRow])

    var description: String {
        switch self {
        case let .unexpectedRows(expected, actual):
            return """
            Unexpected derived-state probe rows.
            Expected: \(expected)
            Actual: \(actual)
            """
        }
    }
}
