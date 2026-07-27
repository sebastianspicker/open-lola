// Reassembles PCM v2 fragments only when sequence, channel range, metadata, and payload coverage agree, returning explicit incomplete state otherwise.
import Foundation

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmV2FragmentReassemblyError: Error, Equatable, Sendable {
    case emptyFragments
    case inconsistentDeadline(String)
    case fragmentCountExceedsLimit(actual: UInt16, max: UInt16)
    case destinationBufferUnavailable
    case invalidFragmentPayload(index: UInt16)
}

/// Represents the UdpPcmV2ReassemblyResult produced by UDP media transport without exposing its execution state.
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

/// Reassembles consistent UDP PCM v2 fragments and reports missing or duplicate indices without inventing payload data.
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
            (header.packingMode == reference.packingMode, "packingMode")
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
