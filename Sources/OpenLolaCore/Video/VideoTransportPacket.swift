import Foundation

public struct VideoTransportPacket: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var timestampBasis: VideoTimestampBasis
    public var sourceRole: VideoStreamRole
    public var width: Int
    public var height: Int
    public var pixelFormat: String
    public var frameRate: VideoFrameRate
    public var payloadByteCount: Int
    public var frameFingerprint: String

    public init(
        streamID: UInt32,
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        timestampBasis: VideoTimestampBasis,
        sourceRole: VideoStreamRole,
        width: Int,
        height: Int,
        pixelFormat: String,
        frameRate: VideoFrameRate,
        payloadByteCount: Int,
        frameFingerprint: String
    ) {
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.timestampBasis = timestampBasis
        self.sourceRole = sourceRole
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.frameRate = frameRate
        self.payloadByteCount = payloadByteCount
        self.frameFingerprint = frameFingerprint
    }
}

public struct VideoTransportFragment: Equatable, Sendable {
    public static let magic = VideoTransportFormat.magic
    public static let currentVersion = VideoTransportFormat.currentVersion
    public static let fixedHeaderByteCount = VideoTransportFormat.fixedHeaderByteCount
    public static let headerGuard = VideoTransportFormat.headerGuard

    public var streamID: UInt32
    public var frameSequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var timestampBasis: VideoTimestampBasis
    public var sourceRole: VideoStreamRole
    public var width: Int
    public var height: Int
    public var pixelFormat: String
    public var frameRate: VideoFrameRate
    public var framePayloadByteCount: Int
    public var fragmentIndex: Int
    public var fragmentCount: Int
    public var payloadOffset: Int
    public var frameFingerprint: String
    public var payload: Data

    public var payloadByteCount: Int {
        payload.count
    }

    public var encodedByteCount: Int {
        VideoTransportFormat.fixedHeaderByteCount
            + frameFingerprint.utf8.count
            + sourceRole.rawValue.utf8.count
            + pixelFormat.utf8.count
            + payload.count
    }

    public init(
        streamID: UInt32,
        frameSequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        timestampBasis: VideoTimestampBasis,
        sourceRole: VideoStreamRole,
        width: Int,
        height: Int,
        pixelFormat: String,
        frameRate: VideoFrameRate,
        framePayloadByteCount: Int,
        fragmentIndex: Int,
        fragmentCount: Int,
        payloadOffset: Int,
        frameFingerprint: String,
        payload: Data
    ) {
        self.streamID = streamID
        self.frameSequenceNumber = frameSequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.timestampBasis = timestampBasis
        self.sourceRole = sourceRole
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.frameRate = frameRate
        self.framePayloadByteCount = framePayloadByteCount
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.payloadOffset = payloadOffset
        self.frameFingerprint = frameFingerprint
        self.payload = payload
    }

    public func validate() throws {
        let fingerprintByteCount = frameFingerprint.utf8.count
        let sourceRoleByteCount = sourceRole.rawValue.utf8.count
        let pixelFormatByteCount = pixelFormat.utf8.count
        guard streamID > 0 else {
            throw VideoTransportFragmentError.invalidStreamID(streamID)
        }
        guard sourceRole != .disabled else {
            throw VideoTransportFragmentError.invalidSourceRole(sourceRole.rawValue)
        }
        guard sourceRoleByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.sourceRoleTooLarge(sourceRoleByteCount)
        }
        guard width > 0 else {
            throw VideoTransportFragmentError.invalidFrameWidth(width)
        }
        guard width <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameWidthTooLarge(width)
        }
        guard height > 0 else {
            throw VideoTransportFragmentError.invalidFrameHeight(height)
        }
        guard height <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameHeightTooLarge(height)
        }
        guard !pixelFormat.isEmpty else {
            throw VideoTransportFragmentError.emptyPixelFormat
        }
        guard pixelFormatByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.pixelFormatTooLarge(pixelFormatByteCount)
        }
        guard frameRate.numerator > 0,
              frameRate.denominator > 0 else {
            throw VideoTransportFragmentError.invalidFrameRate(
                numerator: frameRate.numerator,
                denominator: frameRate.denominator
            )
        }
        guard frameRate.numerator <= Int(UInt32.max),
              frameRate.denominator <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameRateTooLarge(
                numerator: frameRate.numerator,
                denominator: frameRate.denominator
            )
        }
        guard fingerprintByteCount > 0 else {
            throw VideoTransportFragmentError.emptyFrameFingerprint
        }
        guard fingerprintByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.fingerprintTooLarge(fingerprintByteCount)
        }
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        guard framePayloadByteCount <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.framePayloadTooLarge(framePayloadByteCount)
        }
        guard fragmentCount > 0 else {
            throw VideoTransportFragmentError.invalidFragmentCount(fragmentCount)
        }
        guard fragmentIndex >= 0 && fragmentIndex < fragmentCount else {
            throw VideoTransportFragmentError.invalidFragmentIndex(
                index: fragmentIndex,
                count: fragmentCount
            )
        }
        guard payloadOffset >= 0 else {
            throw VideoTransportFragmentError.invalidPayloadOffset(payloadOffset)
        }
        guard payloadOffset <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.payloadOffsetTooLarge(payloadOffset)
        }
        guard !payload.isEmpty else {
            throw VideoTransportFragmentError.emptyPayload
        }
        guard payload.count <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.fragmentPayloadTooLarge(payload.count)
        }
        guard payloadOffset + payload.count <= framePayloadByteCount else {
            throw VideoTransportFragmentError.payloadOutOfBounds(
                offset: payloadOffset,
                payloadBytes: payload.count,
                framePayloadBytes: framePayloadByteCount
            )
        }
    }

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
        assert(data.count == encodedByteCount, "VideoTransportFragment.encodedByteCount must mirror encoded()")
        return data
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> VideoTransportFragment {
        let bytes = [UInt8](data)
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
        let fingerprintByteCount = Int(
            readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.fingerprintByteCountOffset)
        )
        let streamID = readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.streamIDOffset)
        let sourceRoleByteCount = Int(
            readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.sourceRoleByteCountOffset)
        )
        let pixelFormatByteCount = Int(
            readVideoTransportUInt16LE(bytes, offset: VideoTransportFormat.pixelFormatByteCountOffset)
        )
        let frameSequenceNumber = readVideoTransportUInt64LE(
            bytes,
            offset: VideoTransportFormat.frameSequenceNumberOffset
        )
        let timestampNanoseconds = readVideoTransportUInt64LE(
            bytes,
            offset: VideoTransportFormat.timestampNanosecondsOffset
        )
        let framePayloadByteCount = Int(
            readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.framePayloadByteCountOffset)
        )
        let fragmentIndex = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.fragmentIndexOffset))
        let fragmentCount = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.fragmentCountOffset))
        let payloadOffset = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.payloadOffsetOffset))
        let payloadByteCount = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.payloadByteCountOffset))
        let width = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.widthOffset))
        let height = Int(readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.heightOffset))
        let frameRateNumerator = Int(
            readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.frameRateNumeratorOffset)
        )
        let frameRateDenominator = Int(
            readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.frameRateDenominatorOffset)
        )
        let headerGuard = readVideoTransportUInt32LE(bytes, offset: VideoTransportFormat.headerGuardOffset)
        guard headerGuard == VideoTransportFormat.headerGuard else {
            throw VideoTransportFragmentError.invalidHeaderGuard
        }

        var expectedByteCount = VideoTransportFormat.fixedHeaderByteCount
        for fieldByteCount in [
            fingerprintByteCount,
            sourceRoleByteCount,
            pixelFormatByteCount,
            payloadByteCount,
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
        let fingerprintStart = VideoTransportFormat.fixedHeaderByteCount
        let fingerprintEnd = fingerprintStart + fingerprintByteCount
        guard let frameFingerprint = String(
            bytes: bytes[fingerprintStart..<fingerprintEnd],
            encoding: .utf8
        ) else {
            throw VideoTransportFragmentError.invalidFrameFingerprint
        }
        let sourceRoleStart = fingerprintEnd
        let sourceRoleEnd = sourceRoleStart + sourceRoleByteCount
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
        let pixelFormatEnd = pixelFormatStart + pixelFormatByteCount
        guard let pixelFormat = String(
            bytes: bytes[pixelFormatStart..<pixelFormatEnd],
            encoding: .utf8
        ) else {
            throw VideoTransportFragmentError.invalidPixelFormat
        }
        let payloadStart = pixelFormatEnd
        let fragment = VideoTransportFragment(
            streamID: streamID,
            frameSequenceNumber: frameSequenceNumber,
            timestampNanoseconds: timestampNanoseconds,
            timestampBasis: timestampBasis,
            sourceRole: sourceRole,
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            frameRate: VideoFrameRate(
                numerator: frameRateNumerator,
                denominator: frameRateDenominator
            ),
            framePayloadByteCount: framePayloadByteCount,
            fragmentIndex: fragmentIndex,
            fragmentCount: fragmentCount,
            payloadOffset: payloadOffset,
            frameFingerprint: frameFingerprint,
            payload: Data(bytes[payloadStart..<bytes.count])
        )
        try fragment.validate()
        return fragment
    }
}

public enum VideoTransportFragmentError: Error, Equatable, Sendable {
    case maxPacketTooSmall(maxPacketBytes: Int, overheadBytes: Int)
    case invalidStreamID(UInt32)
    case invalidTimestampBasis(UInt8)
    case invalidSourceRole(String)
    case sourceRoleTooLarge(Int)
    case invalidFrameWidth(Int)
    case frameWidthTooLarge(Int)
    case invalidFrameHeight(Int)
    case frameHeightTooLarge(Int)
    case emptyPixelFormat
    case invalidPixelFormat
    case pixelFormatTooLarge(Int)
    case invalidFrameRate(numerator: Int, denominator: Int)
    case frameRateTooLarge(numerator: Int, denominator: Int)
    case emptyFrameFingerprint
    case invalidFrameFingerprint
    case fingerprintTooLarge(Int)
    case invalidFramePayloadByteCount(Int)
    case framePayloadTooLarge(Int)
    case invalidFragmentCount(Int)
    case invalidFragmentIndex(index: Int, count: Int)
    case invalidPayloadOffset(Int)
    case payloadOffsetTooLarge(Int)
    case emptyPayload
    case fragmentPayloadTooLarge(Int)
    case payloadOutOfBounds(offset: Int, payloadBytes: Int, framePayloadBytes: Int)
    case truncatedPacket(byteCount: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case invalidHeaderGuard
    case payloadLengthMismatch(expected: Int, actual: Int)
    case inconsistentFrameMetadata
    case fragmentOffsetMismatch(expected: Int, actual: Int)
    case encodingValidationFailed(field: String, reason: String)

    public var validationField: String {
        switch self {
        case .maxPacketTooSmall:
            "maxPacketBytes"
        case .invalidStreamID:
            "streamID"
        case .invalidTimestampBasis:
            "timestampBasis"
        case .invalidSourceRole, .sourceRoleTooLarge:
            "sourceRole"
        case .invalidFrameWidth, .frameWidthTooLarge:
            "width"
        case .invalidFrameHeight, .frameHeightTooLarge:
            "height"
        case .emptyPixelFormat, .invalidPixelFormat, .pixelFormatTooLarge:
            "pixelFormat"
        case .invalidFrameRate, .frameRateTooLarge:
            "frameRate"
        case .emptyFrameFingerprint, .invalidFrameFingerprint, .fingerprintTooLarge:
            "frameFingerprint"
        case .invalidFramePayloadByteCount, .framePayloadTooLarge:
            "framePayloadByteCount"
        case .invalidFragmentCount:
            "fragmentCount"
        case .invalidFragmentIndex:
            "fragmentIndex"
        case .invalidPayloadOffset, .payloadOffsetTooLarge:
            "payloadOffset"
        case .emptyPayload, .fragmentPayloadTooLarge:
            "payload"
        case .payloadOutOfBounds:
            "payloadOffset"
        case .truncatedPacket:
            "packet"
        case .invalidMagic:
            "magic"
        case .unsupportedVersion:
            "version"
        case .invalidHeaderGuard:
            "headerGuard"
        case .payloadLengthMismatch:
            "payloadByteCount"
        case .inconsistentFrameMetadata:
            "frameMetadata"
        case .fragmentOffsetMismatch:
            "payloadOffset"
        case .encodingValidationFailed(let field, _):
            field
        }
    }
}

public enum RawVideoFrameTransport {
    public static let defaultMaxPacketBytes = 9_000

    public static func packet(for frame: CapturedVideoFrame) -> VideoTransportPacket {
        VideoTransportPacket(
            streamID: frame.streamID,
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds,
            timestampBasis: frame.timestampBasis,
            sourceRole: frame.sourceRole,
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            frameRate: frame.frameRate,
            payloadByteCount: payloadByteCount(for: frame),
            frameFingerprint: frame.fingerprint
        )
    }

    public static func payloadByteCount(for frame: CapturedVideoFrame) -> Int {
        frame.width * frame.height * videoBytesPerPixel(for: frame.pixelFormat)
    }

    public static func fragmentCount(for frame: CapturedVideoFrame, maxPayloadBytes: Int) -> Int {
        guard maxPayloadBytes > 0 else {
            return 0
        }
        let payloadBytes = payloadByteCount(for: frame)
        return max(1, Int((Double(payloadBytes) / Double(maxPayloadBytes)).rounded(.up)))
    }

    public static func fragments(
        for frame: CapturedVideoFrame,
        maxPacketBytes: Int = Self.defaultMaxPacketBytes
    ) throws -> [VideoTransportFragment] {
        let framePayloadByteCount = payloadByteCount(for: frame)
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        let overheadBytes = VideoTransportFormat.fixedHeaderByteCount
            + frame.fingerprint.utf8.count
            + frame.sourceRole.rawValue.utf8.count
            + frame.pixelFormat.utf8.count
        let maxFragmentPayloadBytes = maxPacketBytes - overheadBytes
        guard maxFragmentPayloadBytes > 0 else {
            throw VideoTransportFragmentError.maxPacketTooSmall(
                maxPacketBytes: maxPacketBytes,
                overheadBytes: overheadBytes
            )
        }

        let fragmentCount = max(
            1,
            Int((Double(framePayloadByteCount) / Double(maxFragmentPayloadBytes)).rounded(.up))
        )
        return (0..<fragmentCount).map { fragmentIndex in
            let payloadOffset = fragmentIndex * maxFragmentPayloadBytes
            let fragmentPayloadByteCount = min(
                maxFragmentPayloadBytes,
                framePayloadByteCount - payloadOffset
            )
            return VideoTransportFragment(
                streamID: frame.streamID,
                frameSequenceNumber: frame.sequenceNumber,
                timestampNanoseconds: frame.timestampNanoseconds,
                timestampBasis: frame.timestampBasis,
                sourceRole: frame.sourceRole,
                width: frame.width,
                height: frame.height,
                pixelFormat: frame.pixelFormat,
                frameRate: frame.frameRate,
                framePayloadByteCount: framePayloadByteCount,
                fragmentIndex: fragmentIndex,
                fragmentCount: fragmentCount,
                payloadOffset: payloadOffset,
                frameFingerprint: frame.fingerprint,
                payload: syntheticPayload(
                    sequenceNumber: frame.sequenceNumber,
                    payloadOffset: payloadOffset,
                    byteCount: fragmentPayloadByteCount
                )
            )
        }
    }

    public static func fragments(
        for rawFrame: RawCapturedVideoFrame,
        maxPacketBytes: Int = Self.defaultMaxPacketBytes
    ) throws -> [VideoTransportFragment] {
        let frame = rawFrame.metadata
        let framePayloadByteCount = rawFrame.payload.count
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        let overheadBytes = VideoTransportFragment.fixedHeaderByteCount
            + frame.fingerprint.utf8.count
            + frame.sourceRole.rawValue.utf8.count
            + frame.pixelFormat.utf8.count
        let maxFragmentPayloadBytes = maxPacketBytes - overheadBytes
        guard maxFragmentPayloadBytes > 0 else {
            throw VideoTransportFragmentError.maxPacketTooSmall(
                maxPacketBytes: maxPacketBytes,
                overheadBytes: overheadBytes
            )
        }

        let fragmentCount = max(
            1,
            Int((Double(framePayloadByteCount) / Double(maxFragmentPayloadBytes)).rounded(.up))
        )
        var fragments: [VideoTransportFragment] = []
        fragments.reserveCapacity(fragmentCount)
        for fragmentIndex in 0..<fragmentCount {
            let payloadOffset = fragmentIndex * maxFragmentPayloadBytes
            let end = min(payloadOffset + maxFragmentPayloadBytes, framePayloadByteCount)
            let payload = rawFrame.payload.subdata(in: payloadOffset..<end)
            fragments.append(VideoTransportFragment(
                streamID: frame.streamID,
                frameSequenceNumber: frame.sequenceNumber,
                timestampNanoseconds: frame.timestampNanoseconds,
                timestampBasis: frame.timestampBasis,
                sourceRole: frame.sourceRole,
                width: frame.width,
                height: frame.height,
                pixelFormat: frame.pixelFormat,
                frameRate: frame.frameRate,
                framePayloadByteCount: framePayloadByteCount,
                fragmentIndex: fragmentIndex,
                fragmentCount: fragmentCount,
                payloadOffset: payloadOffset,
                frameFingerprint: frame.fingerprint,
                payload: payload
            ))
        }
        return fragments
    }

    private static func syntheticPayload(
        sequenceNumber: UInt64,
        payloadOffset: Int,
        byteCount: Int
    ) -> Data {
        let byte = UInt8((sequenceNumber &+ UInt64(payloadOffset)) & 0xFF)
        return Data(repeating: byte, count: byteCount)
    }
}

private func readVideoTransportUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    UInt16(bytes[offset])
        | UInt16(bytes[offset + 1]) << 8
}

private func readVideoTransportUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
}

private func readVideoTransportUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
    UInt64(readVideoTransportUInt32LE(bytes, offset: offset))
        | UInt64(readVideoTransportUInt32LE(bytes, offset: offset + 4)) << 32
}

private func appendVideoTransportUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
}

private func appendVideoTransportUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 24) & 0xFF))
}

private func appendVideoTransportUInt64LE(_ value: UInt64, to data: inout Data) {
    appendVideoTransportUInt32LE(UInt32(value & 0xFFFF_FFFF), to: &data)
    appendVideoTransportUInt32LE(UInt32((value >> 32) & 0xFFFF_FFFF), to: &data)
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
