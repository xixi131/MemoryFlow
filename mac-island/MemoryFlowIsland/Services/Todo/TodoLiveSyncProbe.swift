import Foundation

struct TodoLiveSyncProbeResult: Equatable {
    let paths: [String]
    let taskIDs: [Int64]
    let counts: [Int]
    let kinds: [IslandPreviewContent.Kind]
    let pollingFetches: Int
    let overlapPrevented: Bool
    let recovered: Bool
    let cancelled: Bool
}

enum TodoLiveSyncProbe {
    @MainActor
    static func run() async throws -> TodoLiveSyncProbeResult {
        let transport = TodoEndpointProbeSession()
        let store = InMemoryAuthSessionStore(session: AuthSession(
            accessToken: "todo-token",
            refreshToken: "todo-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        ))
        let client = try APIClient(
            baseURL: URL(string: "https://api.memoryflow.example")!,
            session: transport,
            tokenProvider: store,
            sessionStore: store
        )
        let snapshot = try await TodoRepository(apiClient: client).fetchSnapshot()
        guard snapshot.tasks.map(\.id) == [1, 2, 3, 4, 5, 6],
              snapshot.pendingTasks == 9,
              snapshot.dueToday == 3,
              snapshot.overdueTasks == 2,
              transport.verifiedQuery else {
            throw APIClientError.decodingFailed
        }

        var todoState = IslandDomainState.loggedInTodoCompact
        todoState.mockSources.todo = nil
        todoState.todoSnapshot = snapshot
        let compact = IslandDerivedState.derive(from: todoState)
        var activityState = todoState
        activityState.presentationState = .activity
        activityState.forceCompactMode = false
        let activity = IslandDerivedState.derive(from: activityState)
        var expandedState = todoState
        expandedState.presentationState = .expanded
        expandedState.forceCompactMode = false
        let expanded = IslandDerivedState.derive(from: expandedState)
        var reviewState = todoState
        reviewState.appDisplayMode = .review
        let review = IslandDerivedState.derive(from: reviewState)
        let kinds = [compact, activity, expanded, review].map(\.previewContent.kind)
        guard kinds == [.todoCompact, .todoActivity, .expandedTodo, .reviewCompact],
              activity.previewContent.todo?.tasks.first?.isOverdue == true,
              activity.previewContent.todo?.tasks[1].isDueToday == true else {
            throw APIClientError.decodingFailed
        }

        let pollingRepository = TodoPollingProbeRepository(snapshot: snapshot)
        let clock = ManualTodoPollingClock()
        var delivered: [TodoSnapshot] = []
        let poller = TodoPollingController(repository: pollingRepository, clock: clock) { delivered.append($0) }
        poller.start()
        await settle()
        clock.fire(); await settle()
        clock.fire(); await settle()
        pollingRepository.shouldBlock = true
        clock.fire(); await settle()
        let beforeOverlap = pollingRepository.fetchCount
        clock.fire(); await settle()
        let overlap = pollingRepository.fetchCount == beforeOverlap
        pollingRepository.release(); await waitUntilIdle(poller)
        pollingRepository.shouldFail = true
        clock.fire(); await waitUntilIdle(poller)
        let stale = delivered.last?.isStale == true
        pollingRepository.shouldFail = false
        clock.fire(); await waitUntilIdle(poller)
        let recovered = stale && delivered.last?.isStale == false
        poller.stop()
        let stopped = pollingRepository.fetchCount
        clock.fire(); await settle()

        return TodoLiveSyncProbeResult(
            paths: transport.paths.sorted(),
            taskIDs: snapshot.tasks.map(\.id),
            counts: [snapshot.pendingTasks, snapshot.dueToday, snapshot.overdueTasks],
            kinds: kinds,
            pollingFetches: pollingRepository.fetchCount,
            overlapPrevented: overlap,
            recovered: recovered,
            cancelled: pollingRepository.fetchCount == stopped
        )
    }

    private static func settle() async { for _ in 0..<8 { await Task.yield() } }
    @MainActor
    private static func waitUntilIdle(_ poller: TodoPollingController) async {
        for _ in 0..<100 {
            if poller.isFetching == false { return }
            await Task.yield()
        }
    }
}

private final class TodoEndpointProbeSession: URLSessioning {
    private let lock = NSLock()
    private(set) var paths: [String] = []
    private(set) var verifiedQuery = false
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        lock.withLock { paths.append(url.path) }
        let data: String
        if url.path.hasSuffix("/todos/stats") {
            data = "{\"code\":200,\"message\":\"success\",\"data\":{\"pendingTasks\":9,\"dueToday\":3,\"overdueTasks\":2},\"timestamp\":1}"
        } else {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
            verifiedQuery = values == ["status":"todo", "sortBy":"due", "sortOrder":"asc"]
            let tasks = (1...7).map { id in
                "{\"id\":\(id),\"title\":\"Task \(id)\",\"status\":\"todo\",\"priority\":\"high\",\"dueDate\":\"2026-07-\(10 + id)\",\"dueTime\":\"09:00:00\",\"overdue\":\(id == 1),\"dueToday\":\(id == 2)}"
            }.joined(separator: ",")
            data = "{\"code\":200,\"message\":\"success\",\"data\":[\(tasks)],\"timestamp\":1}"
        }
        return (Data(data.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class ManualTodoPollingClock: TodoPollingClock {
    private final class Token: TodoPollingCancellation { var action: (() -> Void)?; func cancel() { action = nil } }
    private var token: Token?
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> TodoPollingCancellation {
        let token = Token(); token.action = action; self.token = token; return token
    }
    func fire() { token?.action?() }
}

private final class TodoPollingProbeRepository: TodoRepositoryProtocol {
    let snapshot: TodoSnapshot
    var shouldFail = false
    var shouldBlock = false
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0
    init(snapshot: TodoSnapshot) { self.snapshot = snapshot }
    func fetchSnapshot() async throws -> TodoSnapshot {
        fetchCount += 1
        if shouldBlock { await withCheckedContinuation { continuation = $0 } }
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return snapshot
    }
    func release() { shouldBlock = false; continuation?.resume(); continuation = nil }
}
