import Foundation

public enum UdpPcmV2PacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case oversizedPacket(expected: Int, actual: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedSampleFormat(UInt8)
    case unsupportedPackingMode(UInt8)
    case invalidStreamID(UInt32)
    case invalidTotalChannelCount(UInt16)
    case invalidChannelRange(
        totalChannelCount: UInt16,
        channelOffset: UInt16,
        channelsInFragment: UInt16
    )
    case invalidFragmentCount(UInt16)
    case invalidFragmentIndex(index: UInt16, count: UInt16)
    case invalidFrameCount(UInt32)
    case invalidSampleRate(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
}

public struct UdpPcmV2Packet: PacketCodec {
    public static let maxPayloadByteCount = UdpPcmPacket.maxPayloadByteCount

    public var header: UdpPcmV2PacketHeader
    public var payload: Data

    public init(header: UdpPcmV2PacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpPcmV2Packet {
        let bytes = [UInt8](data)
        guard bytes.count >= UdpPcmV2PacketHeader.byteCount else {
            throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<4]) == UdpPcmV2PacketHeader.magic else {
            throw UdpPcmV2PacketError.invalidMagic
        }

        let version = bytes[4]
        guard version == UdpPcmV2PacketHeader.currentVersion else {
            throw UdpPcmV2PacketError.unsupportedVersion(version)
        }
        let formatValue = bytes[5]
        guard let sampleFormat = UdpPcmSampleFormat(rawValue: formatValue) else {
            throw UdpPcmV2PacketError.unsupportedSampleFormat(formatValue)
        }
        let packingValue = bytes[6]
        guard let packingMode = AudioWirePackingMode(wireValue: packingValue) else {
            throw UdpPcmV2PacketError.unsupportedPackingMode(packingValue)
        }

        let streamID = try readCheckedUdpPcmUInt32LE(bytes, offset: 8)
        let sequenceNumber = try readCheckedUdpPcmUInt64LE(bytes, offset: 12)
        let senderFrameIndex = try readCheckedUdpPcmUInt64LE(bytes, offset: 20)
        let senderHostTimeNanoseconds = try readCheckedUdpPcmUInt64LE(bytes, offset: 28)
        let sampleRateHertz = try readCheckedUdpPcmUInt32LE(bytes, offset: 36)
        let framesPerPacket = try readCheckedUdpPcmUInt32LE(bytes, offset: 40)
        let totalChannelCount = try readCheckedUdpPcmUInt16LE(bytes, offset: 44)
        let channelOffset = try readCheckedUdpPcmUInt16LE(bytes, offset: 46)
        let channelsInFragment = try readCheckedUdpPcmUInt16LE(bytes, offset: 48)
        let fragmentIndex = try readCheckedUdpPcmUInt16LE(bytes, offset: 50)
        let fragmentCount = try readCheckedUdpPcmUInt16LE(bytes, offset: 52)
        let metadataRevision = try readCheckedUdpPcmUInt32LE(bytes, offset: 56)
        let payloadByteCount = try readCheckedUdpPcmUInt32LE(bytes, offset: 60)
        let headerGuard = try readCheckedUdpPcmUInt32LE(bytes, offset: 64)

        guard headerGuard == UdpPcmV2PacketHeader.headerGuard else {
            throw UdpPcmV2PacketError.invalidHeaderGuard
        }

        let header = UdpPcmV2PacketHeader(
            version: version,
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            totalChannelCount: totalChannelCount,
            channelOffset: channelOffset,
            channelsInFragment: channelsInFragment,
            fragmentIndex: fragmentIndex,
            fragmentCount: fragmentCount,
            sampleFormat: sampleFormat,
            metadataRevision: metadataRevision,
            packingMode: packingMode,
            payloadByteCount: payloadByteCount
        )
        try validateHeaderShape(header)

        let actualPayloadByteCount = bytes.count - UdpPcmV2PacketHeader.byteCount
        let declaredPayloadByteCount = Int(payloadByteCount)
        let declaredPacketByteCount = UdpPcmV2PacketHeader.byteCount + declaredPayloadByteCount
        if actualPayloadByteCount > declaredPayloadByteCount {
            throw UdpPcmV2PacketError.oversizedPacket(
                expected: declaredPacketByteCount,
                actual: bytes.count
            )
        }
        if actualPayloadByteCount != declaredPayloadByteCount {
            throw UdpPcmV2PacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= maxPayloadByteCount else {
            throw UdpPcmV2PacketError.payloadTooLarge(declaredPayloadByteCount)
        }

        let expectedPayloadByteCount = expectedV2PayloadByteCount(header)
        guard expectedPayloadByteCount == declaredPayloadByteCount else {
            throw UdpPcmV2PacketError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: declaredPayloadByteCount
            )
        }

        return UdpPcmV2Packet(
            header: header,
            payload: Data(bytes[UdpPcmV2PacketHeader.byteCount...])
        )
    }

    public func encoded() throws -> Data {
        try validatePayload()

        var data = Data()
        data.reserveCapacity(UdpPcmV2PacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpPcmV2PacketHeader.magic)
        data.append(header.version)
        data.append(header.sampleFormat.rawValue)
        data.append(header.packingMode.wireValue)
        data.append(0)
        appendUdpPcmUInt32LE(header.streamID, to: &data)
        appendUdpPcmUInt64LE(header.sequenceNumber, to: &data)
        appendUdpPcmUInt64LE(header.senderFrameIndex, to: &data)
        appendUdpPcmUInt64LE(header.senderHostTimeNanoseconds, to: &data)
        appendUdpPcmUInt32LE(header.sampleRateHertz, to: &data)
        appendUdpPcmUInt32LE(header.framesPerPacket, to: &data)
        appendUdpPcmUInt16LE(header.totalChannelCount, to: &data)
        appendUdpPcmUInt16LE(header.channelOffset, to: &data)
        appendUdpPcmUInt16LE(header.channelsInFragment, to: &data)
        appendUdpPcmUInt16LE(header.fragmentIndex, to: &data)
        appendUdpPcmUInt16LE(header.fragmentCount, to: &data)
        appendUdpPcmUInt16LE(0, to: &data)
        appendUdpPcmUInt32LE(header.metadataRevision, to: &data)
        appendUdpPcmUInt32LE(UInt32(payload.count), to: &data)
        appendUdpPcmUInt32LE(UdpPcmV2PacketHeader.headerGuard, to: &data)
        // Reserved trailer bytes keep the v2 header at the documented 80-byte wire length.
        data.append(contentsOf: repeatElement(0, count: UdpPcmV2PacketHeader.reservedPaddingByteCount))
        data.append(payload)
        return data
    }

    private func validatePayload() throws {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        try validateHeaderShape(header)
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpPcmV2PacketError.payloadTooLarge(payload.count)
        }
        let expected = expectedV2PayloadByteCount(header)
        if payload.count != expected {
            throw UdpPcmV2PacketError.payloadLengthMismatch(
                expected: expected,
                actual: payload.count
            )
        }
    }
}

public enum UdpPcmV2PacketizerError: Error, Equatable, Sendable {
    case invalidModeProtocol(AudioTransportProtocolVersion)
    case missingFragments
    case payloadLengthMismatch(expected: Int, actual: Int)
    case fragmentPlanMismatch(String)
    case packetExceedsMtu(packetByteCount: Int, maxTransmissionUnitBytes: Int)
}

public enum UdpPcmV2Packetizer {
    public static func silence(
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        try packetize(
            Data(repeating: 0, count: expectedDeadlinePayloadByteCount(mode)),
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            mode: mode
        )
    }

    public static func packetize(
        _ payload: Data,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        try payload.withUnsafeBytes { payloadBytes in
            try packetize(
                payloadBytes,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds,
                mode: mode
            )
        }
    }

    public static func packetize(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        guard mode.protocolVersion == .udpPcmV2 else {
            throw UdpPcmV2PacketizerError.invalidModeProtocol(mode.protocolVersion)
        }
        guard !mode.fragments.isEmpty else {
            throw UdpPcmV2PacketizerError.missingFragments
        }
        let expectedPayloadByteCount = expectedDeadlinePayloadByteCount(mode)
        guard payload.count == expectedPayloadByteCount else {
            throw UdpPcmV2PacketizerError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }
        guard payload.baseAddress != nil else {
            throw UdpPcmV2PacketizerError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }

        let bytesPerSample = mode.sampleFormat.bytesPerSample
        return try mode.fragments.map { fragment in
            try validateFragmentPlan(fragment, mode: mode)
            let fragmentPayload = try fragmentPayloadBytes(
                sourceBytes: payload,
                fragment: fragment,
                totalChannelCount: mode.channelCount,
                bytesPerSample: bytesPerSample
            )
            let packet = UdpPcmV2Packet(
                header: UdpPcmV2PacketHeader(
                    streamID: try uint32(fragment.streamID, field: "streamID"),
                    sequenceNumber: sequenceNumber,
                    senderFrameIndex: senderFrameIndex,
                    senderHostTimeNanoseconds: senderHostTimeNanoseconds,
                    sampleRateHertz: try uint32(mode.sampleRateHertz, field: "sampleRateHertz"),
                    framesPerPacket: try uint32(mode.framesPerPacket, field: "framesPerPacket"),
                    totalChannelCount: try uint16(fragment.totalChannelCount, field: "totalChannelCount"),
                    channelOffset: try uint16(fragment.channelOffset, field: "channelOffset"),
                    channelsInFragment: try uint16(fragment.channelsInFragment, field: "channelsInFragment"),
                    fragmentIndex: try uint16(fragment.fragmentIndex, field: "fragmentIndex"),
                    fragmentCount: try uint16(fragment.fragmentCount, field: "fragmentCount"),
                    sampleFormat: mode.sampleFormat,
                    metadataRevision: try uint32(fragment.metadataRevision, field: "metadataRevision"),
                    packingMode: fragment.packingMode
                ),
                payload: fragmentPayload
            )
            guard packet.header.packetByteCount <= mode.maxTransmissionUnitBytes else {
                throw UdpPcmV2PacketizerError.packetExceedsMtu(
                    packetByteCount: packet.header.packetByteCount,
                    maxTransmissionUnitBytes: mode.maxTransmissionUnitBytes
                )
            }
            return packet
        }
    }

    private static func fragmentPayloadBytes(
        sourceBytes: UnsafeRawBufferPointer,
        fragment: UdpPcmV2ChannelFragmentPlan,
        totalChannelCount: Int,
        bytesPerSample: Int
    ) throws -> Data {
        let fragmentFrameByteCount = try checkedV2PacketizerProduct(
            fragment.channelsInFragment,
            bytesPerSample,
            field: "fragmentFrameByteCount"
        )
        var output = Data(count: fragment.payloadByteCount)
        try output.withUnsafeMutableBytes { destinationBytes in
            guard let sourceBaseAddress = sourceBytes.baseAddress,
                  let destinationBaseAddress = destinationBytes.baseAddress else {
                throw UdpPcmV2PacketizerError.fragmentPlanMismatch("payloadBuffer")
            }
            var destinationOffset = 0
            for frame in 0..<fragment.framesPerPacket {
                let sourceFrameOffset = try checkedV2PacketizerProduct(
                    frame,
                    totalChannelCount,
                    field: "sourceFrameOffset"
                )
                let sourceChannelOffset = try checkedV2PacketizerSum(
                    sourceFrameOffset,
                    fragment.channelOffset,
                    field: "sourceChannelOffset"
                )
                let sourceStart = try checkedV2PacketizerProduct(
                    sourceChannelOffset,
                    bytesPerSample,
                    field: "sourceStart"
                )
                let sourceEnd = try checkedV2PacketizerSum(
                    sourceStart,
                    fragmentFrameByteCount,
                    field: "sourceEnd"
                )
                let destinationEnd = try checkedV2PacketizerSum(
                    destinationOffset,
                    fragmentFrameByteCount,
                    field: "destinationEnd"
                )
                guard sourceEnd <= sourceBytes.count,
                      destinationEnd <= destinationBytes.count else {
                    throw UdpPcmV2PacketizerError.fragmentPlanMismatch("fragmentPayloadBounds")
                }
                memcpy(
                    destinationBaseAddress.advanced(by: destinationOffset),
                    sourceBaseAddress.advanced(by: sourceStart),
                    fragmentFrameByteCount
                )
                destinationOffset += fragmentFrameByteCount
            }
        }
        return output
    }

    private static func validateFragmentPlan(
        _ fragment: UdpPcmV2ChannelFragmentPlan,
        mode: AudioTransportMode
    ) throws {
        guard fragment.totalChannelCount == mode.channelCount else {
            throw UdpPcmV2PacketizerError.fragmentPlanMismatch("totalChannelCount")
        }
        guard fragment.framesPerPacket == mode.framesPerPacket else {
            throw UdpPcmV2PacketizerError.fragmentPlanMismatch("framesPerPacket")
        }
        guard fragment.sampleRateHertz == mode.sampleRateHertz else {
            throw UdpPcmV2PacketizerError.fragmentPlanMismatch("sampleRateHertz")
        }
        guard fragment.sampleFormat == mode.sampleFormat else {
            throw UdpPcmV2PacketizerError.fragmentPlanMismatch("sampleFormat")
        }
        guard fragment.packetByteCount <= mode.maxTransmissionUnitBytes else {
            throw UdpPcmV2PacketizerError.packetExceedsMtu(
                packetByteCount: fragment.packetByteCount,
                maxTransmissionUnitBytes: mode.maxTransmissionUnitBytes
            )
        }
    }
}

public enum UdpPcmV2FragmentReassemblyError: Error, Equatable, Sendable {
    case emptyFragments
    case inconsistentDeadline(String)
    case fragmentCountExceedsLimit(actual: UInt16, max: UInt16)
    case destinationBufferUnavailable
    case invalidFragmentPayload(index: UInt16)
}

public struct UdpPcmV2ReassemblyResult: Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var missingFragmentIndices: [UInt16]
    public var duplicateFragmentIndices: [UInt16]
    public var payload: Data?

    public var isComplete: Bool {
        missingFragmentIndices.isEmpty && payload != nil
    }

    public init(
        sequenceNumber: UInt64,
        missingFragmentIndices: [UInt16],
        duplicateFragmentIndices: [UInt16],
        payload: Data?
    ) {
        self.sequenceNumber = sequenceNumber
        self.missingFragmentIndices = missingFragmentIndices
        self.duplicateFragmentIndices = duplicateFragmentIndices
        self.payload = payload
    }
}

public enum UdpPcmV2FragmentReassembler {
    public static func reassemble(
        _ packets: [UdpPcmV2Packet],
        maxFragmentCount: UInt16? = nil
    ) throws -> UdpPcmV2ReassemblyResult {
        guard let first = packets.first else {
            throw UdpPcmV2FragmentReassemblyError.emptyFragments
        }
        let reference = first.header
        if let maxFragmentCount, reference.fragmentCount > maxFragmentCount {
            throw UdpPcmV2FragmentReassemblyError.fragmentCountExceedsLimit(
                actual: reference.fragmentCount,
                max: maxFragmentCount
            )
        }
        var fragmentsByIndex: [UInt16: UdpPcmV2Packet] = [:]
        var duplicates: [UInt16] = []

        for packet in packets {
            try validateConsistent(packet.header, reference: reference)
            if fragmentsByIndex[packet.header.fragmentIndex] != nil {
                duplicates.append(packet.header.fragmentIndex)
                continue
            }
            fragmentsByIndex[packet.header.fragmentIndex] = packet
        }

        let missing = (0..<reference.fragmentCount).filter { fragmentsByIndex[$0] == nil }
        guard missing.isEmpty else {
            return UdpPcmV2ReassemblyResult(
                sequenceNumber: reference.sequenceNumber,
                missingFragmentIndices: missing,
                duplicateFragmentIndices: duplicates.sorted(),
                payload: nil
            )
        }

        let payload = try reassembledPayload(
            reference: reference,
            fragmentsByIndex: fragmentsByIndex
        )
        return UdpPcmV2ReassemblyResult(
            sequenceNumber: reference.sequenceNumber,
            missingFragmentIndices: [],
            duplicateFragmentIndices: duplicates.sorted(),
            payload: payload
        )
    }

    private static func validateConsistent(
        _ header: UdpPcmV2PacketHeader,
        reference: UdpPcmV2PacketHeader
    ) throws {
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

    private static func reassembledPayload(
        reference: UdpPcmV2PacketHeader,
        fragmentsByIndex: [UInt16: UdpPcmV2Packet]
    ) throws -> Data {
        try validateCompleteChannelCoverage(reference: reference, fragmentsByIndex: fragmentsByIndex)
        let totalChannelCount = Int(reference.totalChannelCount)
        let framesPerPacket = Int(reference.framesPerPacket)
        let bytesPerSample = reference.sampleFormat.bytesPerSample
        var bytes = [UInt8](
            repeating: 0,
            count: totalChannelCount * framesPerPacket * bytesPerSample
        )

        for index in 0..<reference.fragmentCount {
            guard let packet = fragmentsByIndex[index] else {
                throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("missing \(index)")
            }
            let channelsInFragment = Int(packet.header.channelsInFragment)
            let fragmentFrameByteCount = channelsInFragment * bytesPerSample
            guard packet.payload.count == Int(packet.header.framesPerPacket) * fragmentFrameByteCount else {
                throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
            }
            let fragmentBytes = [UInt8](packet.payload)
            for frame in 0..<framesPerPacket {
                let destinationStart = (
                    (frame * totalChannelCount) + Int(packet.header.channelOffset)
                ) * bytesPerSample
                let sourceStart = frame * fragmentFrameByteCount
                guard destinationStart + fragmentFrameByteCount <= bytes.count,
                      sourceStart + fragmentFrameByteCount <= fragmentBytes.count else {
                    throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
                }
                bytes.replaceSubrange(
                    destinationStart..<destinationStart + fragmentFrameByteCount,
                    with: fragmentBytes[sourceStart..<sourceStart + fragmentFrameByteCount]
                )
            }
        }
        return Data(bytes)
    }

    private static func validateCompleteChannelCoverage(
        reference: UdpPcmV2PacketHeader,
        fragmentsByIndex: [UInt16: UdpPcmV2Packet]
    ) throws {
        var expectedOffset = 0
        for index in 0..<reference.fragmentCount {
            guard let packet = fragmentsByIndex[index] else {
                throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("missing \(index)")
            }
            let offset = Int(packet.header.channelOffset)
            let channelsInFragment = Int(packet.header.channelsInFragment)
            guard offset + channelsInFragment <= Int(reference.totalChannelCount) else {
                throw UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: index)
            }
            guard offset == expectedOffset else {
                throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("channelCoverage")
            }
            expectedOffset += channelsInFragment
        }
        guard expectedOffset == Int(reference.totalChannelCount) else {
            throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline("channelCoverage")
        }
    }
}

private func validateHeaderShape(_ header: UdpPcmV2PacketHeader) throws {
    guard header.version == UdpPcmV2PacketHeader.currentVersion else {
        throw UdpPcmV2PacketError.unsupportedVersion(header.version)
    }
    guard header.streamID > 0 else {
        throw UdpPcmV2PacketError.invalidStreamID(header.streamID)
    }
    guard header.totalChannelCount > 0 else {
        throw UdpPcmV2PacketError.invalidTotalChannelCount(header.totalChannelCount)
    }
    guard header.channelsInFragment > 0,
          Int(header.channelOffset) + Int(header.channelsInFragment)
            <= Int(header.totalChannelCount) else {
        throw UdpPcmV2PacketError.invalidChannelRange(
            totalChannelCount: header.totalChannelCount,
            channelOffset: header.channelOffset,
            channelsInFragment: header.channelsInFragment
        )
    }
    guard header.fragmentCount > 0 else {
        throw UdpPcmV2PacketError.invalidFragmentCount(header.fragmentCount)
    }
    guard header.fragmentIndex < header.fragmentCount else {
        throw UdpPcmV2PacketError.invalidFragmentIndex(
            index: header.fragmentIndex,
            count: header.fragmentCount
        )
    }
    guard header.framesPerPacket > 0 else {
        throw UdpPcmV2PacketError.invalidFrameCount(header.framesPerPacket)
    }
    guard header.sampleRateHertz > 0 else {
        throw UdpPcmV2PacketError.invalidSampleRate(header.sampleRateHertz)
    }
    guard header.senderHostTimeNanoseconds > 0 else {
        throw UdpPcmV2PacketError.invalidTimestamp(header.senderHostTimeNanoseconds)
    }
}

private func expectedDeadlinePayloadByteCount(_ mode: AudioTransportMode) -> Int {
    mode.payloadByteCount
}

private func expectedV2PayloadByteCount(_ header: UdpPcmV2PacketHeader) -> Int {
    Int(header.framesPerPacket)
        * Int(header.channelsInFragment)
        * header.sampleFormat.bytesPerSample
}

private func uint16(_ value: Int, field: String) throws -> UInt16 {
    guard value >= 0, value <= Int(UInt16.max) else {
        throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
    }
    return UInt16(value)
}

private func uint32(_ value: Int, field: String) throws -> UInt32 {
    guard value >= 0, value <= Int(UInt32.max) else {
        throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
    }
    return UInt32(value)
}

private func checkedV2PacketizerProduct(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
    let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    guard !overflow else {
        throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
    }
    return value
}

private func checkedV2PacketizerSum(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
    let (value, overflow) = lhs.addingReportingOverflow(rhs)
    guard !overflow else {
        throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
    }
    return value
}

private func readCheckedUdpPcmUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
        throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

private func readCheckedUdpPcmUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
        throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt32LE(bytes, offset: offset)
}

private func readCheckedUdpPcmUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
        throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}
