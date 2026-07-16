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

struct TodoDataFidelityProbeResult: Equatable, CustomStringConvertible {
    let descriptions: [String]
    let priorities: [String]
    let dueTexts: [String]

    var description: String {
        "todo-data-fidelity-probe: PASS; descriptions=\(descriptions.count); priorities=\(priorities.joined(separator: ",")); due=\(dueTexts.joined(separator: ","))"
    }
}

enum TodoDataFidelityProbe {
    static func run() throws -> TodoDataFidelityProbeResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 12))!
        let tasks = [
            task(1, "Completed", "high", "2026-07-16", "08:00:00", completed: true),
            task(2, "Overdue", "medium", "2026-07-15", "09:00:00", overdue: true),
            task(3, "Today", "low", "2026-07-16", "09:30:00", dueToday: true),
            task(4, "Tomorrow", "none", "2026-07-17", "10:15:00"),
            task(5, "Later", "high", "2026-07-20", "11:00:00"),
            task(6, "Date only", "medium", "2026-07-21", nil),
            task(7, "No date", "low", nil, nil)
        ]
        let firstActivity = activity(tasks: Array(tasks.prefix(6)))
        let secondActivity = activity(tasks: [tasks[6]])
        let slots = IslandExpandedTodoContentLayout.taskSlots(for: firstActivity, now: now, calendar: calendar)
            + IslandExpandedTodoContentLayout.taskSlots(for: secondActivity, now: now, calendar: calendar)
        let descriptions = tasks.compactMap(\.descriptionMd)
        let priorityTitles = slots.map(\.priority.title)
        let dueTexts = slots.map(\.dueText)

        guard descriptions == (1...7).map { "Description **\($0)**" },
              priorityTitles == ["紧急", "重要", "普通", "未设置", "紧急", "重要", "普通"],
              dueTexts == ["已完成", "已逾期", "今日 09:30", "明日 10:15", "7月20日 11:00", "7月21日", "未设置日期"],
              slots[1].priority == .medium,
              slots[2].priority == .low else {
            throw APIClientError.decodingFailed
        }

        return TodoDataFidelityProbeResult(
            descriptions: descriptions,
            priorities: priorityTitles,
            dueTexts: dueTexts
        )
    }

    private static func task(
        _ id: Int,
        _ title: String,
        _ priority: String,
        _ dueDate: String?,
        _ dueTime: String?,
        completed: Bool = false,
        overdue: Bool = false,
        dueToday: Bool = false
    ) -> IslandMockTodoTask {
        IslandMockTodoTask(
            id: String(id),
            title: title,
            descriptionMd: "Description **\(id)**",
            priority: IslandTodoPriority(apiValue: priority),
            dueDate: dueDate,
            dueTime: dueTime,
            isCompleted: completed,
            isDueToday: dueToday,
            isOverdue: overdue
        )
    }

    private static func activity(tasks: [IslandMockTodoTask]) -> IslandMockTodoActivity {
        IslandMockTodoActivity(
            pendingCount: tasks.filter { !$0.isCompleted }.count,
            dueTodayCount: tasks.filter(\.isDueToday).count,
            overdueCount: tasks.filter(\.isOverdue).count,
            nextTaskTitle: tasks.first(where: { !$0.isCompleted })?.title,
            tasks: tasks
        )
    }
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
              snapshot.tasks.first?.descriptionMd == "Description **1**",
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
        await settle()
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
                "{\"id\":\(id),\"title\":\"Task \(id)\",\"descriptionMd\":\"Description **\(id)**\",\"status\":\"todo\",\"priority\":\"high\",\"dueDate\":\"2026-07-\(10 + id)\",\"dueTime\":\"09:00:00\",\"overdue\":\(id == 1),\"dueToday\":\(id == 2)}"
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
