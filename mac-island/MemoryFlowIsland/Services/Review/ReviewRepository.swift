import Foundation

protocol ReviewRepositoryProtocol: AnyObject {
    func fetchSummary() async throws -> ReviewSnapshot
}
final class ReviewRepository: ReviewRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchSummary() async throws -> ReviewSnapshot {
        let dto: WidgetSummaryDTO = try await apiClient.request(
            "widget/summary",
            authenticated: true
        )
        return ReviewSnapshot(dto: dto)
    }
}
