import Foundation

protocol TodoPollingCancellation: AnyObject { func cancel() }
protocol TodoPollingClock {
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> TodoPollingCancellation
}
private final class DispatchTodoPollingCancellation: TodoPollingCancellation {
    private let source: DispatchSourceTimer
    init(_ source: DispatchSourceTimer) { self.source = source }
    func cancel() { source.cancel() }
}

struct DispatchTodoPollingClock: TodoPollingClock {
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> TodoPollingCancellation {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: action)
        source.resume()
        return DispatchTodoPollingCancellation(source)
    }
}

@MainActor
final class TodoPollingController {
    private let repository: TodoRepositoryProtocol
    private let clock: TodoPollingClock
    private let onSnapshot: @MainActor (TodoSnapshot) -> Void
    private var timer: TodoPollingCancellation?
    private var fetchTask: Task<Void, Never>?
    private var lastSuccessfulSnapshot: TodoSnapshot?
    private(set) var isRunning = false
    private(set) var isFetching = false
    var onAuthenticationInvalidated: @MainActor () -> Void = {}

    init(
        repository: TodoRepositoryProtocol,
        clock: TodoPollingClock = DispatchTodoPollingClock(),
        onSnapshot: @escaping @MainActor (TodoSnapshot) -> Void
    ) {
        self.repository = repository
        self.clock = clock
        self.onSnapshot = onSnapshot
    }

    func start() {
        guard isRunning == false else { return }
        isRunning = true
        timer = clock.schedule(every: 60) { [weak self] in
            Task { @MainActor in self?.fetchIfIdle() }
        }
        fetchIfIdle()
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
        isFetching = false
        lastSuccessfulSnapshot = nil
    }

    func fetchIfIdle() {
        guard isRunning, isFetching == false else { return }
        isFetching = true
        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await repository.fetchSnapshot()
                guard Task.isCancelled == false, isRunning else { return }
                lastSuccessfulSnapshot = snapshot
                onSnapshot(snapshot)
            } catch {
                guard Task.isCancelled == false, isRunning else { return }
                if APIClient.isAuthenticationFailure(error) {
                    onAuthenticationInvalidated()
                } else if let lastSuccessfulSnapshot {
                    onSnapshot(lastSuccessfulSnapshot.markingStale())
                }
            }
            isFetching = false
            fetchTask = nil
        }
    }
}
