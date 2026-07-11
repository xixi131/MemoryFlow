import Foundation

struct ReviewPollingProbeResult: Equatable {
    let fetchCount: Int
    let preventedOverlap: Bool
    let stalePreserved: Bool
    let recoveryClearedStale: Bool
    let authInvalidations: Int
    let logoutCancelled: Bool
    let reloginRestarted: Bool
    let deliveredOnMainActor: Bool
}

enum ReviewPollingProbe {
    @MainActor
    static func run() async throws -> ReviewPollingProbeResult {
        let repository = ReviewPollingProbeRepository()
        let clock = ManualReviewPollingClock()
        var delivered: [ReviewSnapshot] = []
        var mainActorDelivery = true
        let controller = ReviewPollingController(repository: repository, clock: clock) { snapshot in
            mainActorDelivery = mainActorDelivery && Thread.isMainThread
            delivered.append(snapshot)
        }
        var invalidations = 0
        controller.onAuthenticationInvalidated = { invalidations += 1 }

        repository.enqueue(.success(snapshot(1)))
        controller.start()
        await settle()
        repository.enqueue(.success(snapshot(2)))
        clock.fire()
        await settle()
        repository.enqueue(.success(snapshot(3)))
        clock.fire()
        await settle()

        repository.enqueue(.slow(snapshot(4)))
        clock.fire()
        await settle()
        let beforeOverlap = repository.fetchCount
        clock.fire()
        await settle()
        let preventedOverlap = repository.fetchCount == beforeOverlap
        repository.releaseSlowRequest()
        await settle()

        repository.enqueue(.failure(URLError(.notConnectedToInternet)))
        clock.fire()
        await settle()
        let stalePreserved = delivered.last?.isStale == true && delivered.last?.totalPendingReviews == 4

        repository.enqueue(.success(snapshot(5)))
        clock.fire()
        await settle()
        let recoveryCleared = delivered.last?.isStale == false && delivered.last?.totalPendingReviews == 5

        repository.enqueue(.failure(APIClientError.transportStatus(401)))
        clock.fire()
        await settle()

        controller.stop()
        let stoppedCount = repository.fetchCount
        clock.fire()
        await settle()
        let logoutCancelled = repository.fetchCount == stoppedCount

        repository.enqueue(.success(snapshot(6)))
        controller.start()
        await settle()
        let reloginRestarted = repository.fetchCount == stoppedCount + 1
        controller.stop()

        return ReviewPollingProbeResult(
            fetchCount: repository.fetchCount,
            preventedOverlap: preventedOverlap,
            stalePreserved: stalePreserved,
            recoveryClearedStale: recoveryCleared,
            authInvalidations: invalidations,
            logoutCancelled: logoutCancelled,
            reloginRestarted: reloginRestarted,
            deliveredOnMainActor: mainActorDelivery
        )
    }

    private static func snapshot(_ count: Int) -> ReviewSnapshot {
        ReviewSnapshot(dto: WidgetSummaryDTO(
            totalPendingReviews: count,
            totalCompletedToday: count,
            reminderTime: "20:00",
            subjects: []
        ))
    }

    private static func settle() async {
        for _ in 0..<8 { await Task.yield() }
    }
}

private final class ManualReviewPollingClock: ReviewPollingClock {
    private final class Token: ReviewPollingCancellation {
        var action: (() -> Void)?
        func cancel() { action = nil }
    }
    private var token: Token?
    func schedule(every interval: TimeInterval, _ action: @escaping () -> Void) -> ReviewPollingCancellation {
        let token = Token()
        token.action = action
        self.token = token
        return token
    }
    func fire() { token?.action?() }
}

private final class ReviewPollingProbeRepository: ReviewRepositoryProtocol {
    enum Outcome { case success(ReviewSnapshot), slow(ReviewSnapshot), failure(Error) }
    private var outcomes: [Outcome] = []
    private var slowContinuation: CheckedContinuation<Void, Never>?
    private(set) var fetchCount = 0
    func enqueue(_ outcome: Outcome) { outcomes.append(outcome) }
    func releaseSlowRequest() { slowContinuation?.resume(); slowContinuation = nil }
    func fetchSummary() async throws -> ReviewSnapshot {
        fetchCount += 1
        let outcome = outcomes.removeFirst()
        switch outcome {
        case .success(let snapshot): return snapshot
        case .failure(let error): throw error
        case .slow(let snapshot):
            await withCheckedContinuation { slowContinuation = $0 }
            return snapshot
        }
    }
}
