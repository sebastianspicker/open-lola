// Covers SPSC atomic-ring contracts used by the real-time media path.
import Dispatch
import Testing

@testable import OpenLolaCore

@Test
func spscAtomicUInt64RingPreservesOrderAndReportsFullEmpty() {
    let ring = SPSCUInt64Ring(capacity: 2)

    #expect(ring.pop() == nil)
    #expect(ring.push(10) == .stored)
    #expect(ring.push(11) == .stored)
    #expect(ring.push(12) == .full)
    #expect(ring.pop() == 10)
    #expect(ring.pop() == 11)
    #expect(ring.pop() == nil)
}

@Test
func spscAtomicUInt64RingPreservesOrderWithConcurrentProducerConsumer() {
    let ring = SPSCUInt64Ring(capacity: 64)
    assertConcurrentUInt64RingPreservesOrder(
        totalValues: 10_000,
        producer: { ring.push($0) },
        consumer: { ring.pop() },
        ownerViolationCount: { ring.ownerViolationCount }
    )
}

@Test
func spscAtomicUInt64RingRejectsOwnerViolationsInReleasePath() {
    let ring = SPSCUInt64Ring(capacity: 2)
    let producerResult = SPSCAtomicRingResultBox(nil)
    let consumerResult = OptionalUInt64ResultBox(nil)
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)

    #expect(ring.push(1) == .stored)
    DispatchQueue.global(qos: .userInitiated).async {
        producerResult.store(ring.push(2))
        producerDone.signal()
    }

    #expect(producerDone.wait(timeout: .now() + 5) == .success)
    #expect(producerResult.value == .invalid)
    #expect(ring.ownerViolationCount == 1)
    #expect(ring.pop() == 1)

    #expect(ring.push(3) == .stored)
    DispatchQueue.global(qos: .userInitiated).async {
        consumerResult.store(ring.pop())
        consumerDone.signal()
    }

    #expect(consumerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumerResult.value == nil)
    #expect(ring.ownerViolationCount == 2)
    #expect(ring.pop() == 3)
}

private typealias OptionalUInt64ResultBox = TestResultBox<UInt64?>
