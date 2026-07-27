// Implements DirectPeerAudioPayloadRing bounded buffering, isolating real-time ownership rules from audio and network loops.
import COpenLolaAtomics
import Foundation

let payloadRingStorageAlignment = max(16, MemoryLayout<Float>.alignment)

/// Bounds captured payload slots so producer pressure cannot add unbounded callback-path latency.
public final class DirectPeerAudioPayloadRing: @unchecked Sendable {
    public let capacity: Int
    public let payloadByteCount: Int
    public let frameCount: Int

    private var storage: UnsafeMutableRawPointer
    private var startFrames: UnsafeMutablePointer<UInt64>
    private var hostTimes: UnsafeMutablePointer<UInt64>
    private var occupied: UnsafeMutablePointer<OpenLolaAtomicUInt64>
    private let state: SPSCAtomicRingState

    public init(capacity: Int, payloadByteCount: Int, frameCount: Int) {
        precondition(capacity > 0, "capacity must be positive")
        precondition(payloadByteCount > 0, "payloadByteCount must be positive")
        precondition(frameCount > 0, "frameCount must be positive")
        let storageByteCount = capacity.multipliedReportingOverflow(by: payloadByteCount)
        precondition(
            !storageByteCount.overflow,
            "DirectPeerAudioPayloadRing storage byte count must not overflow"
        )
        let metadataByteCount = capacity.multipliedReportingOverflow(by: MemoryLayout<UInt64>.stride)
        precondition(
            !metadataByteCount.overflow,
            "DirectPeerAudioPayloadRing metadata pointer capacity must not overflow"
        )
        let occupiedByteCount = capacity.multipliedReportingOverflow(
            by: MemoryLayout<OpenLolaAtomicUInt64>.stride
        )
        precondition(
            !occupiedByteCount.overflow,
            "DirectPeerAudioPayloadRing occupied pointer capacity must not overflow"
        )
        self.capacity = capacity
        self.payloadByteCount = payloadByteCount
        self.frameCount = frameCount
        self.state = SPSCAtomicRingState(capacity: capacity)
        self.storage = UnsafeMutableRawPointer.allocate(
            byteCount: storageByteCount.partialValue,
            alignment: payloadRingStorageAlignment
        )
        memset(self.storage, 0, storageByteCount.partialValue)
        self.startFrames = UnsafeMutablePointer<UInt64>.allocate(capacity: capacity)
        self.startFrames.initialize(repeating: 0, count: capacity)
        self.hostTimes = UnsafeMutablePointer<UInt64>.allocate(capacity: capacity)
        self.hostTimes.initialize(repeating: 0, count: capacity)
        self.occupied = UnsafeMutablePointer<OpenLolaAtomicUInt64>.allocate(capacity: capacity)
        for slot in 0..<capacity {
            open_lola_atomic_u64_init(self.occupied.advanced(by: slot), 0)
        }
    }

    public var ownerViolationCount: Int {
        state.ownerViolationCount
    }

    deinit {
        storage.deallocate()
        startFrames.deinitialize(count: capacity)
        startFrames.deallocate()
        hostTimes.deinitialize(count: capacity)
        hostTimes.deallocate()
        occupied.deallocate()
    }

    public func push(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        sourceBytes: UnsafeRawBufferPointer
    ) -> SPSCAtomicRingResult {
        guard state.validateProducer() else {
            return .invalid
        }
        guard let sourceBaseAddress = validatedPushSource(sourceBytes) else {
            return .invalid
        }
        guard let reservation = state.reservePushSlot() else {
            return .full
        }
        storePayload(
            at: reservation.slot,
            nextWriteIndex: reservation.nextWriteIndex,
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            sourceBaseAddress: sourceBaseAddress
        )
        return .stored
    }

    private func validatedPushSource(_ sourceBytes: UnsafeRawBufferPointer) -> UnsafeRawPointer? {
        guard sourceBytes.count >= payloadByteCount else {
            return nil
        }
        return sourceBytes.baseAddress
    }

    private func storePayload(
        at slot: Int,
        nextWriteIndex: UInt64,
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        sourceBaseAddress: UnsafeRawPointer
    ) {
        startFrames[slot] = startFrame
        hostTimes[slot] = hostTimeNanoseconds
        memcpy(storage.advanced(by: slot * payloadByteCount), sourceBaseAddress, payloadByteCount)
        // Publish payload metadata before advancing writeIndex; the release store below is the
        // producer-to-consumer handoff boundary for this SPSC ring.
        open_lola_atomic_u64_store(occupied.advanced(by: slot), 1)
        state.publishWriteIndex(nextWriteIndex)
    }

    public func withPoppedPayload<Result>(
        _ body: (RealtimeAudioFrameBlock, UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result? {
        guard state.validateConsumer() else {
            return nil
        }
        skipReleasedHeadSlots()
        guard let reservation = state.reservePopSlot() else {
            return nil
        }
        let slot = reservation.slot
        guard isOccupied(slot) else {
            return nil
        }
        let block = RealtimeAudioFrameBlock(
            startFrame: startFrames[slot],
            frameCount: frameCount,
            payloadByteCount: payloadByteCount,
            hostTimeNanoseconds: hostTimes[slot]
        )
        defer {
            // Clear occupancy before advancing readIndex so the producer never sees a reusable slot
            // until the consumer has finished reading the payload bytes.
            clearOccupied(slot)
            skipReleasedHeadSlots(startingAt: reservation.readIndex)
        }
        return try body(
            block,
            UnsafeRawBufferPointer(
                start: storage.advanced(by: slot * payloadByteCount),
                count: payloadByteCount
            )
        )
    }

}

extension DirectPeerAudioPayloadRing {
public func copyNextPayload(to destination: UnsafeMutableRawPointer, byteCount: Int) -> Bool {
        guard state.validateConsumer() else {
            return false
        }
        guard byteCount >= payloadByteCount else {
            return false
        }
        skipReleasedHeadSlots()
        guard let reservation = state.reservePopSlot() else {
            return false
        }
        let slot = reservation.slot
        guard isOccupied(slot) else {
            return false
        }
        memcpy(destination, storage.advanced(by: slot * payloadByteCount), payloadByteCount)
        // Release this slot only after the destination copy has completed.
        clearOccupied(slot)
        skipReleasedHeadSlots(startingAt: reservation.readIndex)
        return true
    }

    public func copyPayload(
        startFrame: UInt64,
        to destination: UnsafeMutableRawPointer,
        byteCount: Int
    ) -> Bool {
        guard state.validateConsumer() else {
            return false
        }
        guard byteCount >= payloadByteCount else {
            return false
        }
        let read = state.readIndexValue()
        let write = state.writeIndexValue()
        guard read < write else {
            return false
        }
        for cursor in read..<write {
            let slot = Int(cursor % UInt64(capacity))
            guard isOccupied(slot), startFrames[slot] == startFrame else {
                continue
            }
            memcpy(destination, storage.advanced(by: slot * payloadByteCount), payloadByteCount)
            // Release this slot only after the destination copy has completed.
            clearOccupied(slot)
            if cursor == read {
                skipReleasedHeadSlots(startingAt: read)
            }
            return true
        }
        skipReleasedHeadSlots(startingAt: read)
        return false
    }

    public func peekStartFrame() -> UInt64? {
        guard state.validateConsumer() else {
            return nil
        }
        skipReleasedHeadSlots()
        guard let reservation = state.reservePopSlot() else {
            return nil
        }
        let slot = reservation.slot
        guard isOccupied(slot) else {
            return nil
        }
        return startFrames[slot]
    }

    public func dropNextPayload() -> Bool {
        guard state.validateConsumer() else {
            return false
        }
        skipReleasedHeadSlots()
        guard let reservation = state.reservePopSlot() else {
            return false
        }
        // Dropping is a consumer-side release; readIndex is advanced after occupancy clears.
        clearOccupied(reservation.slot)
        skipReleasedHeadSlots(startingAt: reservation.readIndex)
        return true
    }

    public func dropAllButNewest() -> Int {
        guard state.validateConsumer() else {
            return 0
        }
        skipReleasedHeadSlots()
        let read = state.readIndexValue()
        let write = state.writeIndexValue()
        guard write - read > 1 else {
            return 0
        }
        let newest = write - 1
        var dropped = 0
        for cursor in read..<newest {
            let slot = Int(cursor % UInt64(capacity))
            if isOccupied(slot) {
                clearOccupied(slot)
                dropped += 1
            }
        }
        skipReleasedHeadSlots(startingAt: read)
        return dropped
    }

    public func dropPayloads(before startFrame: UInt64) -> Int {
        guard state.validateConsumer() else {
            return 0
        }
        let read = state.readIndexValue()
        let write = state.writeIndexValue()
        guard read < write else {
            return 0
        }
        // Only payloads strictly before the requested start frame are stale; a payload exactly
        // at startFrame is still the next due block and must remain available to the consumer.
        var dropped = 0
        for cursor in read..<write {
            let slot = Int(cursor % UInt64(capacity))
            if isOccupied(slot), startFrames[slot] < startFrame {
                clearOccupied(slot)
                dropped += 1
            }
        }
        skipReleasedHeadSlots(startingAt: read)
        return dropped
    }

    private func skipReleasedHeadSlots() {
        skipReleasedHeadSlots(startingAt: state.readIndexValue())
    }

    private func skipReleasedHeadSlots(startingAt read: UInt64) {
        let write = state.writeIndexValue()
        var nextRead = read
        while nextRead < write {
            let slot = Int(nextRead % UInt64(capacity))
            guard !isOccupied(slot) else {
                break
            }
            nextRead &+= 1
        }
        if nextRead != read {
            state.publishReadIndex(nextRead)
        }
    }

    private func isOccupied(_ slot: Int) -> Bool {
        open_lola_atomic_u64_load(occupied.advanced(by: slot)) != 0
    }

private func clearOccupied(_ slot: Int) {
open_lola_atomic_u64_store(occupied.advanced(by: slot), 0)
}
}
