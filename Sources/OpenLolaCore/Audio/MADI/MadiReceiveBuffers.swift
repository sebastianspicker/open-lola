import Foundation

struct MadiReceiveDeadlineKey: Hashable, Sendable {
    var streamID: UInt32
    var sequenceNumber: UInt64
}

struct MadiReceivePendingDeadlineSlot: Sendable {
    var key: MadiReceiveDeadlineKey
    var pending: MadiReceivePendingDeadline
}

struct MadiReceivePendingDeadlineSlots: Sendable {
    private var storage: [MadiReceivePendingDeadlineSlot?]

    init(capacity: Int) throws {
        guard capacity > 0 else {
            throw MadiReceiveError.nonPositiveField("pendingDeadlineSlotCapacity")
        }
        self.storage = Array(repeating: nil, count: capacity)
    }

    func pending(for key: MadiReceiveDeadlineKey) -> MadiReceivePendingDeadline? {
        for slot in storage {
            guard let slot, slot.key == key else {
                continue
            }
            return slot.pending
        }
        return nil
    }

    mutating func store(
        _ pending: MadiReceivePendingDeadline,
        for key: MadiReceiveDeadlineKey
    ) -> Bool {
        var emptyIndex: Int?
        for index in storage.indices {
            guard let slot = storage[index] else {
                if emptyIndex == nil {
                    emptyIndex = index
                }
                continue
            }
            if slot.key == key {
                storage[index] = MadiReceivePendingDeadlineSlot(key: key, pending: pending)
                return true
            }
        }
        guard let index = emptyIndex else {
            return false
        }
        storage[index] = MadiReceivePendingDeadlineSlot(key: key, pending: pending)
        return true
    }

    mutating func remove(for key: MadiReceiveDeadlineKey) -> MadiReceivePendingDeadline? {
        for index in storage.indices {
            guard let slot = storage[index], slot.key == key else {
                continue
            }
            storage[index] = nil
            return slot.pending
        }
        return nil
    }

    mutating func remove(
        where matches: (MadiReceivePendingDeadline) -> Bool
    ) -> MadiReceivePendingDeadline? {
        for index in storage.indices {
            guard let slot = storage[index], matches(slot.pending) else {
                continue
            }
            storage[index] = nil
            return slot.pending
        }
        return nil
    }

}

enum MadiReceivePendingInsertResult {
    case stored
    case duplicate
}

enum MadiReceiveReadyBlockStoreResult: Equatable {
    case stored
    case droppedNewest
    case droppedOldest(MadiReceivePlayoutBlock)
    case droppedFuture
}

struct MadiReceivePendingDeadline: Sendable {
    var reference: UdpPcmV2PacketHeader
    var fragmentsByIndex: [UdpPcmV2Packet?]
    var receivedFragments = 0

    var isComplete: Bool {
        receivedFragments == Int(reference.fragmentCount)
    }

    var receivedFragmentCount: Int {
        receivedFragments
    }

    var expectedFragmentCount: Int {
        Int(reference.fragmentCount)
    }

    var missingFragmentIndices: [UInt16] {
        var missing: [UInt16] = []
        missing.reserveCapacity(Int(reference.fragmentCount))
        appendMissingFragmentIndices(to: &missing)
        return missing
    }

    init(reference: UdpPcmV2PacketHeader) {
        self.reference = reference
        self.fragmentsByIndex = Array(repeating: nil, count: Int(reference.fragmentCount))
    }

    func appendMissingFragmentIndices(to missing: inout [UInt16]) {
        missing.removeAll(keepingCapacity: true)
        for index in 0..<reference.fragmentCount where fragmentsByIndex[Int(index)] == nil {
            missing.append(index)
        }
    }

    mutating func insert(_ packet: UdpPcmV2Packet) throws -> MadiReceivePendingInsertResult {
        try validateConsistent(packet.header)
        let index = Int(packet.header.fragmentIndex)
        guard fragmentsByIndex.indices.contains(index) else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("fragmentIndex")
        }
        guard fragmentsByIndex[index] == nil else {
            return .duplicate
        }
        fragmentsByIndex[index] = packet
        receivedFragments += 1
        return .stored
    }

    func reassemble() throws -> UdpPcmV2ReassemblyResult {
        let missing = missingFragmentIndices
        guard missing.isEmpty else {
            return UdpPcmV2ReassemblyResult(
                sequenceNumber: reference.sequenceNumber,
                missingFragmentIndices: missing,
                duplicateFragmentIndices: [],
                payload: nil
            )
        }

        let totalChannelCount = Int(reference.totalChannelCount)
        let framesPerPacket = Int(reference.framesPerPacket)
        let bytesPerSample = reference.sampleFormat.bytesPerSample
        let totalFrameByteCount = try checkedMadiReceiveByteCount(
            totalChannelCount,
            bytesPerSample,
            index: 0
        )
        let payloadByteCount = try checkedMadiReceiveByteCount(
            framesPerPacket,
            totalFrameByteCount,
            index: 0
        )
        var payload = Data(count: payloadByteCount)

        try payload.withUnsafeMutableBytes { destinationBytes in
            guard let destinationBaseAddress = destinationBytes.baseAddress else {
                throw UdpPcmV2FragmentReassemblyError.destinationBufferUnavailable
            }
            let destinationBase = destinationBaseAddress.assumingMemoryBound(to: UInt8.self)
            for index in 0..<reference.fragmentCount {
                guard let packet = fragmentsByIndex[Int(index)] else {
                    throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("missing \(index)")
                }
                let channelsInFragment = Int(packet.header.channelsInFragment)
                let fragmentFrameByteCount = try checkedMadiReceiveByteCount(
                    channelsInFragment,
                    bytesPerSample,
                    index: index
                )
                let fragmentPayloadByteCount = try checkedMadiReceiveByteCount(
                    framesPerPacket,
                    fragmentFrameByteCount,
                    index: index
                )
                guard packet.payload.count == fragmentPayloadByteCount else {
                    throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
                }
                try packet.payload.withUnsafeBytes { fragmentBytes in
                    guard let fragmentBase = fragmentBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
                    }
                    for frame in 0..<framesPerPacket {
                        let destinationStart = (
                            (frame * totalChannelCount) + Int(packet.header.channelOffset)
                        ) * bytesPerSample
                        let sourceStart = frame * fragmentFrameByteCount
                        let destinationEnd = destinationStart.addingReportingOverflow(fragmentFrameByteCount)
                        let sourceEnd = sourceStart.addingReportingOverflow(fragmentFrameByteCount)
                        guard !destinationEnd.overflow,
                              !sourceEnd.overflow,
                              destinationEnd.partialValue <= destinationBytes.count,
                              sourceEnd.partialValue <= fragmentBytes.count else {
                            throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
                        }
                        memcpy(
                            destinationBase.advanced(by: destinationStart),
                            fragmentBase.advanced(by: sourceStart),
                            fragmentFrameByteCount
                        )
                    }
                }
            }
        }
        return UdpPcmV2ReassemblyResult(
            sequenceNumber: reference.sequenceNumber,
            missingFragmentIndices: [],
            duplicateFragmentIndices: [],
            payload: payload
        )
    }

    private func validateConsistent(_ header: UdpPcmV2PacketHeader) throws {
        guard header.streamID == reference.streamID else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("streamID")
        }
        guard header.sequenceNumber == reference.sequenceNumber else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("sequenceNumber")
        }
        guard header.senderFrameIndex == reference.senderFrameIndex else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("senderFrameIndex")
        }
        guard header.senderHostTimeNanoseconds == reference.senderHostTimeNanoseconds else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("senderHostTimeNanoseconds")
        }
        guard header.sampleRateHertz == reference.sampleRateHertz else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("sampleRateHertz")
        }
        guard header.framesPerPacket == reference.framesPerPacket else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("framesPerPacket")
        }
        guard header.totalChannelCount == reference.totalChannelCount else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("totalChannelCount")
        }
        guard header.fragmentCount == reference.fragmentCount else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("fragmentCount")
        }
        guard header.sampleFormat == reference.sampleFormat else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("sampleFormat")
        }
        guard header.metadataRevision == reference.metadataRevision else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("metadataRevision")
        }
        guard header.packingMode == reference.packingMode else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("packingMode")
        }
    }
}

private func checkedMadiReceiveByteCount(_ lhs: Int, _ rhs: Int, index: UInt16) throws -> Int {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    guard !result.overflow, result.partialValue >= 0 else {
        throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
    }
    return result.partialValue
}

struct MadiReceiveReadyBlockRing: Sendable {
    private var storage: [MadiReceivePlayoutBlock?]
    private let framesPerBlock: Int
    private var storedCount = 0

    var count: Int {
        storedCount
    }

    init(capacity: Int, framesPerBlock: Int) throws {
        guard capacity > 0 else {
            throw MadiReceiveError.nonPositiveField("preallocatedBlockCount")
        }
        guard framesPerBlock > 0 else {
            throw MadiReceiveError.nonPositiveField("framesPerBlock")
        }
        self.storage = Array(repeating: nil, count: capacity)
        self.framesPerBlock = framesPerBlock
    }

    func contains(playoutFrame: UInt64) -> Bool {
        storage[storageIndex(for: playoutFrame)]?.startFrame == playoutFrame
    }

    func accepts(playoutFrame: UInt64, nextDueFrame: UInt64) -> Bool {
        let horizonFrames = (storage.count + 1).multipliedReportingOverflow(by: framesPerBlock)
        guard !horizonFrames.overflow,
              let horizonFrameCount = UInt64(exactly: horizonFrames.partialValue) else {
            return false
        }
        let horizonEnd = nextDueFrame.addingReportingOverflow(horizonFrameCount)
        guard !horizonEnd.overflow else {
            return false
        }
        return playoutFrame <= horizonEnd.partialValue
    }

    mutating func store(
        _ block: MadiReceivePlayoutBlock,
        nextDueFrame: UInt64,
        overrunPolicy: MadiReceiveOverrunPolicy
    ) -> MadiReceiveReadyBlockStoreResult {
        guard accepts(playoutFrame: block.startFrame, nextDueFrame: nextDueFrame) else {
            return .droppedFuture
        }
        let index = storageIndex(for: block.startFrame)
        if storage[index] == nil {
            storage[index] = block
            storedCount += 1
            return .stored
        }

        switch overrunPolicy {
        case .dropNewest:
            return .droppedNewest
        case .dropOldest:
            guard let droppedBlock = storage[index] else {
                storage[index] = block
                storedCount += 1
                return .stored
            }
            storage[index] = block
            return .droppedOldest(droppedBlock)
        }
    }

    mutating func remove(playoutFrame: UInt64) -> MadiReceivePlayoutBlock? {
        let index = storageIndex(for: playoutFrame)
        guard storage[index]?.startFrame == playoutFrame else {
            return nil
        }
        let block = storage[index]
        storage[index] = nil
        storedCount -= 1
        return block
    }

    private func storageIndex(for playoutFrame: UInt64) -> Int {
        Int((playoutFrame / UInt64(framesPerBlock)) % UInt64(storage.count))
    }
}

func readInt16(_ bytes: UnsafeRawBufferPointer, offset: Int) throws -> Int16 {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("input.int16")
    }
    let source = baseAddress.assumingMemoryBound(to: UInt8.self)
    return Int16(bitPattern: UInt16(source[offset]) | UInt16(source[offset + 1]) << 8)
}

func readInt16(_ bytes: UnsafeMutableBufferPointer<UInt8>, offset: Int) throws -> Int16 {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("output.int16")
    }
    return Int16(bitPattern: UInt16(baseAddress[offset]) | UInt16(baseAddress[offset + 1]) << 8)
}

func writeInt16(
    _ value: Int16,
    to bytes: inout UnsafeMutableBufferPointer<UInt8>,
    offset: Int
) {
    let bitPattern = UInt16(bitPattern: value)
    bytes[offset] = UInt8(bitPattern & 0xFF)
    bytes[offset + 1] = UInt8((bitPattern >> 8) & 0xFF)
}

func readFloat32(_ bytes: UnsafeRawBufferPointer, offset: Int) throws -> Float {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("input.float32")
    }
    let source = baseAddress.assumingMemoryBound(to: UInt8.self)
    let bitPattern = UInt32(source[offset])
        | UInt32(source[offset + 1]) << 8
        | UInt32(source[offset + 2]) << 16
        | UInt32(source[offset + 3]) << 24
    return Float(bitPattern: bitPattern)
}

func readFloat32(_ bytes: UnsafeMutableBufferPointer<UInt8>, offset: Int) throws -> Float {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("output.float32")
    }
    let bitPattern = UInt32(baseAddress[offset])
        | UInt32(baseAddress[offset + 1]) << 8
        | UInt32(baseAddress[offset + 2]) << 16
        | UInt32(baseAddress[offset + 3]) << 24
    return Float(bitPattern: bitPattern)
}

func writeFloat32(
    _ value: Float,
    to bytes: inout UnsafeMutableBufferPointer<UInt8>,
    offset: Int
) {
    let bitPattern = value.bitPattern
    bytes[offset] = UInt8(bitPattern & 0xFF)
    bytes[offset + 1] = UInt8((bitPattern >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((bitPattern >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((bitPattern >> 24) & 0xFF)
}
