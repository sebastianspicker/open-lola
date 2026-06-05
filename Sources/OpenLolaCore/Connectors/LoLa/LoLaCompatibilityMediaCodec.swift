import Foundation

public enum LoLaCompatibilityMediaPacketKind: String, Codable, Equatable, Sendable {
    case audioFragment
    case videoPrelude
    case videoFragment
    case malformedFragment
    case unknown
}

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

public struct LoLaCompatibilitySerializedMediaBody: Codable, Equatable, Sendable {
    public var sequence: UInt32
    public var payloadLength: Int
    public var payload: Data
}

public struct LoLaCompatibilityFragmentHeader: Codable, Equatable, Sendable {
    public var frameID: UInt32
    public var fragmentCount: Int
    public var fragmentIndex: Int
    public var originalOffset: Int
    public var fragmentPayloadLength: Int
    public var finalFlag: Bool
}

public struct LoLaCompatibilityNormalFragment: Codable, Equatable, Sendable {
    public var header: LoLaCompatibilityFragmentHeader
    public var fragmentBytes: Data
    public var body: LoLaCompatibilitySerializedMediaBody?
}

public struct LoLaCompatibilityVideoPrelude: Codable, Equatable, Sendable {
    public var frameID: UInt32
    public var serializedSize: Int
    public var fragmentCount: Int
}

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

public struct LoLaCompatibilityDecodedMediaPacket: Equatable, Sendable {
    public var kind: LoLaCompatibilityMediaPacketKind
    public var videoPrelude: LoLaCompatibilityVideoPrelude?
    public var normalFragment: LoLaCompatibilityNormalFragment?
}

public enum LoLaCompatibilityMediaCodec {
    public static let preludeByteCount = 0x40
    public static let defaultMaxFragmentBodyByteCount = 1_200
    public static let maxSerializedMediaByteCount = 16 * 1024 * 1024
    public static let maxVideoFragmentCount = 16_384
    private static let fragmentPrefix = Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xee, 0xee, 0xee, 0xee
    ])
    private static let preludePrefix = Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xaa, 0xaa, 0xaa, 0xaa
    ])
    private static let preludeFrameIDOffset = 0x10
    private static let preludeSerializedSizeOffset = 0x14
    private static let preludeFragmentCountOffset = 0x1c
    private static let preludeRequiredByteCount = preludeFragmentCountOffset + 4
    private static let fragmentFrameIDOffset = 12
    private static let fragmentCountOffset = 16
    private static let fragmentIndexOffset = 20
    private static let fragmentOriginalOffset = 24
    private static let fragmentPayloadLengthOffset = 28
    private static let fragmentFinalFlagOffset = 32

    public static func expectedDatagramCount(
        mediaMode: ExternalConnectorMediaMode,
        videoWidth: Int,
        videoHeight: Int,
        videoBitsPerPixel: Int,
        frameCountPerStream: Int
    ) -> Int {
        var datagramsPerFrame = 0
        if mediaMode.hasAudio {
            datagramsPerFrame += 1
        }
        if mediaMode.hasVideo {
            let payloadBytes = MediaGeometrySizing.clampedRawFrameByteCountForBitsPerPixel(
                width: videoWidth,
                height: videoHeight,
                bitsPerPixel: videoBitsPerPixel
            )
            let serializedBytes = checkedLoLaDatagramCountSum(8, payloadBytes)
            let fragmentCount = max(
                1,
                ((serializedBytes - 1) / defaultMaxFragmentBodyByteCount) + 1
            )
            datagramsPerFrame = checkedLoLaDatagramCountSum(datagramsPerFrame, 1 + fragmentCount)
        }
        return max(1, checkedLoLaDatagramCountProduct(datagramsPerFrame, max(1, frameCountPerStream)))
    }

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

    public static func decode(_ payload: Data) throws -> LoLaCompatibilityDecodedMediaPacket {
        if payload.count == preludeByteCount, payload.prefix(preludePrefix.count) == preludePrefix {
            return LoLaCompatibilityDecodedMediaPacket(
                kind: .videoPrelude,
                videoPrelude: try decodePrelude(payload),
                normalFragment: nil
            )
        }
        return LoLaCompatibilityDecodedMediaPacket(
            kind: .videoFragment,
            videoPrelude: nil,
            normalFragment: try decodeNormalFragment(payload)
        )
    }

    public static func reassemble(
        prelude: LoLaCompatibilityVideoPrelude,
        fragments: [LoLaCompatibilityNormalFragment]
    ) throws -> LoLaCompatibilitySerializedMediaBody {
        try validateVideoPrelude(prelude)
        let byIndex = try indexedVideoFragments(fragments, prelude: prelude)
        let serialized = try serializedVideoBody(from: byIndex, prelude: prelude)
        return try decodedReassembledVideoBody(serialized, prelude: prelude)
    }

    private static func indexedVideoFragments(
        _ fragments: [LoLaCompatibilityNormalFragment],
        prelude: LoLaCompatibilityVideoPrelude
    ) throws -> [Int: LoLaCompatibilityNormalFragment] {
        var byIndex: [Int: LoLaCompatibilityNormalFragment] = [:]
        for fragment in fragments {
            try validateReassemblyFragment(fragment, prelude: prelude, byIndex: byIndex)
            byIndex[fragment.header.fragmentIndex] = fragment
        }
        return byIndex
    }

    private static func validateReassemblyFragment(
        _ fragment: LoLaCompatibilityNormalFragment,
        prelude: LoLaCompatibilityVideoPrelude,
        byIndex: [Int: LoLaCompatibilityNormalFragment]
    ) throws {
        guard fragment.header.frameID == prelude.frameID else {
            throw LoLaCompatibilityMediaCodecError.frameIDMismatch(
                expected: prelude.frameID,
                actual: fragment.header.frameID
            )
        }
        guard fragment.header.fragmentCount == prelude.fragmentCount else {
            throw LoLaCompatibilityMediaCodecError.fragmentCountMismatch(
                expected: prelude.fragmentCount,
                actual: fragment.header.fragmentCount
            )
        }
        guard fragment.header.fragmentIndex < prelude.fragmentCount else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentIndex(fragment.header.fragmentIndex)
        }
        let expectedFinalFlag = fragment.header.fragmentIndex == prelude.fragmentCount - 1
        guard fragment.header.finalFlag == expectedFinalFlag else {
            throw LoLaCompatibilityMediaCodecError.invalidFinalFlag(
                fragmentIndex: fragment.header.fragmentIndex,
                expected: expectedFinalFlag,
                actual: fragment.header.finalFlag
            )
        }
        guard byIndex[fragment.header.fragmentIndex] == nil else {
            throw LoLaCompatibilityMediaCodecError.duplicateFragment(fragment.header.fragmentIndex)
        }
    }

    private static func serializedVideoBody(
        from byIndex: [Int: LoLaCompatibilityNormalFragment],
        prelude: LoLaCompatibilityVideoPrelude
    ) throws -> Data {
        var serialized = Data()
        for index in 0..<prelude.fragmentCount {
            guard let fragment = byIndex[index] else {
                throw LoLaCompatibilityMediaCodecError.missingFragment(index)
            }
            try validateReassemblyOffset(fragment, expectedOffset: serialized.count)
            serialized.append(fragment.fragmentBytes)
        }
        guard serialized.count == prelude.serializedSize else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
                expected: prelude.serializedSize,
                actual: serialized.count
            )
        }
        return serialized
    }

    private static func validateReassemblyOffset(
        _ fragment: LoLaCompatibilityNormalFragment,
        expectedOffset: Int
    ) throws {
        guard fragment.header.originalOffset == expectedOffset else {
            throw LoLaCompatibilityMediaCodecError.fragmentOffsetMismatch(
                expected: expectedOffset,
                actual: fragment.header.originalOffset
            )
        }
    }

    private static func decodedReassembledVideoBody(
        _ serialized: Data,
        prelude: LoLaCompatibilityVideoPrelude
    ) throws -> LoLaCompatibilitySerializedMediaBody {
        let body = try decodeSerializedBody(serialized)
        guard body.sequence == prelude.frameID else {
            throw LoLaCompatibilityMediaCodecError.sequenceMismatch(expected: prelude.frameID, actual: body.sequence)
        }
        return body
    }

    public static func decodeSerializedBody(_ data: Data) throws -> LoLaCompatibilitySerializedMediaBody {
        guard data.count >= 8 else {
            throw LoLaCompatibilityMediaCodecError.truncatedPayload(data.count)
        }
        let bytes = [UInt8](data)
        let sequence = readLoLaCodecLE32(bytes, offset: 0)
        let payloadLength = Int(readLoLaCodecLE32(bytes, offset: 4))
        guard data.count == 8 + payloadLength else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
                expected: 8 + payloadLength,
                actual: data.count
            )
        }
        return LoLaCompatibilitySerializedMediaBody(
            sequence: sequence,
            payloadLength: payloadLength,
            payload: Data(bytes[8..<data.count])
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

    private static func decodePrelude(_ payload: Data) throws -> LoLaCompatibilityVideoPrelude {
        guard payload.count >= preludeRequiredByteCount else {
            throw LoLaCompatibilityMediaCodecError.truncatedPayload(payload.count)
        }
        guard payload.prefix(preludePrefix.count) == preludePrefix else {
            throw LoLaCompatibilityMediaCodecError.invalidPreludeMagic
        }
        let bytes = [UInt8](payload)
        let prelude = LoLaCompatibilityVideoPrelude(
            frameID: readLoLaCodecLE32(bytes, offset: preludeFrameIDOffset),
            serializedSize: Int(readLoLaCodecLE32(bytes, offset: preludeSerializedSizeOffset)),
            fragmentCount: Int(readLoLaCodecLE32(bytes, offset: preludeFragmentCountOffset))
        )
        try validateVideoPrelude(prelude)
        return prelude
    }

    private static func decodeNormalFragment(_ payload: Data) throws -> LoLaCompatibilityNormalFragment {
        guard payload.count >= LoLaCompatibilityMediaModel.fragmentPayloadOffset else {
            throw LoLaCompatibilityMediaCodecError.truncatedPayload(payload.count)
        }
        guard payload.prefix(fragmentPrefix.count) == fragmentPrefix else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentMagic
        }
        let bytes = [UInt8](payload)
        let header = decodeNormalFragmentHeader(bytes)
        try validateNormalFragmentHeader(header)
        try validateNormalFragmentPayloadBounds(payload, bytes: bytes, header: header)
        let fragmentBytes = normalFragmentBytes(bytes, header: header)
        return LoLaCompatibilityNormalFragment(
            header: header,
            fragmentBytes: fragmentBytes,
            body: try? decodeSerializedBody(fragmentBytes)
        )
    }

    private static func decodeNormalFragmentHeader(_ bytes: [UInt8]) -> LoLaCompatibilityFragmentHeader {
        LoLaCompatibilityFragmentHeader(
            frameID: readLoLaCodecLE32(bytes, offset: fragmentFrameIDOffset),
            fragmentCount: Int(readLoLaCodecLE32(bytes, offset: fragmentCountOffset)),
            fragmentIndex: Int(readLoLaCodecLE32(bytes, offset: fragmentIndexOffset)),
            originalOffset: Int(readLoLaCodecLE32(bytes, offset: fragmentOriginalOffset)),
            fragmentPayloadLength: Int(readLoLaCodecLE32(bytes, offset: fragmentPayloadLengthOffset)),
            finalFlag: bytes[fragmentFinalFlagOffset] != 0
        )
    }

    private static func validateNormalFragmentHeader(_ header: LoLaCompatibilityFragmentHeader) throws {
        guard header.fragmentCount > 0 else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentCount(header.fragmentCount)
        }
        guard header.fragmentCount <= maxVideoFragmentCount else {
            throw LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(header.fragmentCount)
        }
        guard header.fragmentPayloadLength <= maxSerializedMediaByteCount else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeTooLarge(header.fragmentPayloadLength)
        }
        guard header.fragmentIndex < header.fragmentCount else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentIndex(header.fragmentIndex)
        }
    }

    private static func validateNormalFragmentPayloadBounds(
        _ payload: Data,
        bytes: [UInt8],
        header: LoLaCompatibilityFragmentHeader
    ) throws {
        let fragmentStart = LoLaCompatibilityMediaModel.fragmentPayloadOffset
        let fragmentEnd = fragmentStart + header.fragmentPayloadLength
        guard payload.count >= fragmentEnd else {
            throw LoLaCompatibilityMediaCodecError.truncatedPayload(payload.count)
        }
        guard payload.count == fragmentEnd || bytes[fragmentEnd..<payload.count].allSatisfy({ $0 == 0 }) else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
                expected: fragmentEnd,
                actual: payload.count
            )
        }
    }

    private static func normalFragmentBytes(
        _ bytes: [UInt8],
        header: LoLaCompatibilityFragmentHeader
    ) -> Data {
        let fragmentStart = LoLaCompatibilityMediaModel.fragmentPayloadOffset
        return Data(bytes[fragmentStart..<(fragmentStart + header.fragmentPayloadLength)])
    }

    private static func validateVideoPrelude(_ prelude: LoLaCompatibilityVideoPrelude) throws {
        guard prelude.fragmentCount > 0 else {
            throw LoLaCompatibilityMediaCodecError.invalidFragmentCount(prelude.fragmentCount)
        }
        guard prelude.fragmentCount <= maxVideoFragmentCount else {
            throw LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(prelude.fragmentCount)
        }
        guard prelude.serializedSize <= maxSerializedMediaByteCount else {
            throw LoLaCompatibilityMediaCodecError.serializedSizeTooLarge(prelude.serializedSize)
        }
    }
}

private func appendLoLaCodecLE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}

private func readLoLaCodecLE32(_ bytes: [UInt8], offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
}

private func writeLoLaCodecLE32(_ value: UInt32, to data: inout Data, offset: Int) {
    data[offset] = UInt8(value & 0xff)
    data[offset + 1] = UInt8((value >> 8) & 0xff)
    data[offset + 2] = UInt8((value >> 16) & 0xff)
    data[offset + 3] = UInt8((value >> 24) & 0xff)
}

private func checkedLoLaDatagramCountSum(_ lhs: Int, _ rhs: Int) -> Int {
    let sum = lhs.addingReportingOverflow(rhs)
    return sum.overflow ? Int.max : sum.partialValue
}

private func checkedLoLaDatagramCountProduct(_ lhs: Int, _ rhs: Int) -> Int {
    let product = lhs.multipliedReportingOverflow(by: rhs)
    return product.overflow ? Int.max : product.partialValue
}
