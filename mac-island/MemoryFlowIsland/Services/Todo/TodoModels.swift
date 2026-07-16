import Foundation

struct TodoStatsDTO: Decodable {
    let pendingTasks: Int
    let dueToday: Int
    let overdueTasks: Int
}
struct TodoTaskDTO: Decodable {
    let id: Int64
    let title: String
    let descriptionMd: String?
    let status: String
    let priority: String
    let dueDate: String?
    let dueTime: String?
    let overdue: Bool
    let dueToday: Bool

    init(
        id: Int64,
        title: String,
        descriptionMd: String? = nil,
        status: String,
        priority: String,
        dueDate: String?,
        dueTime: String?,
        overdue: Bool,
        dueToday: Bool
    ) {
        self.id = id
        self.title = title
        self.descriptionMd = descriptionMd
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.overdue = overdue
        self.dueToday = dueToday
    }
}

struct TodoTaskSnapshot: Codable, Equatable, Identifiable {
    let id: Int64
    let title: String
    let descriptionMd: String?
    let status: String
    let priority: String
    let dueDate: String?
    let dueTime: String?
    let isOverdue: Bool
    let isDueToday: Bool
}

struct TodoSnapshot: Codable, Equatable {
    var pendingTasks: Int
    var dueToday: Int
    var overdueTasks: Int
    var tasks: [TodoTaskSnapshot]
    var isStale: Bool = false

    init(stats: TodoStatsDTO, tasks: [TodoTaskDTO]) {
        pendingTasks = max(0, stats.pendingTasks)
        dueToday = max(0, stats.dueToday)
        overdueTasks = max(0, stats.overdueTasks)
        self.tasks = tasks.prefix(6).map {
            TodoTaskSnapshot(
                id: $0.id,
                title: $0.title,
                descriptionMd: $0.descriptionMd,
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

    func completing(taskID: Int64) -> TodoSnapshot? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        let task = tasks[index]
        guard task.status != "done" && task.status != "completed" else { return nil }
        var copy = self
        copy.tasks[index] = TodoTaskSnapshot(
            id: task.id,
            title: task.title,
            descriptionMd: task.descriptionMd,
            status: "completed",
            priority: task.priority,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
            isOverdue: task.isOverdue,
            isDueToday: task.isDueToday
        )
        copy.pendingTasks = max(0, pendingTasks - 1)
        if task.isDueToday { copy.dueToday = max(0, dueToday - 1) }
        if task.isOverdue { copy.overdueTasks = max(0, overdueTasks - 1) }
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
                    descriptionMd: $0.descriptionMd,
                    priority: IslandTodoPriority(apiValue: $0.priority),
                    dueDate: $0.dueDate,
                    dueTime: $0.dueTime,
                    isCompleted: $0.status == "done" || $0.status == "completed",
                    isDueToday: $0.isDueToday,
                    isOverdue: $0.isOverdue
                )
            }
        )
    }
}
