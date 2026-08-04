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
        let reminderTime = state.reviewSnapshot?.reminderTime
        let hasConfiguredReminderTime = reminderTime.flatMap(parseHourMinute) != nil
        let reminderTimeReached = reachedReminderTimeSuffix(reminderTime, now: now, calendar: calendar) != nil

        // Fire AT MOST ONCE per kind per day, no matter how many items are
        // pending and no matter how many times this gets re-evaluated (10s
        // ticker + snapshot appliers). There is deliberately no separate
        // "reminder time reached" vs. "has tasks today" pair anymore — both
        // used to embed `today` as two distinct keys, so once the reminder
        // time passed with items still pending, BOTH became eligible within
        // moments of each other and fired back-to-back (perceived as
        // reminder spam). A single day-scoped key per kind is dispatched as
        // soon as the reminder time is reached (or immediately, if no
        // reminder time is configured), and never again until the day rolls
        // over — checking a freshly built key against `firedKeys` is
        // equivalent to pruning stale entries, since a key fired on a
        // previous day never matches today's key.
        let mayFireNow = reminderTimeReached || hasConfiguredReminderTime == false

        if totalPendingReviews > 0, mayFireNow {
            let key = "review-\(today)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .review, key: key)
            }
        }
        if totalDueOrOverdueTasks > 0, mayFireNow {
            let key = "todo-\(today)"
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
