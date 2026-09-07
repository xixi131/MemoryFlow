import Foundation

/// The result of a single `IslandReminderDuePolicy.evaluate` call: which
/// reminder kind is due, the deterministic dedup key that should be dispatched
/// as `.reminderBannerDue(kind:key:)`, and how many times this kind has already
/// been announced today (`repeatIndex == 0` is the first announcement).
struct IslandReminderDueEvent: Equatable {
    let kind: IslandReminderKind
    let key: String
    let repeatIndex: Int
}

/// Turns the already-polled `reviewSnapshot`/`todoSnapshot` plus a local clock
/// into at most one due-reminder event per call. Pure and side-effect free —
/// no network calls, no timers, no state mutation. Callers (the 10s ticker in
/// `IslandWindowController` and the review/todo snapshot appliers) own turning
/// the returned event into a dispatched `.reminderBannerDue` intent.
enum IslandReminderDuePolicy {
    /// 复习没完成时的重复提醒间隔。
    static let repeatInterval: TimeInterval = 3600

    static func evaluate(
        now: Date,
        state: IslandDomainState,
        calendar: Calendar
    ) -> IslandReminderDueEvent? {
        let today = dayKey(for: now, calendar: calendar)
        let firedKeys = Set(state.firedReminderKeys)

        // 复习提醒总开关（网页设置里的「复习提醒」）。关闭时一律不提醒。
        guard state.reviewSnapshot?.reminderEnabled ?? true else { return nil }

        let totalPendingReviews = state.reviewSnapshot?.totalPendingReviews ?? 0
        let totalDueOrOverdueTasks = (state.todoSnapshot?.dueToday ?? 0) + (state.todoSnapshot?.overdueTasks ?? 0)
        // Review and todo share one user-level reminder time; only
        // `ReviewSnapshot` carries it today.
        let reminderTime = state.reviewSnapshot?.reminderTime
        let parsedReminderTime = reminderTime.flatMap(parseHourMinute)
        let hasConfiguredReminderTime = parsedReminderTime != nil
        let elapsed = elapsedSinceReminderTime(parsedReminderTime, now: now, calendar: calendar)

        // The reminder time gates the FIRST announcement of the day. Without a
        // configured time we fall back to "announce as soon as there is
        // something pending".
        let mayFireNow = elapsed != nil || hasConfiguredReminderTime == false

        // Review repeats: once the reminder time has passed and the queue is
        // still non-empty, re-announce once per `repeatInterval`. The bucket
        // index is embedded in the key, so a bucket that already fired can
        // never fire twice, and yesterday's keys never collide with today's.
        if totalPendingReviews > 0, mayFireNow {
            let repeatIndex = repeatBucket(elapsed: elapsed, now: now, calendar: calendar)
            let key = "review-\(today)#\(repeatIndex)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .review, key: key, repeatIndex: repeatIndex)
            }
        }
        // Todo keeps its single announcement per day — the hourly nagging was
        // requested for the review queue only.
        if totalDueOrOverdueTasks > 0, mayFireNow {
            let key = "todo-\(today)"
            if firedKeys.contains(key) == false {
                return IslandReminderDueEvent(kind: .todo, key: key, repeatIndex: 0)
            }
        }
        return nil
    }

    /// Which repeat slot `now` falls into. With a configured reminder time this
    /// is the number of whole `repeatInterval`s since that time; without one we
    /// bucket by hour of day so the fallback path still repeats hourly instead
    /// of firing once and going quiet.
    private static func repeatBucket(
        elapsed: TimeInterval?,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let elapsed else {
            return calendar.component(.hour, from: now)
        }
        return max(0, Int(elapsed / repeatInterval))
    }

    /// Seconds since today's reminder time, or `nil` when it is not configured
    /// or has not been reached yet. Accepts both `HH:mm` and `HH:mm:ss` source
    /// formats (the backend has shipped both).
    private static func elapsedSinceReminderTime(
        _ parsed: (hour: Int, minute: Int)?,
        now: Date,
        calendar: Calendar
    ) -> TimeInterval? {
        guard let parsed,
              let target = calendar.date(bySettingHour: parsed.hour, minute: parsed.minute, second: 0, of: now) else {
            return nil
        }
        let elapsed = now.timeIntervalSince(target)
        return elapsed >= 0 ? elapsed : nil
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
