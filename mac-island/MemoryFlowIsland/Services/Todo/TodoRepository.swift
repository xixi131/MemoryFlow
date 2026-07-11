import Foundation

protocol TodoRepositoryProtocol: AnyObject {
    func fetchSnapshot() async throws -> TodoSnapshot
}
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
}
