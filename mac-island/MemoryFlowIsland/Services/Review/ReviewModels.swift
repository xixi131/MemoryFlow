import Foundation

struct WidgetSummaryDTO: Decodable {
    let totalPendingReviews: Int
    let totalCompletedToday: Int
    let reminderTime: String?
    let subjects: [SubjectLightDTO]
    /// 复习提醒总开关。老版本后端不返回该字段，缺省视为开启。
    var reminderEnabled: Bool? = nil
    /// 今日待复习的具体要点。老版本后端不返回该字段。
    var reviewItems: [ReviewItemDTO]? = nil
}

struct ReviewItemDTO: Decodable {
    let id: Int64
    var subjectId: Int64? = nil
    var chapterId: Int64? = nil
    let title: String
    var chapterTitle: String? = nil
    var subjectTitle: String? = nil
    var learnedAt: String? = nil
    var nextReviewDate: String? = nil
    var overdue: Bool? = nil
}
struct SubjectLightDTO: Decodable {
    let id: Int64
    let title: String
    let icon: String?
    let colorClass: String?
    let progress: Int?
    let pendingReviewCount: Int
    let lightStatus: String
    let goalTitle: String?
}

struct ReviewSubjectSnapshot: Codable, Equatable, Identifiable {
    let id: Int64
    let title: String
    let icon: String?
    let colorClass: String?
    let progress: Int?
    let pendingReviewCount: Int
    let lightStatus: String
    let goalTitle: String?
}

/// 一条具体的待复习内容（要点级），对应网页「今日聚焦」列表里的一行。
struct ReviewItemSnapshot: Codable, Equatable, Identifiable {
    let id: Int64
    let subjectId: Int64?
    let title: String
    /// 章节标题，例如「第 1 周 · 数组与字符串基础（24 题）」
    let subtitle: String
    /// 学习日期的展示文本，例如「8月22日」
    let dateText: String
    let isOverdue: Bool

    init(dto: ReviewItemDTO) {
        id = dto.id
        subjectId = dto.subjectId
        title = dto.title
        // 优先显示章节标题；没有章节时退回科目名，两者都缺就只显示标题。
        let chapterTitle = dto.chapterTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        subtitle = chapterTitle.isEmpty ? (dto.subjectTitle ?? "") : chapterTitle
        dateText = ReviewItemSnapshot.displayDate(from: dto.learnedAt)
        isOverdue = dto.overdue ?? false
    }

    init(
        id: Int64,
        subjectId: Int64?,
        title: String,
        subtitle: String,
        dateText: String,
        isOverdue: Bool
    ) {
        self.id = id
        self.subjectId = subjectId
        self.title = title
        self.subtitle = subtitle
        self.dateText = dateText
        self.isOverdue = isOverdue
    }

    /// `learnedAt` 是后端 `LocalDateTime.toString()`，前 10 位固定是 `yyyy-MM-dd`。
    /// 只取日期部分并渲染成「8月22日」，与网页端一致。
    static func displayDate(from isoText: String?) -> String {
        guard let isoText, isoText.count >= 10 else { return "" }
        let datePart = isoText.prefix(10).split(separator: "-")
        guard datePart.count == 3,
              let month = Int(datePart[1]),
              let day = Int(datePart[2]) else { return "" }
        return "\(month)月\(day)日"
    }
}

struct ReviewSnapshot: Codable, Equatable {
    let totalPendingReviews: Int
    let totalCompletedToday: Int
    let reminderTime: String?
    /// 复习提醒总开关；关闭时不得触发任何复习提醒。
    let reminderEnabled: Bool
    let subjects: [ReviewSubjectSnapshot]
    let items: [ReviewItemSnapshot]
    var isStale: Bool = false
    var lastSuccessfulSyncAt: Date? = nil

    var nextSubjectTitle: String? {
        subjects.first(where: { $0.pendingReviewCount > 0 })?.title ?? subjects.first?.title
    }

    init(dto: WidgetSummaryDTO) {
        totalPendingReviews = max(0, dto.totalPendingReviews)
        totalCompletedToday = max(0, dto.totalCompletedToday)
        reminderTime = dto.reminderTime
        reminderEnabled = dto.reminderEnabled ?? true
        items = (dto.reviewItems ?? []).map(ReviewItemSnapshot.init(dto:))
        subjects = dto.subjects.map {
            ReviewSubjectSnapshot(
                id: $0.id,
                title: $0.title,
                icon: $0.icon,
                colorClass: $0.colorClass,
                progress: $0.progress,
                pendingReviewCount: max(0, $0.pendingReviewCount),
                lightStatus: $0.lightStatus,
                goalTitle: $0.goalTitle
            )
        }
        isStale = false
        lastSuccessfulSyncAt = Date()
    }

    func markingStale() -> ReviewSnapshot {
        var copy = self
        copy.isStale = true
        return copy
    }
}

extension ReviewSnapshot {
    var presentationActivity: IslandMockReviewActivity {
        IslandMockReviewActivity(
            pendingCount: totalPendingReviews,
            completedTodayCount: totalCompletedToday,
            nextSubjectTitle: items.first?.title ?? nextSubjectTitle,
            subjectTitles: subjects.map(\.title),
            items: items.map {
                IslandReviewItem(
                    id: String($0.id),
                    subjectID: $0.subjectId.map(String.init),
                    title: $0.title,
                    subtitle: $0.subtitle,
                    dateText: $0.dateText,
                    isOverdue: $0.isOverdue
                )
            }
        )
    }
}
