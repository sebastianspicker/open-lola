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

        let payload = try reassembledPayload()
        return UdpPcmV2ReassemblyResult(
            sequenceNumber: reference.sequenceNumber,
            missingFragmentIndices: [],
            duplicateFragmentIndices: [],
            payload: payload
        )
    }

    private func reassembledPayload() throws -> Data {
        let layout = try reassemblyLayout()
        var payload = Data(count: layout.payloadByteCount)
        try copyFragments(into: &payload, layout: layout)
        return payload
    }

    private func reassemblyLayout() throws -> MadiReceiveReassemblyLayout {
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
        return MadiReceiveReassemblyLayout(
            totalChannelCount: totalChannelCount,
            framesPerPacket: framesPerPacket,
            bytesPerSample: bytesPerSample,
            payloadByteCount: payloadByteCount
        )
    }

    private func copyFragments(
        into payload: inout Data,
        layout: MadiReceiveReassemblyLayout
    ) throws {
        try payload.withUnsafeMutableBytes { destinationBytes in
            guard let destinationBaseAddress = destinationBytes.baseAddress else {
                throw UdpPcmV2FragmentReassemblyError.destinationBufferUnavailable
            }
            let destinationBase = destinationBaseAddress.assumingMemoryBound(to: UInt8.self)
            for index in 0..<reference.fragmentCount {
                guard let packet = fragmentsByIndex[Int(index)] else {
                    throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("missing \(index)")
                }
                try copyFragment(
                    packet,
                    index: index,
                    into: destinationBytes,
                    destinationBase: destinationBase,
                    layout: layout
                )
            }
        }
    }

    private func copyFragment(
        _ packet: UdpPcmV2Packet,
        index: UInt16,
        into destinationBytes: UnsafeMutableRawBufferPointer,
        destinationBase: UnsafeMutablePointer<UInt8>,
        layout: MadiReceiveReassemblyLayout
    ) throws {
        let fragmentFrameByteCount = try fragmentFrameByteCount(for: packet, index: index, layout: layout)
        try packet.payload.withUnsafeBytes { fragmentBytes in
            guard let fragmentBase = fragmentBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
            }
            let buffers = MadiReceiveFragmentCopyBuffers(
                fragmentBytes: fragmentBytes,
                fragmentBase: fragmentBase,
                destinationBytes: destinationBytes,
                destinationBase: destinationBase
            )
            try copyFragmentFrames(
                MadiReceiveFragmentCopy(
                    packet: packet,
                    index: index,
                    fragmentFrameByteCount: fragmentFrameByteCount
                ),
                buffers: buffers,
                fragmentFrameByteCount: fragmentFrameByteCount,
                layout: layout
            )
        }
    }

    private func fragmentFrameByteCount(
        for packet: UdpPcmV2Packet,
        index: UInt16,
        layout: MadiReceiveReassemblyLayout
    ) throws -> Int {
        let channelsInFragment = Int(packet.header.channelsInFragment)
        let fragmentFrameByteCount = try checkedMadiReceiveByteCount(
            channelsInFragment,
            layout.bytesPerSample,
            index: index
        )
        let fragmentPayloadByteCount = try checkedMadiReceiveByteCount(
            layout.framesPerPacket,
            fragmentFrameByteCount,
            index: index
        )
        guard packet.payload.count == fragmentPayloadByteCount else {
            throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
        }
        return fragmentFrameByteCount
    }

    private func copyFragmentFrames(
        _ fragment: MadiReceiveFragmentCopy,
        buffers: MadiReceiveFragmentCopyBuffers,
        fragmentFrameByteCount: Int,
        layout: MadiReceiveReassemblyLayout
    ) throws {
        for frame in 0..<layout.framesPerPacket {
            let destinationStart = destinationStart(
                packet: fragment.packet,
                frame: frame,
                layout: layout
            )
            let sourceStart = frame * fragmentFrameByteCount
            try validateFragmentCopyBounds(
                MadiReceiveFragmentCopyBounds(
                    index: fragment.index,
                    destinationStart: destinationStart,
                    sourceStart: sourceStart,
                    fragmentFrameByteCount: fragmentFrameByteCount,
                    destinationByteCount: buffers.destinationBytes.count,
                    fragmentByteCount: buffers.fragmentBytes.count
                )
            )
            memcpy(
                buffers.destinationBase.advanced(by: destinationStart),
                buffers.fragmentBase.advanced(by: sourceStart),
                fragmentFrameByteCount
            )
        }
    }

    private func destinationStart(
        packet: UdpPcmV2Packet,
        frame: Int,
        layout: MadiReceiveReassemblyLayout
    ) -> Int {
        ((frame * layout.totalChannelCount) + Int(packet.header.channelOffset)) * layout.bytesPerSample
    }

    private func validateFragmentCopyBounds(_ bounds: MadiReceiveFragmentCopyBounds) throws {
        let destinationEnd = bounds.destinationStart.addingReportingOverflow(bounds.fragmentFrameByteCount)
        let sourceEnd = bounds.sourceStart.addingReportingOverflow(bounds.fragmentFrameByteCount)
        guard !destinationEnd.overflow,
              !sourceEnd.overflow,
              destinationEnd.partialValue <= bounds.destinationByteCount,
              sourceEnd.partialValue <= bounds.fragmentByteCount else {
            throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: bounds.index)
        }
    }

    private func validateConsistent(_ header: UdpPcmV2PacketHeader) throws {
        try requireConsistent("streamID", header.streamID == reference.streamID)
        try requireConsistent("sequenceNumber", header.sequenceNumber == reference.sequenceNumber)
        try requireConsistent("senderFrameIndex", header.senderFrameIndex == reference.senderFrameIndex)
        try requireConsistent(
            "senderHostTimeNanoseconds",
            header.senderHostTimeNanoseconds == reference.senderHostTimeNanoseconds
        )
        try requireConsistent("sampleRateHertz", header.sampleRateHertz == reference.sampleRateHertz)
        try requireConsistent("framesPerPacket", header.framesPerPacket == reference.framesPerPacket)
        try requireConsistent("totalChannelCount", header.totalChannelCount == reference.totalChannelCount)
        try requireConsistent("fragmentCount", header.fragmentCount == reference.fragmentCount)
        try requireConsistent("sampleFormat", header.sampleFormat == reference.sampleFormat)
        try requireConsistent("metadataRevision", header.metadataRevision == reference.metadataRevision)
        try requireConsistent("packingMode", header.packingMode == reference.packingMode)
    }

    private func requireConsistent(_ field: String, _ isConsistent: Bool) throws {
        guard isConsistent else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline(field)
        }
    }
}

private struct MadiReceiveReassemblyLayout {
    var totalChannelCount: Int
    var framesPerPacket: Int
    var bytesPerSample: Int
    var payloadByteCount: Int
}

private struct MadiReceiveFragmentCopy {
    var packet: UdpPcmV2Packet
    var index: UInt16
    var fragmentFrameByteCount: Int
}

private struct MadiReceiveFragmentCopyBuffers {
    var fragmentBytes: UnsafeRawBufferPointer
    var fragmentBase: UnsafePointer<UInt8>
    var destinationBytes: UnsafeMutableRawBufferPointer
    var destinationBase: UnsafeMutablePointer<UInt8>
}

private struct MadiReceiveFragmentCopyBounds {
    var index: UInt16
    var destinationStart: Int
    var sourceStart: Int
    var fragmentFrameByteCount: Int
    var destinationByteCount: Int
    var fragmentByteCount: Int
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
