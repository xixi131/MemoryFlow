import Foundation

struct TodoMutationProbeResult: Equatable {
    let optimisticCounts: [Int]
    let duplicatePrevented: Bool
    let successReconciled: Bool
    let offlineRolledBackOnce: Bool
    let serverRolledBackOnce: Bool
    let authRolledBackOnce: Bool
    let authInvalidations: Int
    let persistedGETConfirmed: Bool
}

enum TodoMutationProbe {
    @MainActor
    static func run() async throws -> TodoMutationProbeResult {
        let original = snapshot()
        let repository = TodoMutationProbeRepository(original: original)
        var delivered: [TodoSnapshot] = []
        let controller = TodoMutationController(repository: repository) { delivered.append($0) }
        var invalidations = 0
        controller.onAuthenticationInvalidated = { invalidations += 1 }

        controller.acceptSnapshot(original)
        repository.nextCompletionError = nil
        controller.complete(taskID: 1)
        let optimistic = delivered.last!
        controller.complete(taskID: 1)
        await waitUntilIdle(controller, taskID: 1)
        let duplicatePrevented = repository.completionCalls == 1
        let successReconciled = delivered.last?.tasks.contains(where: { $0.id == 1 }) == false
        let persistedGET = repository.fetchCalls == 1 && repository.persistedCompletedIDs.contains(1)

        controller.acceptSnapshot(original)
        let beforeOffline = delivered.filter { $0 == original }.count
        repository.nextCompletionError = URLError(.notConnectedToInternet)
        controller.complete(taskID: 1)
        await waitUntilIdle(controller, taskID: 1)
        let offlineRollback = delivered.filter { $0 == original }.count == beforeOffline + 1

        controller.acceptSnapshot(original)
        let beforeServer = delivered.filter { $0 == original }.count
        repository.nextCompletionError = APIClientError.backend(code: 500, message: "server")
        controller.complete(taskID: 1)
        await waitUntilIdle(controller, taskID: 1)
        let serverRollback = delivered.filter { $0 == original }.count == beforeServer + 1

        controller.acceptSnapshot(original)
        let beforeAuth = delivered.filter { $0 == original }.count
        repository.nextCompletionError = APIClientError.transportStatus(401)
        controller.complete(taskID: 1)
        await waitUntilIdle(controller, taskID: 1)
        let authRollback = delivered.filter { $0 == original }.count == beforeAuth + 1

        return TodoMutationProbeResult(
            optimisticCounts: [optimistic.pendingTasks, optimistic.dueToday, optimistic.overdueTasks],
            duplicatePrevented: duplicatePrevented,
            successReconciled: successReconciled,
            offlineRolledBackOnce: offlineRollback,
            serverRolledBackOnce: serverRollback,
            authRolledBackOnce: authRollback,
            authInvalidations: invalidations,
            persistedGETConfirmed: persistedGET
        )
    }

    private static func snapshot() -> TodoSnapshot {
        TodoSnapshot(
            stats: TodoStatsDTO(pendingTasks: 2, dueToday: 1, overdueTasks: 1),
            tasks: [
                TodoTaskDTO(id: 1, title: "Persist me", status: "todo", priority: "high", dueDate: "2026-07-11", dueTime: "09:00:00", overdue: true, dueToday: true),
                TodoTaskDTO(id: 2, title: "Keep me", status: "todo", priority: "normal", dueDate: nil, dueTime: nil, overdue: false, dueToday: false)
            ]
        )
    }

    @MainActor
    private static func waitUntilIdle(_ controller: TodoMutationController, taskID: Int64) async {
        for _ in 0..<100 {
            if controller.isMutating(taskID: taskID) == false { return }
            await Task.yield()
        }
    }
}

private final class TodoMutationProbeRepository: TodoRepositoryProtocol {
    let original: TodoSnapshot
    var nextCompletionError: Error?
    private(set) var completionCalls = 0
    private(set) var fetchCalls = 0
    private(set) var persistedCompletedIDs = Set<Int64>()
    init(original: TodoSnapshot) { self.original = original }

    func completeTask(id: Int64) async throws {
        completionCalls += 1
        if let error = nextCompletionError {
            nextCompletionError = nil
            throw error
        }
        persistedCompletedIDs.insert(id)
    }

    func fetchSnapshot() async throws -> TodoSnapshot {
        fetchCalls += 1
        var result = original
        result.tasks.removeAll { persistedCompletedIDs.contains($0.id) }
        result.pendingTasks = result.tasks.count
        result.dueToday = result.tasks.filter(\.isDueToday).count
        result.overdueTasks = result.tasks.filter(\.isOverdue).count
        return result
    }
}
