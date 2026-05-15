import Darwin
import Dispatch
import Foundation
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
    let totalValues = 10_000
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)
    let consumed = UInt64TestRecorder(capacity: totalValues)

    DispatchQueue.global(qos: .userInitiated).async {
        for value in 0..<totalValues {
            while ring.push(UInt64(value)) == .full {
                sched_yield()
            }
        }
        producerDone.signal()
    }

    DispatchQueue.global(qos: .userInitiated).async {
        while consumed.count < totalValues {
            if let value = ring.pop() {
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
}

@Test
func spscAtomicUInt64RingSourceEnforcesSingleProducerConsumerOwners() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Support/SPSCAtomicRing.swift")
    let atomicsSource = try readRepositoryText("Sources/COpenLolaAtomics/OpenLolaAtomics.c")
    let atomicsHeader = try readRepositoryText("Sources/COpenLolaAtomics/include/OpenLolaAtomics.h")
    let releaseReadinessWorkflow = try readRepositoryText(".github/workflows/release-readiness.yml")

    #expect(source.contains("producerThreadID"))
    #expect(source.contains("consumerThreadID"))
    #expect(source.contains("open_lola_atomic_u64_compare_exchange"))
    #expect(source.contains("requires exactly one producer and one consumer"))
    #expect(source.contains("capacity must preserve SPSC wrap-distance ordering"))
    #expect(source.contains("Unsigned subtraction is intentional"))
    #expect(source.contains("safe only for SPSC ownership"))
    #expect(source.contains("would make the check/use sequence a TOCTOU race"))
    #expect(source.contains("release stores"))
    #expect(source.contains("acquire loads"))
    #expect(source.contains("UnsafeMutableBufferPointer<UInt64>"))
    #expect(!source.contains("private var storage: [UInt64]"))
    #expect(atomicsSource.contains("atomic_load_explicit(&atomic->value, memory_order_acquire)"))
    #expect(atomicsSource.contains("atomic_store_explicit(&atomic->value, value, memory_order_release)"))
    #expect(atomicsHeader.contains("memory_order_acquire"))
    #expect(atomicsHeader.contains("memory_order_release"))
    #expect(releaseReadinessWorkflow.contains("--sanitize=thread"))
    #expect(releaseReadinessWorkflow.contains("SPSCAtomicRing"))
    #expect(releaseReadinessWorkflow.contains("DirectPeerAudioPayloadRing"))
}

private final class UInt64TestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64]

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    init(capacity: Int) {
        self.values = []
        self.values.reserveCapacity(capacity)
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
