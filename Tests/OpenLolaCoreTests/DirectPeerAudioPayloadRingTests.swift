import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func directPeerAudioPayloadRingPreservesOrderAndReportsFullEmpty() {
    let ring = DirectPeerAudioPayloadRing(capacity: 2, payloadByteCount: 4, frameCount: 2)
    #expect(capturedPayloadData(from: ring) == nil)
    let first = Data([1, 2, 3, 4])
    let second = Data([5, 6, 7, 8])
    let third = Data([9, 10, 11, 12])

    #expect(first.withUnsafeBytes { ring.push(startFrame: 0, hostTimeNanoseconds: 10, sourceBytes: $0) } == .stored)
    #expect(second.withUnsafeBytes { ring.push(startFrame: 2, hostTimeNanoseconds: 20, sourceBytes: $0) } == .stored)
    #expect(third.withUnsafeBytes { ring.push(startFrame: 4, hostTimeNanoseconds: 30, sourceBytes: $0) } == .full)
    #expect(capturedPayloadData(from: ring) == first)
    #expect(capturedPayloadData(from: ring) == second)
    #expect(capturedPayloadData(from: ring) == nil)
}

@Test
func directPeerAudioPayloadRingPreservesPayloadsWithConcurrentProducerConsumer() {
    let ring = DirectPeerAudioPayloadRing(capacity: 64, payloadByteCount: 8, frameCount: 2)
    let totalValues = 2_000
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)
    let consumed = UInt64PayloadRecorder(capacity: totalValues)

    DispatchQueue.global(qos: .userInitiated).async {
        for value in 0..<totalValues {
            var encoded = UInt64(value).littleEndian
            while withUnsafeBytes(of: &encoded, {
                ring.push(
                    startFrame: UInt64(value * 2),
                    hostTimeNanoseconds: UInt64(value),
                    sourceBytes: $0
                )
            }) == .full {
                sched_yield()
            }
        }
        producerDone.signal()
    }

    DispatchQueue.global(qos: .userInitiated).async {
        while consumed.count < totalValues {
            if let value = nextUInt64Payload(from: ring) {
                consumed.append(value)
            } else {
                sched_yield()
            }
        }
        consumerDone.signal()
    }

    #expect(producerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumed.snapshot() == (0..<totalValues).map(UInt64.init))
    #expect(ring.ownerViolationCount == 0)
}

@Test
func directPeerAudioPayloadRingProvidesMetadataAndSelectiveReleaseBehavior() {
    let ring = DirectPeerAudioPayloadRing(capacity: 4, payloadByteCount: 4, frameCount: 2)
    let first = Data([1, 2, 3, 4])
    let second = Data([5, 6, 7, 8])
    let third = Data([9, 10, 11, 12])

    #expect(first.withUnsafeBytes {
        ring.push(startFrame: 10, hostTimeNanoseconds: 100, sourceBytes: $0)
    } == .stored)
    #expect(second.withUnsafeBytes {
        ring.push(startFrame: 12, hostTimeNanoseconds: 120, sourceBytes: $0)
    } == .stored)
    #expect(third.withUnsafeBytes {
        ring.push(startFrame: 14, hostTimeNanoseconds: 140, sourceBytes: $0)
    } == .stored)
    #expect(ring.peekStartFrame() == 10)

    let popped = ring.withPoppedPayload { block, payload in
        #expect(block.startFrame == 10)
        #expect(block.frameCount == 2)
        #expect(block.payloadByteCount == 4)
        #expect(block.hostTimeNanoseconds == 100)
        return Data(payload)
    }
    #expect(popped == first)
    #expect(ring.peekStartFrame() == 12)

    var copiedThird = [UInt8](repeating: 0, count: 4)
    #expect(copiedThird.withUnsafeMutableBytes { destination in
        ring.copyPayload(
            startFrame: 14,
            to: destination.baseAddress!,
            byteCount: destination.count
        )
    })
    #expect(Data(copiedThird) == third)
    #expect(ring.peekStartFrame() == 12)
    #expect(ring.dropPayloads(before: 14) == 1)
    #expect(ring.peekStartFrame() == nil)
}

private func capturedPayloadData(from ring: DirectPeerAudioPayloadRing) -> Data? {
    ring.withPoppedPayload { _, payload in
        Data(payload)
    }
}

private func nextUInt64Payload(from ring: DirectPeerAudioPayloadRing) -> UInt64? {
    ring.withPoppedPayload { _, payload in
        payload.load(as: UInt64.self).littleEndian
    }
}

private final class UInt64PayloadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64]

    init(capacity: Int) {
        values = []
        values.reserveCapacity(capacity)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    func append(_ value: UInt64) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

private final class SPSCAtomicRingResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: SPSCAtomicRingResult?

    var value: SPSCAtomicRingResult? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func store(_ value: SPSCAtomicRingResult) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}

private final class OptionalDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Data?

    var value: Data? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func store(_ value: Data?) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}
