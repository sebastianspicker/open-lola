// Tracks UltraGridMediaDeadline monotonic deadlines, centralizing timeout comparisons for the media loop.
import Dispatch
import Foundation

func ultraGridExpectedFullDuplexReceiveCount(
    requestedDatagrams: Int,
    transmitResult: Result<UltraGridCompatibilityTransmitResult, Error>?
) -> Int? {
    if requestedDatagrams > 0 {
        return requestedDatagrams
    }
    guard case let .success(result)? = transmitResult else {
        return nil
    }
    return result.attemptedDatagramCount
}

func ultraGridReceiveDeadlineNanoseconds(
    nowNanoseconds: UInt64,
    timeoutSeconds: Int
) -> UInt64 {
    let timeout = UInt64(max(1, timeoutSeconds)).multipliedReportingOverflow(by: 1_000_000_000)
    let timeoutNanoseconds = timeout.overflow ? UInt64.max : timeout.partialValue
    let deadline = nowNanoseconds.addingReportingOverflow(timeoutNanoseconds)
    return deadline.overflow ? UInt64.max : deadline.partialValue
}

private func ultraGridReceiveDeadlineNanoseconds(timeoutSeconds: Int) -> UInt64 {
    ultraGridReceiveDeadlineNanoseconds(
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
        timeoutSeconds: timeoutSeconds
    )
}
