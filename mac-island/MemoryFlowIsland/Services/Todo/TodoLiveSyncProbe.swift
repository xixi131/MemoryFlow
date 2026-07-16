import Foundation

struct TodoLiveSyncProbeResult: Equatable, CustomStringConvertible {
    let paths: [String]
    let taskIDs: [Int64]
    let counts: [Int]
    let kinds: [IslandPreviewContent.Kind]
    let pollingFetches: Int
    let overlapPrevented: Bool
    let recovered: Bool
    let cancelled: Bool
    let cadences: [TimeInterval]
    let lifecycleRefreshes: Bool
    let completionRefresh: Bool
    let relaunched: Bool
    let duplicateTimersPrevented: Bool

    var description: String {
        "todo-live-sync-probe: PASS; cadence=\(cadences.map { String(Int($0)) }.joined(separator: ",")); lifecycle=\(lifecycleRefreshes); overlap=\(overlapPrevented); recovery=\(recovered); completion=\(completionRefresh); relaunch=\(relaunched); cleanup=\(cancelled); duplicate-timers=\(duplicateTimersPrevented)"
    }
}

struct TodoDataFidelityProbeResult: Equatable, CustomStringConvertible {
    let descriptions: [String]
    let priorities: [String]
    let dueTexts: [String]

    var description: String {
        "todo-data-fidelity-probe: PASS; descriptions=\(descriptions.count); priorities=\(priorities.joined(separator: ",")); due=\(dueTexts.joined(separator: ","))"
    }
}

struct TodoDetailProbeResult: Equatable, CustomStringConvertible {
    let opened: Bool
    let returned: Bool
    let deletedFallback: Bool
    let longDescriptionLength: Int
    let missingFallbacks: [String]

    var description: String {
        "todo-detail-probe: PASS; opened=\(opened); returned=\(returned); deleted-fallback=\(deletedFallback); long-description=\(longDescriptionLength); missing=\(missingFallbacks.joined(separator: ",")); hit-regions=checkbox-only-completion+body-detail"
    }
}

enum TodoDetailProbe {
    static func run() throws -> TodoDetailProbeResult {
        let longDescription = Array(repeating: "Long detail content", count: 30).joined(separator: " ")
        let longTask = IslandMockTodoTask(
            id: "long",
            title: "A title that remains readable in the expanded detail view",
            descriptionMd: longDescription,
            priority: .high,
            dueDate: "2026-07-20",
            dueTime: "14:35:00",
            isCompleted: false,
            isDueToday: false,
            isOverdue: false
        )
        let missingTask = IslandMockTodoTask(
            id: "missing",
            title: "Missing metadata",
            priority: .none,
            isCompleted: true,
            isDueToday: false,
            isOverdue: false
        )
        var state = IslandDomainState.mockExpandedTodo
        state.mockSources.todo = IslandMockTodoActivity(
            pendingCount: 1,
            dueTodayCount: 0,
            overdueCount: 0,
            nextTaskTitle: longTask.title,
            tasks: [longTask, missingTask]
        )

        let opened = IslandPresentationReducer.reduce(current: state, intent: .todoDetailRequested("long"))
        let openedDerived = opened.derivedState
        let longPresentation = openedDerived.previewContent.todoDetail!
        guard opened.reason == .todoDetailPresented,
              opened.state.selectedTodoTaskID == "long",
              openedDerived.previewContent.kind == .expandedTodoDetail,
              longPresentation.descriptionText == longDescription,
              longPresentation.priorityText == "紧急",
              longPresentation.dateText == "2026-07-20",
              longPresentation.timeText == "14:35" else {
            throw TodoDetailProbeError.openFailed(
                reason: opened.reason.rawValue,
                selectedID: opened.state.selectedTodoTaskID,
                kind: openedDerived.previewContent.kind.rawValue
            )
        }

        let returned = IslandPresentationReducer.reduce(current: opened.state, intent: .todoDetailDismissed)
        guard returned.reason == .todoDetailDismissed,
              returned.state.selectedTodoTaskID == nil,
              returned.derivedState.previewContent.kind == .expandedTodo else {
            throw TodoDetailProbeError.returnFailed(
                reason: returned.reason.rawValue,
                selectedID: returned.state.selectedTodoTaskID,
                kind: returned.derivedState.previewContent.kind.rawValue
            )
        }

        let missing = IslandPresentationReducer.reduce(current: state, intent: .todoDetailRequested("missing"))
        let missingPresentation = missing.derivedState.previewContent.todoDetail!
        guard missingPresentation.descriptionText == "暂无描述",
              missingPresentation.priorityText == "未设置",
              missingPresentation.dateText == "未设置",
              missingPresentation.timeText == "未设置",
              missingPresentation.statusText == "已完成",
              IslandTodoRowHitRegion.action(for: .checkbox) == .completion,
              IslandTodoRowHitRegion.action(for: .body) == .detail else {
            throw TodoDetailProbeError.missingMetadataFailed
        }

        var deletedState = opened.state
        deletedState.mockSources.todo?.tasks.removeAll { $0.id == "long" }
        let deletedFallback = IslandDerivedState.derive(from: deletedState).previewContent.kind == .expandedTodo
        guard deletedFallback else { throw TodoDetailProbeError.deletedFallbackFailed }

        return TodoDetailProbeResult(
            opened: true,
            returned: true,
            deletedFallback: true,
            longDescriptionLength: longPresentation.descriptionText.count,
            missingFallbacks: [
                missingPresentation.descriptionText,
                missingPresentation.priorityText,
                missingPresentation.dateText,
                missingPresentation.timeText
            ]
        )
    }
}

enum TodoDetailProbeError: Error, CustomStringConvertible {
    case openFailed(reason: String, selectedID: String?, kind: String)
    case returnFailed(reason: String, selectedID: String?, kind: String)
    case missingMetadataFailed
    case deletedFallbackFailed

    var description: String {
        switch self {
        case let .openFailed(reason, selectedID, kind):
            return "open failed: reason=\(reason), selected=\(selectedID ?? "nil"), kind=\(kind)"
        case let .returnFailed(reason, selectedID, kind):
            return "return failed: reason=\(reason), selected=\(selectedID ?? "nil"), kind=\(kind)"
        case .missingMetadataFailed:
            return "missing metadata or hit-region validation failed"
        case .deletedFallbackFailed:
            return "deleted selected task did not fall back to list"
        }
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
        let orchestrator = TodoLiveSyncOrchestrator(pollingController: poller)
        orchestrator.setCapabilityEnabled(true)
        orchestrator.setAuthenticated(true)
        await waitUntilIdle(poller)
        let backgroundCadence = clock.intervals == [60]

        orchestrator.setTodoModeActive(true)
        await waitUntilIdle(poller)
        let activeCadence = clock.intervals == [60, 10]
        let scheduledBeforeDuplicate = clock.intervals.count
        orchestrator.setTodoModeActive(true)
        let duplicateCadenceIgnored = clock.intervals.count == scheduledBeforeDuplicate

        let beforeLifecycle = pollingRepository.fetchCount
        orchestrator.refreshForApplicationActivation()
        await waitUntilIdle(poller)
        orchestrator.refreshForWake()
        await waitUntilIdle(poller)
        let lifecycleRefreshes = pollingRepository.fetchCount == beforeLifecycle + 2

        pollingRepository.shouldBlock = true
        orchestrator.refreshForApplicationActivation()
        await settle()
        let beforeOverlap = pollingRepository.fetchCount
        orchestrator.refreshForWake()
        await settle()
        let overlap = pollingRepository.fetchCount == beforeOverlap
        pollingRepository.release(); await waitUntilIdle(poller)

        pollingRepository.shouldFail = true
        orchestrator.refreshForApplicationActivation()
        await waitUntilIdle(poller)
        let stale = delivered.last?.isStale == true
        pollingRepository.shouldFail = false
        orchestrator.refreshForWake()
        await waitUntilIdle(poller)
        let recovered = stale && delivered.last?.isStale == false

        var mutationDelivered: [TodoSnapshot] = []
        var completionCallbacks = 0
        let mutationController = TodoMutationController(repository: pollingRepository) {
            mutationDelivered.append($0)
        }
        mutationController.acceptSnapshot(snapshot)
        mutationController.onCompletionSucceeded = { refreshed in
            completionCallbacks += 1
            orchestrator.acceptCompletionRefresh(refreshed)
        }
        mutationController.complete(taskID: 1)
        await waitUntilIdle(mutationController, taskID: 1)
        pollingRepository.shouldFail = true
        orchestrator.refreshForApplicationActivation()
        await waitUntilIdle(poller)
        let completionRefresh = completionCallbacks == 1 &&
            pollingRepository.completionCount == 1 &&
            mutationDelivered.last?.tasks.contains(where: { $0.id == 1 }) == false &&
            delivered.last?.isStale == true &&
            delivered.last?.tasks.contains(where: { $0.id == 1 }) == false
        pollingRepository.shouldFail = false
        orchestrator.refreshForWake()
        await waitUntilIdle(poller)

        orchestrator.stop()
        let stopped = pollingRepository.fetchCount
        clock.fire(); await settle()
        let firstCleanup = pollingRepository.fetchCount == stopped && clock.activeTimerCount == 0

        let relaunchedOrchestrator = TodoLiveSyncOrchestrator(pollingController: poller)
        relaunchedOrchestrator.setCapabilityEnabled(true)
        relaunchedOrchestrator.setAuthenticated(true)
        await waitUntilIdle(poller)
        let relaunched = pollingRepository.fetchCount == stopped + 1 && clock.intervals.last == 60
        relaunchedOrchestrator.setAuthenticated(false)
        let cleanedUp = pollingRepository.fetchCount
        clock.fire(); await settle()
        let cancelled = firstCleanup && pollingRepository.fetchCount == cleanedUp && clock.activeTimerCount == 0
        let duplicateTimersPrevented = duplicateCadenceIgnored && clock.maximumActiveTimerCount == 1

        guard backgroundCadence,
              activeCadence,
              lifecycleRefreshes,
              overlap,
              recovered,
              completionRefresh,
              relaunched,
              cancelled,
              duplicateTimersPrevented else {
            throw APIClientError.decodingFailed
        }

        return TodoLiveSyncProbeResult(
            paths: transport.paths.sorted(),
            taskIDs: snapshot.tasks.map(\.id),
            counts: [snapshot.pendingTasks, snapshot.dueToday, snapshot.overdueTasks],
            kinds: kinds,
            pollingFetches: pollingRepository.fetchCount,
            overlapPrevented: overlap,
            recovered: recovered,
            cancelled: cancelled,
            cadences: clock.intervals,
            lifecycleRefreshes: backgroundCadence && activeCadence && lifecycleRefreshes,
            completionRefresh: completionRefresh,
            relaunched: relaunched,
            duplicateTimersPrevented: duplicateTimersPrevented
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

    @MainActor
    private static func waitUntilIdle(_ controller: TodoMutationController, taskID: Int64) async {
        for _ in 0..<100 {
            if controller.isMutating(taskID: taskID) == false { return }
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
    private final class Token: TodoPollingCancellation {
        var action: (() -> Void)?
        let onCancel: () -> Void
        init(action: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self.action = action
            self.onCancel = onCancel
        }
        func cancel() {
            guard action != nil else { return }
            action = nil
            onCancel()
        }
    }
    private var token: Token?
    private(set) var intervals: [TimeInterval] = []
    private(set) var activeTimerCount = 0
    private(set) var maximumActiveTimerCount = 0
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> TodoPollingCancellation {
        intervals.append(interval)
        activeTimerCount += 1
        maximumActiveTimerCount = max(maximumActiveTimerCount, activeTimerCount)
        let token = Token(action: action) { [weak self] in self?.activeTimerCount -= 1 }
        self.token = token
        return token
    }
    func fire() { token?.action?() }
}

private final class TodoPollingProbeRepository: TodoRepositoryProtocol {
    private var snapshot: TodoSnapshot
    var shouldFail = false
    var shouldBlock = false
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0
    private(set) var completionCount = 0
    init(snapshot: TodoSnapshot) { self.snapshot = snapshot }
    func fetchSnapshot() async throws -> TodoSnapshot {
        fetchCount += 1
        if shouldBlock { await withCheckedContinuation { continuation = $0 } }
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return snapshot
    }
    func completeTask(id: Int64) async throws {
        completionCount += 1
        snapshot.tasks.removeAll { $0.id == id }
        snapshot.pendingTasks = snapshot.tasks.count
        snapshot.dueToday = snapshot.tasks.filter(\.isDueToday).count
        snapshot.overdueTasks = snapshot.tasks.filter(\.isOverdue).count
    }
    func release() { shouldBlock = false; continuation?.resume(); continuation = nil }
}
