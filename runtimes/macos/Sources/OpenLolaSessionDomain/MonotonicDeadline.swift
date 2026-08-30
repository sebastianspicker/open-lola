// Tracks MonotonicDeadline monotonic deadlines, centralizing timeout comparisons for callers that must not use wall-clock time.
import Dispatch
import Foundation

public struct MonotonicDeadline: Sendable {
    private let deadline: DispatchTime

    public init(seconds: TimeInterval) {
        deadline = .now() + Self.interval(seconds: seconds)
    }

    public init(uptimeNanoseconds: UInt64) {
        deadline = DispatchTime(uptimeNanoseconds: uptimeNanoseconds)
    }

    public var hasTimeRemaining: Bool {
        DispatchTime.now() < deadline
    }

    public var remainingSeconds: TimeInterval {
        let now = DispatchTime.now().uptimeNanoseconds
        guard deadline.uptimeNanoseconds > now else {
            return 0
        }
        return TimeInterval(deadline.uptimeNanoseconds - now) / 1_000_000_000
    }

    private static func interval(seconds: TimeInterval) -> DispatchTimeInterval {
        let boundedSeconds = max(0, seconds)
        let nanoseconds = (boundedSeconds * 1_000_000_000).rounded(.up)
        guard nanoseconds < Double(Int.max) else {
            return .nanoseconds(Int.max)
        }
        return .nanoseconds(Int(nanoseconds))
    }
}
