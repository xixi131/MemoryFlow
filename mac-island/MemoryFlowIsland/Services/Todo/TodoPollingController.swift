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
    enum Cadence: TimeInterval, Equatable {
        case activeTodo = 10
        case background = 60
    }

    private let repository: TodoRepositoryProtocol
    private let clock: TodoPollingClock
    private let onSnapshot: @MainActor (TodoSnapshot) -> Void
    private var timer: TodoPollingCancellation?
    private var fetchTask: Task<Void, Never>?
    private var lastSuccessfulSnapshot: TodoSnapshot?
    private(set) var isRunning = false
    private(set) var isFetching = false
    private(set) var cadence: Cadence = .background
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

    func start(cadence: Cadence = .background) {
        let wasRunning = isRunning
        isRunning = true
        setCadence(cadence)
        if wasRunning == false {
            fetchIfIdle()
        }
    }

    func setCadence(_ cadence: Cadence) {
        guard self.cadence != cadence || timer == nil else { return }
        self.cadence = cadence
        timer?.cancel()
        timer = nil
        guard isRunning else { return }
        timer = clock.schedule(every: cadence.rawValue) { [weak self] in
            Task { @MainActor in self?.fetchIfIdle() }
        }
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
            defer {
                isFetching = false
                fetchTask = nil
            }
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
        }
    }

    func refresh() {
        fetchIfIdle()
    }

    func acceptRefreshedSnapshot(_ snapshot: TodoSnapshot) {
        guard isRunning else { return }
        lastSuccessfulSnapshot = snapshot
    }
}
