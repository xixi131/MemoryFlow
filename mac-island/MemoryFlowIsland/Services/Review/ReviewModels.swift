import Foundation

struct WidgetSummaryDTO: Decodable {
    let totalPendingReviews: Int
    let totalCompletedToday: Int
    let reminderTime: String?
    let subjects: [SubjectLightDTO]
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

struct ReviewSnapshot: Codable, Equatable {
    let totalPendingReviews: Int
    let totalCompletedToday: Int
    let reminderTime: String?
    let subjects: [ReviewSubjectSnapshot]
    var isStale: Bool = false
    var lastSuccessfulSyncAt: Date? = nil

    var nextSubjectTitle: String? {
        subjects.first(where: { $0.pendingReviewCount > 0 })?.title ?? subjects.first?.title
    }

    init(dto: WidgetSummaryDTO) {
        totalPendingReviews = max(0, dto.totalPendingReviews)
        totalCompletedToday = max(0, dto.totalCompletedToday)
        reminderTime = dto.reminderTime
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
            nextSubjectTitle: nextSubjectTitle,
            subjectTitles: subjects.map(\.title)
        )
    }
}
