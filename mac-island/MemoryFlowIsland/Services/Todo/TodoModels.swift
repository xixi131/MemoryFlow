import Foundation

struct TodoStatsDTO: Decodable {
    let pendingTasks: Int
    let dueToday: Int
    let overdueTasks: Int
}
struct TodoTaskDTO: Decodable {
    let id: Int64
    let title: String
    let status: String
    let priority: String
    let dueDate: String?
    let dueTime: String?
    let overdue: Bool
    let dueToday: Bool
}

struct TodoTaskSnapshot: Codable, Equatable, Identifiable {
    let id: Int64
    let title: String
    let status: String
    let priority: String
    let dueDate: String?
    let dueTime: String?
    let isOverdue: Bool
    let isDueToday: Bool
}

struct TodoSnapshot: Codable, Equatable {
    let pendingTasks: Int
    let dueToday: Int
    let overdueTasks: Int
    let tasks: [TodoTaskSnapshot]
    var isStale: Bool = false

    init(stats: TodoStatsDTO, tasks: [TodoTaskDTO]) {
        pendingTasks = max(0, stats.pendingTasks)
        dueToday = max(0, stats.dueToday)
        overdueTasks = max(0, stats.overdueTasks)
        self.tasks = tasks.prefix(6).map {
            TodoTaskSnapshot(
                id: $0.id,
                title: $0.title,
                status: $0.status,
                priority: $0.priority,
                dueDate: $0.dueDate,
                dueTime: $0.dueTime,
                isOverdue: $0.overdue,
                isDueToday: $0.dueToday
            )
        }
    }

    func markingStale() -> TodoSnapshot {
        var copy = self
        copy.isStale = true
        return copy
    }
}

extension TodoSnapshot {
    var presentationActivity: IslandMockTodoActivity {
        IslandMockTodoActivity(
            pendingCount: pendingTasks,
            dueTodayCount: dueToday,
            overdueCount: overdueTasks,
            nextTaskTitle: tasks.first?.title,
            tasks: tasks.map {
                IslandMockTodoTask(
                    id: String($0.id),
                    title: $0.title,
                    isCompleted: $0.status == "done" || $0.status == "completed",
                    isDueToday: $0.isDueToday,
                    isOverdue: $0.isOverdue
                )
            }
        )
    }
}
