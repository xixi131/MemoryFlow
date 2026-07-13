import Foundation

protocol ReviewPollingCancellation: AnyObject {
    func cancel()
}
protocol ReviewPollingClock {
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> ReviewPollingCancellation
}

private final class DispatchReviewPollingCancellation: ReviewPollingCancellation {
    private let source: DispatchSourceTimer
    init(source: DispatchSourceTimer) { self.source = source }
    func cancel() { source.cancel() }
}

struct DispatchReviewPollingClock: ReviewPollingClock {
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> ReviewPollingCancellation {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: action)
        source.resume()
        return DispatchReviewPollingCancellation(source: source)
    }
}

@MainActor
final class ReviewPollingController {
    private let repository: ReviewRepositoryProtocol
    private let clock: ReviewPollingClock
    private let onSnapshot: @MainActor (ReviewSnapshot) -> Void
    private var timer: ReviewPollingCancellation?
    private var fetchTask: Task<Void, Never>?
    private(set) var isRunning = false
    private(set) var isFetching = false
    private var lastSuccessfulSnapshot: ReviewSnapshot?
    var onAuthenticationInvalidated: @MainActor () -> Void = {}

    init(
        repository: ReviewRepositoryProtocol,
        clock: ReviewPollingClock = DispatchReviewPollingClock(),
        onSnapshot: @escaping @MainActor (ReviewSnapshot) -> Void
    ) {
        self.repository = repository
        self.clock = clock
        self.onSnapshot = onSnapshot
    }

    func start() {
        guard isRunning == false else { return }
        isRunning = true
        timer = clock.schedule(every: 30) { [weak self] in
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
                let snapshot = try await repository.fetchSummary()
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
