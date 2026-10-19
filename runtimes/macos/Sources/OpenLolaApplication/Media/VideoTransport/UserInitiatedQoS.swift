// Runs blocking work on a userInitiated dispatch queue so CLI main-thread callers satisfy the video transport QoS guard.
import Dispatch
import Foundation

/// Runs `body` on a userInitiated-QoS queue, blocks until it finishes, and returns its value or throws its error.
///
/// The CLI main thread runs at user-interactive QoS, which video transport work must avoid so audio keeps priority.
public func runAtUserInitiatedQoS<T>(_ body: () throws -> T) throws -> T {
    try withoutActuallyEscaping(body) { escapableBody in
        let task = UserInitiatedTask(escapableBody)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue(label: "open-lola.user-initiated-qos", qos: .userInitiated).async {
            task.run()
            finished.signal()
        }
        finished.wait()
        return try task.outcome()
    }
}

private final class UserInitiatedTask<T>: @unchecked Sendable {
    private let body: () throws -> T
    private var result: Result<T, Error>?

    init(_ body: @escaping () throws -> T) {
        self.body = body
    }

    func run() {
        result = Result { try body() }
    }

    func outcome() throws -> T {
        guard let result else { preconditionFailure("User-initiated task finished without a result.") }
        return try result.get()
    }
}
