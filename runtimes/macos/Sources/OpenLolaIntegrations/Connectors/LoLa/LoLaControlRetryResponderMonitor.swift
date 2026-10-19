// Records errors the background LoLa retry responder hits and decides when it must stop retrying.
import Darwin
import Foundation
import OpenLolaSessionDomain

/// Consecutive transient failures after which the retry responder gives up;
/// a socket that fails this often is broken, and looping on it would spin.
let maxLoLaRetryResponderConsecutiveFailures = 8
/// Ignored control messages kept for the report; later ones are dropped.
let maxLoLaRetryResponderIgnoredMessages = 32
/// Pause after a transient failure so a repeating error cannot busy-loop.
let lolaRetryResponderFailureBackoffMicroseconds: useconds_t = 50_000

/// A failed retry-responder iteration and whether retrying can help.
struct LoLaRetryResponderFailure: Error, CustomStringConvertible {
    var isPermanent: Bool
    var underlying: Error

    var description: String { String(describing: underlying) }
}

/// Thread-safe record of what the retry responder hit after it started, read
/// by the session runner when it writes the report.
final class LoLaControlRetryResponderMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var errorCount = 0
    private var consecutiveFailures = 0
    private var lastError: String?
    private var stopReason: String?
    private var ignoredControlMessages: [String] = []

    func recordSuccess() {
        lock.lock()
        defer { lock.unlock() }
        consecutiveFailures = 0
    }

    /// Records the failure and returns true when the responder must stop.
    func recordFailure(_ failure: LoLaRetryResponderFailure) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        errorCount += 1
        consecutiveFailures += 1
        lastError = failure.description
        if failure.isPermanent {
            stopReason = "permanent error: \(failure.description)"
        } else if consecutiveFailures >= maxLoLaRetryResponderConsecutiveFailures {
            stopReason = "\(consecutiveFailures) consecutive errors, last: \(failure.description)"
        }
        return stopReason != nil
    }

    /// Records a valid control message that the responder does not act on;
    /// the list is bounded so a chatty peer cannot grow the report.
    func recordIgnoredControlMessage(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        guard ignoredControlMessages.count < maxLoLaRetryResponderIgnoredMessages else { return }
        ignoredControlMessages.append(name)
    }

    /// Copies the recorded errors into the report that the session writes.
    func annotate(_ report: LoLaControlRetryResponderReport) -> LoLaControlRetryResponderReport {
        lock.lock()
        defer { lock.unlock() }
        var annotated = report
        if errorCount > 0 {
            annotated.errorCount = errorCount
            annotated.lastError = lastError
        }
        annotated.stopReason = stopReason
        if !ignoredControlMessages.isEmpty {
            annotated.ignoredControlMessages = ignoredControlMessages
        }
        return annotated
    }
}

/// Runs retry-responder iterations until the deadline, cancellation, or a
/// failure the monitor classifies as fatal. Every error is recorded.
func runLoLaControlRetryResponderLoop(
    deadline: MonotonicDeadline,
    isCancelled: () -> Bool,
    monitor: LoLaControlRetryResponderMonitor,
    backoff: () -> Void = { usleep(lolaRetryResponderFailureBackoffMicroseconds) },
    iteration: () throws -> Void
) {
    while deadline.hasTimeRemaining, !isCancelled() {
        do {
            try iteration()
            monitor.recordSuccess()
        } catch {
            let failure = error as? LoLaRetryResponderFailure
                ?? LoLaRetryResponderFailure(isPermanent: false, underlying: error)
            if monitor.recordFailure(failure) { return }
            backoff()
        }
    }
}
