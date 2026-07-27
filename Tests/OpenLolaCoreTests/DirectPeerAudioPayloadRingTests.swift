// Verifies that direct peer audio payload ring preserves order and reports full and empty states.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerAudioPayloadRingPreservesOrderAndReportsFullEmpty() {
    let ring = DirectPeerAudioPayloadRing(capacity: 2, payloadByteCount: 4, frameCount: 2)
    #expect(capturedPayloadData(from: ring) == nil)
    let fixtures = directPeerAudioPayloadFixtures()
    let first = fixtures.first
    let second = fixtures.second
    let third = fixtures.third

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
    assertConcurrentUInt64RingPreservesOrder(
        totalValues: 2_000,
        producer: { value in
            var encoded = value.littleEndian
            return withUnsafeBytes(of: &encoded) {
                ring.push(
                    startFrame: value * 2,
                    hostTimeNanoseconds: value,
                    sourceBytes: $0
                )
            }
        },
        consumer: { nextUInt64Payload(from: ring) },
        ownerViolationCount: { ring.ownerViolationCount }
    )
}

@Test
func directPeerAudioPayloadRingProvidesMetadataAndSelectiveReleaseBehavior() {
    let ring = DirectPeerAudioPayloadRing(capacity: 4, payloadByteCount: 4, frameCount: 2)
    let fixtures = directPeerAudioPayloadFixtures()
    let first = fixtures.first
    let second = fixtures.second
    let third = fixtures.third

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

@Test
func directPeerAudioPayloadRingCanDiscardBacklogWhilePreservingNewest() {
    let ring = DirectPeerAudioPayloadRing(capacity: 4, payloadByteCount: 1, frameCount: 1)
    for value in UInt8(1)...UInt8(4) {
        let payload = Data([value])
        #expect(payload.withUnsafeBytes {
            ring.push(
                startFrame: UInt64(value),
                hostTimeNanoseconds: UInt64(value),
                sourceBytes: $0
            )
        } == .stored)
    }

    #expect(ring.dropAllButNewest() == 3)
    #expect(capturedPayloadData(from: ring) == Data([4]))
    #expect(capturedPayloadData(from: ring) == nil)
}

private func capturedPayloadData(from ring: DirectPeerAudioPayloadRing) -> Data? {
    ring.withPoppedPayload { _, payload in
        Data(payload)
    }
}

private struct DirectPeerAudioPayloadFixtures {
    let first: Data
    let second: Data
    let third: Data
}

private func directPeerAudioPayloadFixtures() -> DirectPeerAudioPayloadFixtures {
    DirectPeerAudioPayloadFixtures(
        first: Data([1, 2, 3, 4]),
        second: Data([5, 6, 7, 8]),
        third: Data([9, 10, 11, 12])
    )
}

private func nextUInt64Payload(from ring: DirectPeerAudioPayloadRing) -> UInt64? {
    ring.withPoppedPayload { _, payload in
        payload.load(as: UInt64.self).littleEndian
    }
}
