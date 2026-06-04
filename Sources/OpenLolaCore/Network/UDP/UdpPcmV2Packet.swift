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

public struct UdpPcmV2PacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLPC".utf8)
    public static let currentVersion: UInt8 = 2
    public static let byteCount = 80
    public static let reservedPaddingByteCount = 12
    public static let headerGuard: UInt32 = 0x3243_504C

    public var version: UInt8
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64
    public var sampleRateHertz: UInt32
    public var framesPerPacket: UInt32
    public var totalChannelCount: UInt16
    public var channelOffset: UInt16
    public var channelsInFragment: UInt16
    public var fragmentIndex: UInt16
    public var fragmentCount: UInt16
    public var sampleFormat: UdpPcmSampleFormat
    public var metadataRevision: UInt32
    public var packingMode: AudioWirePackingMode
    public var payloadByteCount: UInt32

    public var packetByteCount: Int {
        Self.byteCount + Int(payloadByteCount)
    }

    public init(
        version: UInt8 = Self.currentVersion,
        streamID: UInt32,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        sampleRateHertz: UInt32,
        framesPerPacket: UInt32,
        totalChannelCount: UInt16,
        channelOffset: UInt16,
        channelsInFragment: UInt16,
        fragmentIndex: UInt16,
        fragmentCount: UInt16,
        sampleFormat: UdpPcmSampleFormat,
        metadataRevision: UInt32,
        packingMode: AudioWirePackingMode,
        payloadByteCount: UInt32 = 0
    ) {
        self.version = version
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.senderFrameIndex = senderFrameIndex
        self.senderHostTimeNanoseconds = senderHostTimeNanoseconds
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.totalChannelCount = totalChannelCount
        self.channelOffset = channelOffset
        self.channelsInFragment = channelsInFragment
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.sampleFormat = sampleFormat
        self.metadataRevision = metadataRevision
        self.packingMode = packingMode
        self.payloadByteCount = payloadByteCount
    }
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
        let header = try decodedV2Header(from: bytes)
        try validateHeaderShape(header)
        _ = try validatedV2PayloadByteCount(bytes: bytes, header: header)
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
        try validatePacketizeRequest(payload: payload, mode: mode)
        return try mode.fragments.map { fragment in
            try packetizedFragment(
                fragment,
                sourceBytes: payload,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds,
                mode: mode
            )
        }
    }

    private static func validatePacketizeRequest(
        payload: UnsafeRawBufferPointer,
        mode: AudioTransportMode
    ) throws {
        guard mode.protocolVersion == .udpPcmV2 else {
            throw UdpPcmV2PacketizerError.invalidModeProtocol(mode.protocolVersion)
        }
        guard !mode.fragments.isEmpty else {
            throw UdpPcmV2PacketizerError.missingFragments
        }
        let expectedPayloadByteCount = expectedDeadlinePayloadByteCount(mode)
        guard payload.count == expectedPayloadByteCount,
              payload.baseAddress != nil else {
            throw UdpPcmV2PacketizerError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }
    }

    private static func packetizedFragment(
        _ fragment: UdpPcmV2ChannelFragmentPlan,
        sourceBytes: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: AudioTransportMode
    ) throws -> UdpPcmV2Packet {
        try validateFragmentPlan(fragment, mode: mode)
        let fragmentPayload = try fragmentPayloadBytes(
            sourceBytes: sourceBytes,
            fragment: fragment,
            totalChannelCount: mode.channelCount,
            bytesPerSample: mode.sampleFormat.bytesPerSample
        )
        let packet = UdpPcmV2Packet(
            header: try packetHeader(
                fragment: fragment,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds
            ),
            payload: fragmentPayload
        )
        try validatePacketSize(packet, maxTransmissionUnitBytes: mode.maxTransmissionUnitBytes)
        return packet
    }

    private static func packetHeader(
        fragment: UdpPcmV2ChannelFragmentPlan,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64
    ) throws -> UdpPcmV2PacketHeader {
        UdpPcmV2PacketHeader(
            streamID: try uint32(fragment.streamID, field: "streamID"),
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            sampleRateHertz: try uint32(fragment.sampleRateHertz, field: "sampleRateHertz"),
            framesPerPacket: try uint32(fragment.framesPerPacket, field: "framesPerPacket"),
            totalChannelCount: try uint16(fragment.totalChannelCount, field: "totalChannelCount"),
            channelOffset: try uint16(fragment.channelOffset, field: "channelOffset"),
            channelsInFragment: try uint16(fragment.channelsInFragment, field: "channelsInFragment"),
            fragmentIndex: try uint16(fragment.fragmentIndex, field: "fragmentIndex"),
            fragmentCount: try uint16(fragment.fragmentCount, field: "fragmentCount"),
            sampleFormat: fragment.sampleFormat,
            metadataRevision: try uint32(fragment.metadataRevision, field: "metadataRevision"),
            packingMode: fragment.packingMode
        )
    }

    private static func validatePacketSize(
        _ packet: UdpPcmV2Packet,
        maxTransmissionUnitBytes: Int
    ) throws {
        guard packet.header.packetByteCount <= maxTransmissionUnitBytes else {
            throw UdpPcmV2PacketizerError.packetExceedsMtu(
                packetByteCount: packet.header.packetByteCount,
                maxTransmissionUnitBytes: maxTransmissionUnitBytes
            )
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
        for check in consistencyChecks(header, reference: reference) {
            guard check.matches else {
                throw UdpPcmV2FragmentReassemblyError.inconsistentDeadline(check.field)
            }
        }
    }

    private static func consistencyChecks(
        _ header: UdpPcmV2PacketHeader,
        reference: UdpPcmV2PacketHeader
    ) -> [(matches: Bool, field: String)] {
        [
            (header.streamID == reference.streamID, "streamID"),
            (header.sequenceNumber == reference.sequenceNumber, "sequenceNumber"),
            (header.senderFrameIndex == reference.senderFrameIndex, "senderFrameIndex"),
            (
                header.senderHostTimeNanoseconds == reference.senderHostTimeNanoseconds,
                "senderHostTimeNanoseconds"
            ),
            (header.sampleRateHertz == reference.sampleRateHertz, "sampleRateHertz"),
            (header.framesPerPacket == reference.framesPerPacket, "framesPerPacket"),
            (header.totalChannelCount == reference.totalChannelCount, "totalChannelCount"),
            (header.fragmentCount == reference.fragmentCount, "fragmentCount"),
            (header.sampleFormat == reference.sampleFormat, "sampleFormat"),
            (header.metadataRevision == reference.metadataRevision, "metadataRevision"),
            (header.packingMode == reference.packingMode, "packingMode"),
        ]
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

private func decodedV2Header(from bytes: [UInt8]) throws -> UdpPcmV2PacketHeader {
    try validateV2HeaderPrefix(bytes)
    let sampleFormat = try decodedV2SampleFormat(bytes)
    let packingMode = try decodedV2PackingMode(bytes)
    let fields = try decodedV2HeaderFields(from: bytes)
    guard fields.headerGuard == UdpPcmV2PacketHeader.headerGuard else {
        throw UdpPcmV2PacketError.invalidHeaderGuard
    }
    return UdpPcmV2PacketHeader(
        version: bytes[4],
        streamID: fields.streamID,
        sequenceNumber: fields.sequenceNumber,
        senderFrameIndex: fields.senderFrameIndex,
        senderHostTimeNanoseconds: fields.senderHostTimeNanoseconds,
        sampleRateHertz: fields.sampleRateHertz,
        framesPerPacket: fields.framesPerPacket,
        totalChannelCount: fields.totalChannelCount,
        channelOffset: fields.channelOffset,
        channelsInFragment: fields.channelsInFragment,
        fragmentIndex: fields.fragmentIndex,
        fragmentCount: fields.fragmentCount,
        sampleFormat: sampleFormat,
        metadataRevision: fields.metadataRevision,
        packingMode: packingMode,
        payloadByteCount: fields.payloadByteCount
    )
}

private func validateV2HeaderPrefix(_ bytes: [UInt8]) throws {
    guard Array(bytes[0..<4]) == UdpPcmV2PacketHeader.magic else {
        throw UdpPcmV2PacketError.invalidMagic
    }
    let version = bytes[4]
    guard version == UdpPcmV2PacketHeader.currentVersion else {
        throw UdpPcmV2PacketError.unsupportedVersion(version)
    }
}

private func decodedV2SampleFormat(_ bytes: [UInt8]) throws -> UdpPcmSampleFormat {
    let formatValue = bytes[5]
    guard let sampleFormat = UdpPcmSampleFormat(rawValue: formatValue) else {
        throw UdpPcmV2PacketError.unsupportedSampleFormat(formatValue)
    }
    return sampleFormat
}

private func decodedV2PackingMode(_ bytes: [UInt8]) throws -> AudioWirePackingMode {
    let packingValue = bytes[6]
    guard let packingMode = AudioWirePackingMode(wireValue: packingValue) else {
        throw UdpPcmV2PacketError.unsupportedPackingMode(packingValue)
    }
    return packingMode
}

private struct UdpPcmV2DecodedHeaderFields {
    var streamID: UInt32
    var sequenceNumber: UInt64
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
    var sampleRateHertz: UInt32
    var framesPerPacket: UInt32
    var totalChannelCount: UInt16
    var channelOffset: UInt16
    var channelsInFragment: UInt16
    var fragmentIndex: UInt16
    var fragmentCount: UInt16
    var metadataRevision: UInt32
    var payloadByteCount: UInt32
    var headerGuard: UInt32
}

private func decodedV2HeaderFields(from bytes: [UInt8]) throws -> UdpPcmV2DecodedHeaderFields {
    UdpPcmV2DecodedHeaderFields(
        streamID: try readCheckedUdpPcmUInt32LE(bytes, offset: 8),
        sequenceNumber: try readCheckedUdpPcmUInt64LE(bytes, offset: 12),
        senderFrameIndex: try readCheckedUdpPcmUInt64LE(bytes, offset: 20),
        senderHostTimeNanoseconds: try readCheckedUdpPcmUInt64LE(bytes, offset: 28),
        sampleRateHertz: try readCheckedUdpPcmUInt32LE(bytes, offset: 36),
        framesPerPacket: try readCheckedUdpPcmUInt32LE(bytes, offset: 40),
        totalChannelCount: try readCheckedUdpPcmUInt16LE(bytes, offset: 44),
        channelOffset: try readCheckedUdpPcmUInt16LE(bytes, offset: 46),
        channelsInFragment: try readCheckedUdpPcmUInt16LE(bytes, offset: 48),
        fragmentIndex: try readCheckedUdpPcmUInt16LE(bytes, offset: 50),
        fragmentCount: try readCheckedUdpPcmUInt16LE(bytes, offset: 52),
        metadataRevision: try readCheckedUdpPcmUInt32LE(bytes, offset: 56),
        payloadByteCount: try readCheckedUdpPcmUInt32LE(bytes, offset: 60),
        headerGuard: try readCheckedUdpPcmUInt32LE(bytes, offset: 64)
    )
}

private func validatedV2PayloadByteCount(
    bytes: [UInt8],
    header: UdpPcmV2PacketHeader
) throws -> Int {
    let actualPayloadByteCount = bytes.count - UdpPcmV2PacketHeader.byteCount
    let declaredPayloadByteCount = Int(header.payloadByteCount)
    try validateV2DeclaredPayloadLength(
        declaredPayloadByteCount,
        actualPayloadByteCount: actualPayloadByteCount,
        packetByteCount: bytes.count
    )
    guard declaredPayloadByteCount <= UdpPcmV2Packet.maxPayloadByteCount else {
        throw UdpPcmV2PacketError.payloadTooLarge(declaredPayloadByteCount)
    }
    let expectedPayloadByteCount = expectedV2PayloadByteCount(header)
    guard expectedPayloadByteCount == declaredPayloadByteCount else {
        throw UdpPcmV2PacketError.payloadLengthMismatch(
            expected: expectedPayloadByteCount,
            actual: declaredPayloadByteCount
        )
    }
    return declaredPayloadByteCount
}

private func validateV2DeclaredPayloadLength(
    _ declaredPayloadByteCount: Int,
    actualPayloadByteCount: Int,
    packetByteCount: Int
) throws {
    if actualPayloadByteCount > declaredPayloadByteCount {
        throw UdpPcmV2PacketError.oversizedPacket(
            expected: UdpPcmV2PacketHeader.byteCount + declaredPayloadByteCount,
            actual: packetByteCount
        )
    }
    if actualPayloadByteCount != declaredPayloadByteCount {
        throw UdpPcmV2PacketError.payloadLengthMismatch(
            expected: declaredPayloadByteCount,
            actual: actualPayloadByteCount
        )
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
