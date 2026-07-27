// Provides thread-safe result storage and ordering checks for concurrent ring tests.
import Darwin
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

final class TestResultBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func store(_ value: Value) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&storedValue)
    }
}

typealias SPSCAtomicRingResultBox = TestResultBox<SPSCAtomicRingResult?>

func assertConcurrentUInt64RingPreservesOrder(
    totalValues: Int,
    producer: @escaping @Sendable (UInt64) -> SPSCAtomicRingResult,
    consumer: @escaping @Sendable () -> UInt64?,
    ownerViolationCount: @escaping @Sendable () -> Int
) {
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)
    let consumed = TestResultBox<[UInt64]>([])

    DispatchQueue.global(qos: .userInitiated).async {
        for value in 0..<totalValues {
            while producer(UInt64(value)) == .full {
                sched_yield()
            }
        }
        producerDone.signal()
    }

    DispatchQueue.global(qos: .userInitiated).async {
        while consumed.value.count < totalValues {
            if let value = consumer() {
                consumed.withValue { $0.append(value) }
            } else {
                sched_yield()
            }
        }
        consumerDone.signal()
    }

    #expect(producerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumed.value == (0..<totalValues).map(UInt64.init))
    #expect(ownerViolationCount() == 0)
}
