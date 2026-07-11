import Foundation

struct ReviewLiveSummaryProbeResult: Equatable {
    let endpoint: String
    let pending: Int
    let completedToday: Int
    let nextSubject: String?
    let verifiedKinds: [IslandPreviewContent.Kind]
}

enum ReviewLiveSummaryProbe {
    static func run() async throws -> ReviewLiveSummaryProbeResult {
        let transport = ReviewSummaryProbeSession()
        let store = InMemoryAuthSessionStore(session: AuthSession(
            accessToken: "review-token",
            refreshToken: "review-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        ))
        let client = try APIClient(
            baseURL: URL(string: "https://api.memoryflow.example")!,
            session: transport,
            tokenProvider: store,
            sessionStore: store
        )
        let snapshot = try await ReviewRepository(apiClient: client).fetchSummary()
        var state = IslandDomainState.loggedInReviewCompact
        state.mockSources.review = nil
        state.reviewSnapshot = snapshot

        let states: [IslandDomainState] = [
            state,
            state.setting(isHovered: true),
            state.setting(presentation: .activity),
            state.setting(presentation: .expanded)
        ]
        let derived = states.map(IslandDerivedState.derive)
        let expectedKinds: [IslandPreviewContent.Kind] = [.reviewCompact, .reviewCompact, .reviewActivity, .expandedReview]
        guard derived.map(\.previewContent.kind) == expectedKinds,
              derived.allSatisfy({ $0.previewContent.review?.pendingCount == 8 }),
              derived.allSatisfy({ $0.previewContent.review?.completedTodayCount == 5 }),
              derived.last?.previewContent.review?.subjectTitles == ["Algorithms", "English"],
              transport.lastPath == "/api/widget/summary" else {
            throw APIClientError.decodingFailed
        }
        return ReviewLiveSummaryProbeResult(
            endpoint: transport.lastPath ?? "",
            pending: snapshot.totalPendingReviews,
            completedToday: snapshot.totalCompletedToday,
            nextSubject: snapshot.nextSubjectTitle,
            verifiedKinds: expectedKinds
        )
    }
}

private extension IslandDomainState {
    func setting(isHovered: Bool) -> IslandDomainState {
        var copy = self
        copy.isHovered = isHovered
        return copy
    }

    func setting(presentation: IslandPresentationState) -> IslandDomainState {
        var copy = self
        copy.presentationState = presentation
        copy.forceCompactMode = false
        return copy
    }
}

private final class ReviewSummaryProbeSession: URLSessioning {
    private(set) var lastPath: String?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastPath = request.url?.path
        let json = """
        {"code":200,"message":"success","data":{"totalPendingReviews":8,"totalCompletedToday":5,"reminderTime":"20:00","subjects":[{"id":1,"title":"Algorithms","icon":"code","colorClass":"blue","progress":40,"pendingReviewCount":3,"lightStatus":"yellow","goalTitle":"CS"},{"id":2,"title":"English","icon":null,"colorClass":null,"progress":70,"pendingReviewCount":0,"lightStatus":"green","goalTitle":null}]},"timestamp":1}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), response)
    }
}
