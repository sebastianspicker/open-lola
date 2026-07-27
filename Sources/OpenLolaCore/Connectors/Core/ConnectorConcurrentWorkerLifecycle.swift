// Shares the bounded DispatchGroup lifecycle used by one-shot connector workers.
import Dispatch

final class ConnectorConcurrentWorkerLifecycle: Sendable {
    private let group = DispatchGroup()

    func start(_ worker: @escaping @Sendable () -> Void) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.group.leave() }
            worker()
        }
    }

    func wait(untilNanoseconds deadlineNanoseconds: UInt64) -> DispatchTimeoutResult {
        group.wait(timeout: DispatchTime(uptimeNanoseconds: deadlineNanoseconds))
    }
}
