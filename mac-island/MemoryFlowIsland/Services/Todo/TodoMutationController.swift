import Foundation

@MainActor
final class TodoMutationController {
    private let repository: TodoRepositoryProtocol
    private let onSnapshot: @MainActor (TodoSnapshot) -> Void
    private var snapshot: TodoSnapshot?
    private var inFlightTaskIDs = Set<Int64>()
    var onAuthenticationInvalidated: @MainActor () -> Void = {}

    init(repository: TodoRepositoryProtocol, onSnapshot: @escaping @MainActor (TodoSnapshot) -> Void) {
        self.repository = repository
        self.onSnapshot = onSnapshot
    }

    func acceptSnapshot(_ snapshot: TodoSnapshot) {
        self.snapshot = snapshot
        onSnapshot(snapshot)
    }

    func complete(taskID: Int64) {
        guard inFlightTaskIDs.contains(taskID) == false,
              let original = snapshot,
              let optimistic = original.completing(taskID: taskID) else { return }
        inFlightTaskIDs.insert(taskID)
        snapshot = optimistic
        onSnapshot(optimistic)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.completeTask(id: taskID)
                let reconciled = try await repository.fetchSnapshot()
                snapshot = reconciled
                onSnapshot(reconciled)
            } catch {
                snapshot = original
                onSnapshot(original)
                if APIClient.isAuthenticationFailure(error) {
                    onAuthenticationInvalidated()
                }
            }
            inFlightTaskIDs.remove(taskID)
        }
    }

    func cancelAll() {
        inFlightTaskIDs.removeAll()
        snapshot = nil
    }

    func isMutating(taskID: Int64) -> Bool { inFlightTaskIDs.contains(taskID) }
}
