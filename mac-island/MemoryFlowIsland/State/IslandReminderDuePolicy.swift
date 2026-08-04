import Foundation

/// The result of a single `IslandReminderDuePolicy.evaluate` call: which
/// reminder kind is due and the deterministic, day-scoped dedup key that
/// should be dispatched as `.reminderBannerDue(kind:key:)`.
struct IslandReminderDueEvent: Equatable {
    let kind: IslandReminderKind
    let key: String
}

/// Turns the already-polled `reviewSnapshot`/`todoSnapshot` plus a local clock
/// into at most one due-reminder event per call. Pure and side-effect free —
/// no network calls, no timers, no state mutation. Callers (the 10s ticker in
/// `IslandWindowController` and the review/todo snapshot appliers) own turning
/// the returned event into a dispatched `.reminderBannerDue` intent.
enum IslandReminderDuePolicy {
    static func evaluate(
        now: Date,
        state: IslandDomainState,
        calendar: Calendar
    ) -> IslandReminderDueEvent? {
        let today = dayKey(for: now, calendar: calendar)
        let firedKeys = Set(state.firedReminderKeys)

        let totalPendingReviews = state.reviewSnapshot?.totalPendingReviews ?? 0
        let totalDueOrOverdueTasks = (state.todoSnapshot?.dueToday ?? 0) + (state.todoSnapshot?.overdueTasks ?? 0)
        // Review and todo share one user-level reminder time; only
        // `ReviewSnapshot` carries it today.
        let reachedTimeKey = reachedReminderTimeSuffix(
            state.reviewSnapshot?.reminderTime,
            now: now,
            calendar: calendar
        )

        // Every candidate key embeds `today`, so checking a freshly built key
        // against `firedKeys` is equivalent to first pruning the array down to
        // today's entries: a key fired on a previous day never matches, so the
        // same kind/reason re-arms automatically once the day rolls over.
        if totalPendingReviews > 0, let reachedTimeKey {
            let key = "review-time-\(today)-\(reachedTimeKey)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .review, key: key)
            }
        }
        if totalDueOrOverdueTasks > 0, let reachedTimeKey {
            let key = "todo-time-\(today)-\(reachedTimeKey)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .todo, key: key)
            }
        }
        if totalPendingReviews > 0 {
            let key = "review-today-\(today)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .review, key: key)
            }
        }
        if totalDueOrOverdueTasks > 0 {
            let key = "todo-today-\(today)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .todo, key: key)
            }
        }
        return nil
    }

    /// Returns the zero-padded `HH:mm` suffix for the shared reminder time if
    /// `now` has reached it today, else `nil`. Accepts both `HH:mm` and
    /// `HH:mm:ss` source formats (the backend has shipped both).
    private static func reachedReminderTimeSuffix(
        _ reminderTime: String?,
        now: Date,
        calendar: Calendar
    ) -> String? {
        guard let reminderTime, let parsed = parseHourMinute(reminderTime) else { return nil }
        guard let target = calendar.date(bySettingHour: parsed.hour, minute: parsed.minute, second: 0, of: now) else {
            return nil
        }
        guard now >= target else { return nil }
        return String(format: "%02d:%02d", parsed.hour, parsed.minute)
    }

    private static func parseHourMinute(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
