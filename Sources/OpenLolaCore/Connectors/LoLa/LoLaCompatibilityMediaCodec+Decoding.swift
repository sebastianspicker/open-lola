// Decodes LoLa media bodies, fragment headers, and video preludes from captured payload bytes.
import Foundation

extension LoLaCompatibilityMediaCodec {
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
