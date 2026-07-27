// Implements VideoTransportFragmentCodec media transport boundary, separating packet I/O from session policy.
import Foundation

extension VideoTransportFragment {
public func encoded() throws -> Data {
        do {
            try validate()
        } catch let error as VideoTransportFragmentError {
            throw VideoTransportFragmentError.encodingValidationFailed(
                field: error.validationField,
                reason: String(describing: error)
            )
        }

        let fingerprintBytes = [UInt8](frameFingerprint.utf8)
        let sourceRoleBytes = [UInt8](sourceRole.rawValue.utf8)
        let pixelFormatBytes = [UInt8](pixelFormat.utf8)
        var data = Data()
        data.reserveCapacity(encodedByteCount)
        data.append(contentsOf: VideoTransportFormat.magic)
        data.append(VideoTransportFormat.currentVersion)
        data.append(timestampBasis.videoTransportCode)
        appendVideoTransportUInt16LE(UInt16(fingerprintBytes.count), to: &data)
        appendVideoTransportUInt32LE(streamID, to: &data)
        appendVideoTransportUInt16LE(UInt16(sourceRoleBytes.count), to: &data)
        appendVideoTransportUInt16LE(UInt16(pixelFormatBytes.count), to: &data)
        appendVideoTransportUInt64LE(frameSequenceNumber, to: &data)
        appendVideoTransportUInt64LE(timestampNanoseconds, to: &data)
        appendVideoTransportUInt32LE(UInt32(framePayloadByteCount), to: &data)
        appendVideoTransportUInt32LE(UInt32(fragmentIndex), to: &data)
        appendVideoTransportUInt32LE(UInt32(fragmentCount), to: &data)
        appendVideoTransportUInt32LE(UInt32(payloadOffset), to: &data)
        appendVideoTransportUInt32LE(UInt32(payload.count), to: &data)
        appendVideoTransportUInt32LE(UInt32(width), to: &data)
        appendVideoTransportUInt32LE(UInt32(height), to: &data)
        appendVideoTransportUInt32LE(UInt32(frameRate.numerator), to: &data)
        appendVideoTransportUInt32LE(UInt32(frameRate.denominator), to: &data)
        appendVideoTransportUInt32LE(VideoTransportFormat.headerGuard, to: &data)
        data.append(contentsOf: fingerprintBytes)
        data.append(contentsOf: sourceRoleBytes)
        data.append(contentsOf: pixelFormatBytes)
        data.append(payload)
        guard data.count == encodedByteCount else {
            throw VideoTransportFragmentError.encodingValidationFailed(
                field: "encodedByteCount",
                reason: "VideoTransportFragment.encodedByteCount must mirror encoded()"
            )
        }
        return data
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> VideoTransportFragment {
        let bytes = [UInt8](data)
        let timestampBasis = try decodePacketPrefix(bytes)
        let header = try decodeHeaderFields(bytes, timestampBasis: timestampBasis)
        try validateDecodedByteCount(header, bytes: bytes)
        let variableFields = try decodeVariableFields(header, bytes: bytes)
        var fields = VideoTransportFragmentFields()
        fields.streamID = header.streamID
        fields.frameSequenceNumber = header.frameSequenceNumber
        fields.timestampNanoseconds = header.timestampNanoseconds
        fields.timestampBasis = header.timestampBasis
        fields.sourceRole = variableFields.sourceRole
        fields.width = header.width
        fields.height = header.height
        fields.pixelFormat = variableFields.pixelFormat
        fields.frameRate = VideoFrameRate(
            numerator: header.frameRateNumerator,
            denominator: header.frameRateDenominator
        )
        fields.framePayloadByteCount = header.framePayloadByteCount
        fields.fragmentIndex = header.fragmentIndex
        fields.fragmentCount = header.fragmentCount
        fields.payloadOffset = header.payloadOffset
        fields.frameFingerprint = variableFields.frameFingerprint
        fields.payload = Data(bytes[variableFields.payloadStart..<bytes.count])
        let fragment = VideoTransportFragment(fields)
        try fragment.validate()
        return fragment
    }

    private struct DecodedHeader {
        var timestampBasis: VideoTimestampBasis
        var fingerprintByteCount: Int
        var streamID: UInt32
        var sourceRoleByteCount: Int
        var pixelFormatByteCount: Int
        var frameSequenceNumber: UInt64
        var timestampNanoseconds: UInt64
        var framePayloadByteCount: Int
        var fragmentIndex: Int
        var fragmentCount: Int
        var payloadOffset: Int
        var payloadByteCount: Int
        var width: Int
        var height: Int
        var frameRateNumerator: Int
        var frameRateDenominator: Int
    }

    private struct DecodedHeaderByteCounts {
        var fingerprintByteCount: Int
        var sourceRoleByteCount: Int
        var pixelFormatByteCount: Int
    }

    private struct DecodedFrameHeaderFields {
        var frameSequenceNumber: UInt64
        var timestampNanoseconds: UInt64
        var framePayloadByteCount: Int
        var width: Int
        var height: Int
        var frameRateNumerator: Int
        var frameRateDenominator: Int
    }

    private struct DecodedFragmentHeaderFields {
        var streamID: UInt32
        var fragmentIndex: Int
        var fragmentCount: Int
        var payloadOffset: Int
        var payloadByteCount: Int
    }

    private struct DecodedVariableFields {
        var frameFingerprint: String
        var sourceRole: VideoStreamRole
        var pixelFormat: String
        var payloadStart: Int
    }

    private static func decodePacketPrefix(_ bytes: [UInt8]) throws -> VideoTimestampBasis {
        guard bytes.count >= VideoTransportFormat.fixedHeaderByteCount else {
            throw VideoTransportFragmentError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<VideoTransportFormat.magicByteCount]) == VideoTransportFormat.magic else {
            throw VideoTransportFragmentError.invalidMagic
        }
        let version = bytes[VideoTransportFormat.versionOffset]
        guard version == VideoTransportFormat.currentVersion else {
            throw VideoTransportFragmentError.unsupportedVersion(version)
        }

        guard let timestampBasis = VideoTimestampBasis(
            videoTransportCode: bytes[VideoTransportFormat.timestampBasisOffset]
        ) else {
            throw VideoTransportFragmentError.invalidTimestampBasis(
                bytes[VideoTransportFormat.timestampBasisOffset]
            )
        }
        return timestampBasis
    }

    private static func decodeHeaderFields(
        _ bytes: [UInt8],
        timestampBasis: VideoTimestampBasis
    ) throws -> DecodedHeader {
        let byteCounts = decodeHeaderByteCounts(bytes)
        let frame = decodeFrameHeaderFields(bytes)
        let fragment = decodeFragmentHeaderFields(bytes)
        try validateHeaderGuard(bytes)
        return DecodedHeader(
            timestampBasis: timestampBasis,
            fingerprintByteCount: byteCounts.fingerprintByteCount,
            streamID: fragment.streamID,
            sourceRoleByteCount: byteCounts.sourceRoleByteCount,
            pixelFormatByteCount: byteCounts.pixelFormatByteCount,
            frameSequenceNumber: frame.frameSequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds,
            framePayloadByteCount: frame.framePayloadByteCount,
            fragmentIndex: fragment.fragmentIndex,
            fragmentCount: fragment.fragmentCount,
            payloadOffset: fragment.payloadOffset,
            payloadByteCount: fragment.payloadByteCount,
            width: frame.width,
            height: frame.height,
            frameRateNumerator: frame.frameRateNumerator,
            frameRateDenominator: frame.frameRateDenominator
        )
    }

    private static func decodeHeaderByteCounts(_ bytes: [UInt8]) -> DecodedHeaderByteCounts {
        DecodedHeaderByteCounts(
            fingerprintByteCount: Int(
                readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.fingerprintByteCountOffset)
            ),
            sourceRoleByteCount: Int(
                readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.sourceRoleByteCountOffset)
            ),
            pixelFormatByteCount: Int(
                readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.pixelFormatByteCountOffset)
            )
        )
    }

    private static func decodeFrameHeaderFields(_ bytes: [UInt8]) -> DecodedFrameHeaderFields {
        DecodedFrameHeaderFields(
            frameSequenceNumber: readVideoTransportUInt64LE(
                bytes,
                offset: VideoTransportFormat.frameSequenceNumberOffset
            ),
            timestampNanoseconds: readVideoTransportUInt64LE(
                bytes,
                offset: VideoTransportFormat.timestampNanosecondsOffset
            ),
            framePayloadByteCount: Int(
                readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.framePayloadByteCountOffset)
            ),
            width: Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.widthOffset)),
            height: Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.heightOffset)),
            frameRateNumerator: Int(
                readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.frameRateNumeratorOffset)
            ),
            frameRateDenominator: Int(
                readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.frameRateDenominatorOffset)
            )
        )
    }

    private static func decodeFragmentHeaderFields(_ bytes: [UInt8]) -> DecodedFragmentHeaderFields {
        let payloadByteCount = readVideoTransportUInt32LE(
            bytes,
            offset: VideoTransportFormat.payloadByteCountOffset
        )
        return DecodedFragmentHeaderFields(
            streamID: readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.streamIDOffset),
            fragmentIndex: Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.fragmentIndexOffset)),
            fragmentCount: Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.fragmentCountOffset)),
            payloadOffset: Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.payloadOffsetOffset)),
            payloadByteCount: Int(payloadByteCount)
        )
    }

    private static func validateHeaderGuard(_ bytes: [UInt8]) throws {
        let headerGuard = readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.headerGuardOffset)
        guard headerGuard == VideoTransportFormat.headerGuard else {
            throw VideoTransportFragmentError.invalidHeaderGuard
        }
    }

    private static func validateDecodedByteCount(_ header: DecodedHeader, bytes: [UInt8]) throws {
        var expectedByteCount = VideoTransportFormat.fixedHeaderByteCount
        for fieldByteCount in [
            header.fingerprintByteCount,
            header.sourceRoleByteCount,
            header.pixelFormatByteCount,
            header.payloadByteCount
        ] {
            let nextExpectedByteCount = expectedByteCount.addingReportingOverflow(fieldByteCount)
            guard !nextExpectedByteCount.overflow else {
                throw VideoTransportFragmentError.payloadLengthMismatch(
                    expected: Int.max,
                    actual: bytes.count
                )
            }
            expectedByteCount = nextExpectedByteCount.partialValue
        }
        guard bytes.count == expectedByteCount else {
            throw VideoTransportFragmentError.payloadLengthMismatch(
                expected: expectedByteCount,
                actual: bytes.count
            )
        }
    }

    private static func decodeVariableFields(
        _ header: DecodedHeader,
        bytes: [UInt8]
    ) throws -> DecodedVariableFields {
        let fingerprintStart = VideoTransportFormat.fixedHeaderByteCount
        let fingerprintEnd = fingerprintStart + header.fingerprintByteCount
        guard let frameFingerprint = String(
            bytes: bytes[fingerprintStart..<fingerprintEnd],
            encoding: .utf8
        ) else {
            throw VideoTransportFragmentError.invalidFrameFingerprint
        }
        let sourceRoleStart = fingerprintEnd
        let sourceRoleEnd = sourceRoleStart + header.sourceRoleByteCount
        guard let sourceRoleText = String(
            bytes: bytes[sourceRoleStart..<sourceRoleEnd],
            encoding: .utf8
        ),
              let sourceRole = VideoStreamRole(rawValue: sourceRoleText) else {
            throw VideoTransportFragmentError.invalidSourceRole(
                String(bytes: bytes[sourceRoleStart..<sourceRoleEnd], encoding: .utf8) ?? ""
            )
        }
        let pixelFormatStart = sourceRoleEnd
        let pixelFormatEnd = pixelFormatStart + header.pixelFormatByteCount
        guard let pixelFormat = String(
            bytes: bytes[pixelFormatStart..<pixelFormatEnd],
            encoding: .utf8
        ) else {
            throw VideoTransportFragmentError.invalidPixelFormat
        }
        return DecodedVariableFields(
            frameFingerprint: frameFingerprint,
            sourceRole: sourceRole,
            pixelFormat: pixelFormat,
            payloadStart: pixelFormatEnd
        )
    }
}

private func readVideoTransportUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    readPrevalidatedUInt16LE(bytes, offset: offset)
}

private func readVideoTransportUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
    readPrevalidatedUInt32LE(bytes, offset: offset)
}

private func readVideoTransportUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
    UInt64(readVideoTransportUInt32LE(bytes, offset: offset))
        | UInt64(readVideoTransportUInt32LE(bytes, offset: offset + 4)) << 32
}

private func appendVideoTransportUInt16LE(_ value: UInt16, to data: inout Data) {
    appendUdpPcmUInt16LE(value, to: &data)
}

private func appendVideoTransportUInt32LE(_ value: UInt32, to data: inout Data) {
    appendUdpPcmUInt32LE(value, to: &data)
}

private func appendVideoTransportUInt64LE(_ value: UInt64, to data: inout Data) {
    appendUdpPcmUInt64LE(value, to: &data)
}

private extension VideoTimestampBasis {
    var videoTransportCode: UInt8 {
        switch self {
        case .syntheticMonotonicNanoseconds:
            1
        case .hostUptimeNanoseconds:
            2
        case .avFoundationPresentationTimeNanoseconds:
            3
        }
    }

    init?(videoTransportCode: UInt8) {
        switch videoTransportCode {
        case 1:
            self = .syntheticMonotonicNanoseconds
        case 2:
            self = .hostUptimeNanoseconds
        case 3:
            self = .avFoundationPresentationTimeNanoseconds
        default:
            return nil
        }
    }
}
