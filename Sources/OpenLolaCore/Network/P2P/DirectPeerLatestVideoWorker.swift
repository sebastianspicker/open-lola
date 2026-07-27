// Runs latest-only video work on a serial queue while accounting for every superseded frame.
import Foundation

final class DirectPeerLatestVideoWorker<Request, Output>: @unchecked Sendable {
    typealias Operation = @Sendable (Request) throws -> Output

    struct Completion {
        var request: Request
        var result: Result<Output, Error>
    }

    private struct PendingRequest {
        var generation: UInt64
        var request: Request
    }

    private let queue: DispatchQueue
    private let lock = NSLock()
    private let readinessSignal = DirectPeerCaptureReadinessSignal()
    private let operation: Operation
    private var latestGeneration: UInt64 = 0
    private var pending: PendingRequest?
    private var completion: Completion?
    private var inFlightGeneration: UInt64?
    private var workerScheduled = false
    private var droppedFrames = 0
    private var cancelled = false

    init(queueLabel: String, operation: @escaping Operation) {
        queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
        self.operation = operation
    }

    var readinessDescriptor: Int32? { readinessSignal?.readDescriptor }

    func submitLatest(_ request: Request) {
        let shouldSchedule: Bool
        lock.lock()
        if cancelled {
            shouldSchedule = false
        } else {
            latestGeneration = latestGeneration == UInt64.max ? 1 : latestGeneration + 1
            if pending != nil {
                recordDroppedFrameLocked()
            }
            if completion != nil {
                recordDroppedFrameLocked()
            }
            pending = PendingRequest(generation: latestGeneration, request: request)
            completion = nil
            shouldSchedule = !workerScheduled
            workerScheduled = true
        }
        lock.unlock()
        if shouldSchedule {
            scheduleNext()
        }
    }

    func takeCompletion() -> Completion? {
        readinessSignal?.drain()
        lock.lock()
        let completion = self.completion
        self.completion = nil
        lock.unlock()
        return completion
    }

    func takeDroppedFrameCount() -> Int {
        lock.lock()
        let dropped = droppedFrames
        droppedFrames = 0
        lock.unlock()
        return dropped
    }

    func cancel() {
        _ = cancelAndTakeDroppedFrameCount()
    }

    func cancelAndTakeDroppedFrameCount() -> Int {
        lock.lock()
        if !cancelled {
            if pending != nil {
                recordDroppedFrameLocked()
            }
            if completion != nil {
                recordDroppedFrameLocked()
            }
            if inFlightGeneration != nil {
                recordDroppedFrameLocked()
            }
            cancelled = true
        }
        pending = nil
        completion = nil
        let dropped = droppedFrames
        droppedFrames = 0
        lock.unlock()
        readinessSignal?.drain()
        return dropped
    }

    private func scheduleNext() {
        queue.async { [self] in
            processNext()
        }
    }

    private func processNext() {
        lock.lock()
        guard !cancelled, let pending else {
            workerScheduled = false
            lock.unlock()
            return
        }
        self.pending = nil
        inFlightGeneration = pending.generation
        lock.unlock()

        let result = Result { try operation(pending.request) }

        let shouldScheduleAgain: Bool
        var shouldSignal = false
        lock.lock()
        inFlightGeneration = nil
        if !cancelled, pending.generation == latestGeneration {
            completion = Completion(request: pending.request, result: result)
            shouldSignal = true
        } else if !cancelled {
            recordDroppedFrameLocked()
        }
        shouldScheduleAgain = !cancelled && self.pending != nil
        if !shouldScheduleAgain {
            workerScheduled = false
        }
        lock.unlock()

        if shouldSignal {
            readinessSignal?.signal()
        }
        if shouldScheduleAgain {
            scheduleNext()
        }
    }

    private func recordDroppedFrameLocked() {
        if droppedFrames < Int.max {
            droppedFrames += 1
        }
    }
}
