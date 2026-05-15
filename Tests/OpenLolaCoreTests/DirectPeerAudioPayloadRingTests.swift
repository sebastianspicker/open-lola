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
func directPeerAudioPayloadRingReportsInvalidPayloadShapeSeparatelyFromFull() {
    let ring = DirectPeerAudioPayloadRing(capacity: 1, payloadByteCount: 4, frameCount: 2)
    let short = Data([1, 2])

    #expect(short.withUnsafeBytes { ring.push(startFrame: 0, hostTimeNanoseconds: 10, sourceBytes: $0) } == .invalid)
    #expect(capturedPayloadData(from: ring) == nil)
}

@Test
func directPeerAudioPayloadRingReportsOwnerViolationsWithoutTrapping() {
    let ring = DirectPeerAudioPayloadRing(capacity: 2, payloadByteCount: 4, frameCount: 2)
    let first = Data([1, 2, 3, 4])
    let second = Data([5, 6, 7, 8])
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)
    let producerResult = SPSCAtomicRingResultBox()
    let consumerResult = OptionalDataBox()

    #expect(first.withUnsafeBytes { ring.push(startFrame: 0, hostTimeNanoseconds: 10, sourceBytes: $0) } == .stored)
    DispatchQueue.global(qos: .userInitiated).async {
        producerResult.store(second.withUnsafeBytes {
            ring.push(startFrame: 2, hostTimeNanoseconds: 20, sourceBytes: $0)
        })
        producerDone.signal()
    }
    #expect(producerDone.wait(timeout: .now() + 5) == .success)
    #expect(producerResult.value == .invalid)
    #expect(ring.ownerViolationCount == 1)

    #expect(capturedPayloadData(from: ring) == first)
    #expect(second.withUnsafeBytes { ring.push(startFrame: 2, hostTimeNanoseconds: 20, sourceBytes: $0) } == .stored)
    DispatchQueue.global(qos: .userInitiated).async {
        consumerResult.store(capturedPayloadData(from: ring))
        consumerDone.signal()
    }
    #expect(consumerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumerResult.value == nil)
    #expect(ring.ownerViolationCount == 2)
    #expect(capturedPayloadData(from: ring) == second)
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
func directPeerAudioPayloadRingPushHasSeparatedResponsibilities() throws {
    let source = try readDirectPeerAudioRingRepositoryText(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift"
    )

    #expect(source.contains("private func validatedPushSource"))
    #expect(source.contains("private func reservePushSlot()"))
    #expect(source.contains("private func storePayload("))
    #expect(source.contains("sourceBaseAddress: sourceBaseAddress"))
    #expect(source.contains("producer-to-consumer handoff boundary"))
}

@Test
func directPeerAudioPayloadRingAllocatesFloatAlignedStorage() throws {
    let source = try readDirectPeerAudioRingRepositoryText(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift"
    )

    #expect(source.contains("let directPeerAudioPayloadRingStorageAlignment = max(16, MemoryLayout<Float>.alignment)"))
    #expect(source.contains("alignment: directPeerAudioPayloadRingStorageAlignment"))
    #expect(!source.contains("alignment: MemoryLayout<UInt8>.alignment"))
}

@Test
func directPeerAudioPayloadRingKeepsCrossThreadMetadataOutOfSwiftArrays() throws {
    let source = try readDirectPeerAudioRingRepositoryText(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift"
    )

    #expect(source.contains("UnsafeMutablePointer<UInt64>"))
    #expect(source.contains("UnsafeMutablePointer<OpenLolaAtomicUInt64>"))
    #expect(!source.contains("private var startFrames: [UInt64]"))
    #expect(!source.contains("private var hostTimes: [UInt64]"))
    #expect(!source.contains("private var occupied: [Bool]"))
}

@Test
func directPeerAudioPayloadRingChecksRawPointerAllocationCapacity() throws {
    let source = try readDirectPeerAudioRingRepositoryText(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift"
    )

    #expect(source.contains("DirectPeerAudioPayloadRing storage byte count must not overflow"))
    #expect(source.contains("DirectPeerAudioPayloadRing metadata pointer capacity must not overflow"))
    #expect(source.contains("DirectPeerAudioPayloadRing occupied pointer capacity must not overflow"))
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

private func readDirectPeerAudioRingRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
