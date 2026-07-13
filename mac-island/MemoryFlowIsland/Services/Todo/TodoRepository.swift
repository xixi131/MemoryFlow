import Foundation

protocol TodoRepositoryProtocol: AnyObject {
    func fetchSnapshot() async throws -> TodoSnapshot
    func completeTask(id: Int64) async throws
}

extension TodoRepositoryProtocol {
    func completeTask(id: Int64) async throws { throw APIClientError.invalidEndpoint }
}

private struct CompleteTodoTaskRequest: Encodable { let completed: Bool }
final class TodoRepository: TodoRepositoryProtocol {
    private let apiClient: APIClient
    init(apiClient: APIClient) { self.apiClient = apiClient }

    func fetchSnapshot() async throws -> TodoSnapshot {
        async let stats: TodoStatsDTO = apiClient.request("todos/stats", authenticated: true)
        async let tasks: [TodoTaskDTO] = apiClient.request(
            "todos/tasks",
            authenticated: true,
            queryItems: [
                URLQueryItem(name: "status", value: "todo"),
                URLQueryItem(name: "sortBy", value: "due"),
                URLQueryItem(name: "sortOrder", value: "asc")
            ]
        )
        return try await TodoSnapshot(stats: stats, tasks: tasks)
    }

    func completeTask(id: Int64) async throws {
        let _: TodoTaskDTO = try await apiClient.request(
            "todos/tasks/\(id)/status",
            method: .patch,
            body: CompleteTodoTaskRequest(completed: true),
            authenticated: true
        )
    }
}
