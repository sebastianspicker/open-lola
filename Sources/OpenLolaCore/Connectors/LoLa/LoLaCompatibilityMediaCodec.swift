// Encodes LoLa audio fragments, video preludes, and normal media fragments for compatibility transport.
import Foundation

/// Defines the supported choices for LoLa compatibility media packet kind.
public enum LoLaCompatibilityMediaPacketKind: String, Codable, Equatable, Sendable {
    case audioFragment
    case videoPrelude
    case videoFragment
    case malformedFragment
    case unknown
}

/// Defines failures reported when LoLa compatibility media codec error cannot continue.
public enum LoLaCompatibilityMediaCodecError: Error, Equatable, Sendable {
    case truncatedPayload(Int)
    case invalidPreludeMagic
    case invalidFragmentMagic
    case invalidFragmentCount(Int)
    case invalidFragmentIndex(Int)
    case duplicateFragment(Int)
    case duplicateVideoPrelude(UInt32)
    case missingFragment(Int)
    case missingVideoPrelude(UInt32)
    case mediaPortMismatch(source: UInt16, destination: UInt16)
    case unexpectedMediaPort(UInt16)
    case mediaStreamPortMismatch(stream: LoLaCompatibilityMediaStream, expected: UInt16, actual: UInt16)
    case serializedSizeTooLarge(Int)
    case fragmentCountTooLarge(Int)
    case frameIDMismatch(expected: UInt32, actual: UInt32)
    case sequenceMismatch(expected: UInt32, actual: UInt32)
    case fragmentCountMismatch(expected: Int, actual: Int)
    case serializedSizeMismatch(expected: Int, actual: Int)
    case fragmentOffsetMismatch(expected: Int, actual: Int)
    case invalidFinalFlag(fragmentIndex: Int, expected: Bool, actual: Bool)
    case outOfOrderFragment(expected: Int, actual: Int)
}

/// Defines the validated fields for LoLa compatibility serialized media body.
public struct LoLaCompatibilitySerializedMediaBody: Codable, Equatable, Sendable {
    public var sequence: UInt32
    public var payloadLength: Int
    public var payload: Data
}

/// Defines the validated fields for LoLa compatibility fragment header.
public struct LoLaCompatibilityFragmentHeader: Codable, Equatable, Sendable {
    public var frameID: UInt32
    public var fragmentCount: Int
    public var fragmentIndex: Int
    public var originalOffset: Int
    public var fragmentPayloadLength: Int
    public var finalFlag: Bool
}

/// Defines the validated fields for LoLa compatibility normal fragment.
public struct LoLaCompatibilityNormalFragment: Codable, Equatable, Sendable {
    public var header: LoLaCompatibilityFragmentHeader
    public var fragmentBytes: Data
    public var body: LoLaCompatibilitySerializedMediaBody?
}

/// Defines the validated fields for LoLa compatibility video prelude.
public struct LoLaCompatibilityVideoPrelude: Codable, Equatable, Sendable {
    public var frameID: UInt32
    public var serializedSize: Int
    public var fragmentCount: Int
}

/// Defines the validated fields for LoLa compatibility media packet.
public struct LoLaCompatibilityMediaPacket: Codable, Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var kind: LoLaCompatibilityMediaPacketKind
    public var frameID: UInt32
    public var fragmentIndex: Int?
    public var fragmentCount: Int
    public var fragmentPayloadLength: Int?
    public var serializedMediaPayloadLength: Int?
    public var finalFragment: Bool?
    public var payload: Data
}

/// Defines the validated fields for LoLa compatibility decoded media packet.
public struct LoLaCompatibilityDecodedMediaPacket: Equatable, Sendable {
    public var kind: LoLaCompatibilityMediaPacketKind
    public var videoPrelude: LoLaCompatibilityVideoPrelude?
    public var normalFragment: LoLaCompatibilityNormalFragment?
}

/// Encodes and decodes LoLa audio fragments, video preludes, and normal media fragments.
public enum LoLaCompatibilityMediaCodec {
    public static let preludeByteCount = 0x40
    public static let defaultMaxFragmentBodyByteCount = 1_200
    public static let maxSerializedMediaByteCount = 16 * 1024 * 1024
    public static let maxVideoFragmentCount = 16_384
    static let fragmentPrefix = Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xee, 0xee, 0xee, 0xee
    ])
    static let preludePrefix = Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xaa, 0xaa, 0xaa, 0xaa
    ])
    static let preludeFrameIDOffset = 0x10
    static let preludeSerializedSizeOffset = 0x14
    static let preludeFragmentCountOffset = 0x1c
    static let preludeRequiredByteCount = preludeFragmentCountOffset + 4
    static let fragmentFrameIDOffset = 12
    static let fragmentCountOffset = 16
    static let fragmentIndexOffset = 20
    static let fragmentOriginalOffset = 24
    static let fragmentPayloadLengthOffset = 28
    static let fragmentFinalFlagOffset = 32

    public static func audioFragments(
        sequenceNumber: UInt32,
        channels: Int
    ) throws -> [LoLaCompatibilityMediaPacket] {
        let byteCount = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: channels)
        let audio = Data((0..<byteCount).map { UInt8(($0 + Int(sequenceNumber)) & 0xff) })
        return try audioFragments(sequenceNumber: sequenceNumber, channels: channels, payload: audio)
    }

    public static func audioFragments(
        sequenceNumber: UInt32,
        channels: Int,
        payload: Data
    ) throws -> [LoLaCompatibilityMediaPacket] {
        let byteCount = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: channels)
        guard payload.count == byteCount else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
                expected: byteCount,
                actual: payload.count
            )
        }
        let body = serializedBody(sequence: sequenceNumber, payload: payload)
        return [
            normalPacket(
                LoLaCompatibilityNormalPacketRequest(
                    stream: .audio,
                    kind: .audioFragment,
                    frameID: sequenceNumber &+ 1,
                    fragmentIndex: 0,
                    fragmentCount: 1,
                    originalOffset: 0,
                    fragmentBytes: body,
                    paddedPayloadByteCount: LoLaCompatibilityMediaModel.audioUdpPayloadByteCount
                )
            )
        ]
    }

    public static func videoPackets(
        sequenceNumber: UInt32,
        payload: Data,
        maxFragmentBodyByteCount: Int = defaultMaxFragmentBodyByteCount
    ) throws -> [LoLaCompatibilityMediaPacket] {
        guard maxFragmentBodyByteCount > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "maxFragmentBodyByteCount",
                String(maxFragmentBodyByteCount)
            )
        }
        let body = serializedBody(sequence: sequenceNumber, payload: payload)
        guard body.count <= maxSerializedMediaByteCount else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeTooLarge(body.count)
        }
        try validateVideoPacketBodyFragmentLimit(body, maxFragmentBodyByteCount: maxFragmentBodyByteCount)
        let fragmentCount = videoFragmentCount(body, maxFragmentBodyByteCount: maxFragmentBodyByteCount)
        var packets = videoPreludePackets(sequenceNumber: sequenceNumber, body: body, fragmentCount: fragmentCount)
        appendVideoFragmentPackets(
            to: &packets,
            sequenceNumber: sequenceNumber,
            body: body,
            fragmentCount: fragmentCount,
            maxFragmentBodyByteCount: maxFragmentBodyByteCount
        )
        return packets
    }

    private static func validateVideoPacketBodyFragmentLimit(
        _ body: Data,
        maxFragmentBodyByteCount: Int
    ) throws {
        precondition(maxVideoFragmentCount > 0, "LoLa video fragment count limit must be positive")
        if maxFragmentBodyByteCount <= Int.max / maxVideoFragmentCount {
            let maxBodyByteCount = maxVideoFragmentCount * maxFragmentBodyByteCount
            guard body.count <= maxBodyByteCount else {
                throw LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(
                    videoFragmentCount(body, maxFragmentBodyByteCount: maxFragmentBodyByteCount)
                )
            }
        }
        let fragmentCount = videoFragmentCount(body, maxFragmentBodyByteCount: maxFragmentBodyByteCount)
        guard fragmentCount <= maxVideoFragmentCount else {
            throw LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(fragmentCount)
        }
    }

    private static func videoFragmentCount(
        _ body: Data,
        maxFragmentBodyByteCount: Int
    ) -> Int {
        max(1, ((body.count - 1) / maxFragmentBodyByteCount) + 1)
    }

    private static func videoPreludePackets(
        sequenceNumber: UInt32,
        body: Data,
        fragmentCount: Int
    ) -> [LoLaCompatibilityMediaPacket] {
        [
            videoPreludePacket(
                frameID: sequenceNumber,
                serializedSize: body.count,
                fragmentCount: fragmentCount
            )
        ]
    }

    private static func appendVideoFragmentPackets(
        to packets: inout [LoLaCompatibilityMediaPacket],
        sequenceNumber: UInt32,
        body: Data,
        fragmentCount: Int,
        maxFragmentBodyByteCount: Int
    ) {
        for index in 0..<fragmentCount {
            let offset = index * maxFragmentBodyByteCount
            let end = min(body.count, offset + maxFragmentBodyByteCount)
            packets.append(videoFragmentPacket(
                sequenceNumber: sequenceNumber,
                fragmentIndex: index,
                fragmentCount: fragmentCount,
                originalOffset: offset,
                fragmentBytes: body[offset..<end]
            ))
        }
    }

    private static func videoFragmentPacket(
        sequenceNumber: UInt32,
        fragmentIndex: Int,
        fragmentCount: Int,
        originalOffset: Int,
        fragmentBytes: Data
    ) -> LoLaCompatibilityMediaPacket {
        normalPacket(
            LoLaCompatibilityNormalPacketRequest(
                stream: .video,
                kind: .videoFragment,
                frameID: sequenceNumber,
                fragmentIndex: fragmentIndex,
                fragmentCount: fragmentCount,
                originalOffset: originalOffset,
                fragmentBytes: fragmentBytes,
                paddedPayloadByteCount: nil
            )
        )
    }

    private static func serializedBody(sequence: UInt32, payload: Data) -> Data {
        var data = Data()
        appendLoLaCodecLE32(sequence, to: &data)
        appendLoLaCodecLE32(UInt32(payload.count), to: &data)
        data.append(payload)
        return data
    }

    private struct LoLaCompatibilityNormalPacketRequest {
        let stream: LoLaCompatibilityMediaStream
        let kind: LoLaCompatibilityMediaPacketKind
        let frameID: UInt32
        let fragmentIndex: Int
        let fragmentCount: Int
        let originalOffset: Int
        let fragmentBytes: Data
        let paddedPayloadByteCount: Int?
    }

    private static func normalPacket(_ request: LoLaCompatibilityNormalPacketRequest) -> LoLaCompatibilityMediaPacket {
        var payload = Data()
        payload.append(fragmentPrefix)
        appendLoLaCodecLE32(request.frameID, to: &payload)
        appendLoLaCodecLE32(UInt32(request.fragmentCount), to: &payload)
        appendLoLaCodecLE32(UInt32(request.fragmentIndex), to: &payload)
        appendLoLaCodecLE32(UInt32(request.originalOffset), to: &payload)
        appendLoLaCodecLE32(UInt32(request.fragmentBytes.count), to: &payload)
        payload.append(request.fragmentIndex == request.fragmentCount - 1 ? 1 : 0)
        payload.append(request.fragmentBytes)
        appendLoLaNormalPacketPadding(request, to: &payload)
        return LoLaCompatibilityMediaPacket(
            stream: request.stream,
            kind: request.kind,
            frameID: request.frameID,
            fragmentIndex: request.fragmentIndex,
            fragmentCount: request.fragmentCount,
            fragmentPayloadLength: request.fragmentBytes.count,
            serializedMediaPayloadLength: nil,
            finalFragment: request.fragmentIndex == request.fragmentCount - 1,
            payload: payload
        )
    }

    private static func appendLoLaNormalPacketPadding(
        _ request: LoLaCompatibilityNormalPacketRequest,
        to payload: inout Data
    ) {
        if let paddedPayloadByteCount = request.paddedPayloadByteCount, payload.count < paddedPayloadByteCount {
            payload.append(Data(repeating: 0, count: paddedPayloadByteCount - payload.count))
        }
    }

    private static func videoPreludePacket(
        frameID: UInt32,
        serializedSize: Int,
        fragmentCount: Int
    ) -> LoLaCompatibilityMediaPacket {
        var payload = Data()
        payload.append(Data(repeating: 0, count: preludeByteCount))
        payload.replaceSubrange(0..<preludePrefix.count, with: preludePrefix)
        writeLoLaCodecLE32(frameID, to: &payload, offset: preludeFrameIDOffset)
        writeLoLaCodecLE32(UInt32(serializedSize), to: &payload, offset: preludeSerializedSizeOffset)
        writeLoLaCodecLE32(UInt32(fragmentCount), to: &payload, offset: preludeFragmentCountOffset)
        return LoLaCompatibilityMediaPacket(
            stream: .video,
            kind: .videoPrelude,
            frameID: frameID,
            fragmentIndex: nil,
            fragmentCount: fragmentCount,
            fragmentPayloadLength: nil,
            serializedMediaPayloadLength: serializedSize,
            finalFragment: nil,
            payload: payload
        )
    }

}

private func appendLoLaCodecLE32(_ value: UInt32, to data: inout Data) {
    appendUdpPcmUInt32LE(value, to: &data)
}

func readLoLaCodecLE32(_ bytes: [UInt8], offset: Int) -> UInt32 {
    readPrevalidatedUInt32LE(bytes, offset: offset)
}

private func writeLoLaCodecLE32(_ value: UInt32, to data: inout Data, offset: Int) {
    data[offset] = UInt8(value & 0xff)
    data[offset + 1] = UInt8((value >> 8) & 0xff)
    data[offset + 2] = UInt8((value >> 16) & 0xff)
    data[offset + 3] = UInt8((value >> 24) & 0xff)
}

func checkedLoLaDatagramCountSum(_ lhs: Int, _ rhs: Int) -> Int {
    let sum = lhs.addingReportingOverflow(rhs)
    return sum.overflow ? Int.max : sum.partialValue
}

func checkedLoLaDatagramCountProduct(_ lhs: Int, _ rhs: Int) -> Int {
    let product = lhs.multipliedReportingOverflow(by: rhs)
    return product.overflow ? Int.max : product.partialValue
}
