import Foundation

public struct VideoTransportPacketFields: Sendable {
    public var streamID: UInt32 = 0
    public var sequenceNumber: UInt64 = 0
    public var timestampNanoseconds: UInt64 = 0
    public var timestampBasis: VideoTimestampBasis = .syntheticMonotonicNanoseconds
    public var sourceRole: VideoStreamRole = .testPattern
    public var width = 0
    public var height = 0
    public var pixelFormat = ""
    public var frameRate = VideoFrameRate.disabled
    public var payloadByteCount = 0
    public var frameFingerprint = ""

    public init() {}
}

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

    public init(_ fields: VideoTransportPacketFields) {
        self.streamID = fields.streamID
        self.sequenceNumber = fields.sequenceNumber
        self.timestampNanoseconds = fields.timestampNanoseconds
        self.timestampBasis = fields.timestampBasis
        self.sourceRole = fields.sourceRole
        self.width = fields.width
        self.height = fields.height
        self.pixelFormat = fields.pixelFormat
        self.frameRate = fields.frameRate
        self.payloadByteCount = fields.payloadByteCount
        self.frameFingerprint = fields.frameFingerprint
    }
}

public struct VideoTransportFragmentFields: Sendable {
    public var streamID: UInt32 = 0
    public var frameSequenceNumber: UInt64 = 0
    public var timestampNanoseconds: UInt64 = 0
    public var timestampBasis: VideoTimestampBasis = .syntheticMonotonicNanoseconds
    public var sourceRole: VideoStreamRole = .testPattern
    public var width = 0
    public var height = 0
    public var pixelFormat = ""
    public var frameRate = VideoFrameRate.disabled
    public var framePayloadByteCount = 0
    public var fragmentIndex = 0
    public var fragmentCount = 0
    public var payloadOffset = 0
    public var frameFingerprint = ""
    public var payload = Data()

    public init() {}
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

    public init(_ fields: VideoTransportFragmentFields) {
        self.streamID = fields.streamID
        self.frameSequenceNumber = fields.frameSequenceNumber
        self.timestampNanoseconds = fields.timestampNanoseconds
        self.timestampBasis = fields.timestampBasis
        self.sourceRole = fields.sourceRole
        self.width = fields.width
        self.height = fields.height
        self.pixelFormat = fields.pixelFormat
        self.frameRate = fields.frameRate
        self.framePayloadByteCount = fields.framePayloadByteCount
        self.fragmentIndex = fields.fragmentIndex
        self.fragmentCount = fields.fragmentCount
        self.payloadOffset = fields.payloadOffset
        self.frameFingerprint = fields.frameFingerprint
        self.payload = fields.payload
    }
}

extension VideoTransportFragment {
    public func validate() throws {
        let fingerprintByteCount = frameFingerprint.utf8.count
        let sourceRoleByteCount = sourceRole.rawValue.utf8.count
        let pixelFormatByteCount = pixelFormat.utf8.count
        try validateStreamMetadata(sourceRoleByteCount: sourceRoleByteCount)
        try validateGeometry(pixelFormatByteCount: pixelFormatByteCount)
        try validateTimingAndFingerprint(fingerprintByteCount: fingerprintByteCount)
        try validateFragmentPayload()
    }

    private func validateStreamMetadata(sourceRoleByteCount: Int) throws {
        guard streamID > 0 else {
            throw VideoTransportFragmentError.invalidStreamID(streamID)
        }
        guard sourceRole != .disabled else {
            throw VideoTransportFragmentError.invalidSourceRole(sourceRole.rawValue)
        }
        guard sourceRoleByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.sourceRoleTooLarge(sourceRoleByteCount)
        }
    }

    private func validateGeometry(pixelFormatByteCount: Int) throws {
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
    }

    private func validateTimingAndFingerprint(fingerprintByteCount: Int) throws {
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
    }

    private func validateFragmentPayload() throws {
        try validateFramePayloadBounds()
        try validateFragmentOrdinal()
        try validatePayloadBytes()
    }

    private func validateFramePayloadBounds() throws {
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        guard framePayloadByteCount <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.framePayloadTooLarge(framePayloadByteCount)
        }
    }

    private func validateFragmentOrdinal() throws {
        guard fragmentCount > 0 else {
            throw VideoTransportFragmentError.invalidFragmentCount(fragmentCount)
        }
        guard fragmentIndex >= 0 && fragmentIndex < fragmentCount else {
            throw VideoTransportFragmentError.invalidFragmentIndex(
                index: fragmentIndex,
                count: fragmentCount
            )
        }
    }

    private func validatePayloadBytes() throws {
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

    private struct FragmentationPlan {
        var framePayloadByteCount: Int
        var maxFragmentPayloadBytes: Int
        var fragmentCount: Int
    }

    public static func packet(for frame: CapturedVideoFrame) -> VideoTransportPacket {
        var fields = VideoTransportPacketFields()
        fields.streamID = frame.streamID
        fields.sequenceNumber = frame.sequenceNumber
        fields.timestampNanoseconds = frame.timestampNanoseconds
        fields.timestampBasis = frame.timestampBasis
        fields.sourceRole = frame.sourceRole
        fields.width = frame.width
        fields.height = frame.height
        fields.pixelFormat = frame.pixelFormat
        fields.frameRate = frame.frameRate
        fields.payloadByteCount = payloadByteCount(for: frame)
        fields.frameFingerprint = frame.fingerprint
        return VideoTransportPacket(fields)
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
        let plan = try fragmentationPlan(
            frame: frame,
            framePayloadByteCount: framePayloadByteCount,
            maxPacketBytes: maxPacketBytes
        )
        return (0..<plan.fragmentCount).map { fragmentIndex in
            syntheticFragment(frame: frame, plan: plan, fragmentIndex: fragmentIndex)
        }
    }

    public static func fragments(
        for rawFrame: RawCapturedVideoFrame,
        maxPacketBytes: Int = Self.defaultMaxPacketBytes
    ) throws -> [VideoTransportFragment] {
        let frame = rawFrame.metadata
        let framePayloadByteCount = rawFrame.payload.count
        let plan = try fragmentationPlan(
            frame: frame,
            framePayloadByteCount: framePayloadByteCount,
            maxPacketBytes: maxPacketBytes
        )
        var fragments: [VideoTransportFragment] = []
        fragments.reserveCapacity(plan.fragmentCount)
        for fragmentIndex in 0..<plan.fragmentCount {
            fragments.append(rawFragment(rawFrame: rawFrame, plan: plan, fragmentIndex: fragmentIndex))
        }
        return fragments
    }

    private static func fragmentationPlan(
        frame: CapturedVideoFrame,
        framePayloadByteCount: Int,
        maxPacketBytes: Int
    ) throws -> FragmentationPlan {
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        let overheadBytes = fragmentOverheadBytes(frame: frame)
        let maxFragmentPayloadBytes = maxPacketBytes - overheadBytes
        guard maxFragmentPayloadBytes > 0 else {
            throw VideoTransportFragmentError.maxPacketTooSmall(
                maxPacketBytes: maxPacketBytes,
                overheadBytes: overheadBytes
            )
        }
        return FragmentationPlan(
            framePayloadByteCount: framePayloadByteCount,
            maxFragmentPayloadBytes: maxFragmentPayloadBytes,
            fragmentCount: max(
                1,
                Int((Double(framePayloadByteCount) / Double(maxFragmentPayloadBytes)).rounded(.up))
            )
        )
    }

    private static func fragmentOverheadBytes(frame: CapturedVideoFrame) -> Int {
        VideoTransportFragment.fixedHeaderByteCount
            + frame.fingerprint.utf8.count
            + frame.sourceRole.rawValue.utf8.count
            + frame.pixelFormat.utf8.count
    }

    private static func syntheticFragment(
        frame: CapturedVideoFrame,
        plan: FragmentationPlan,
        fragmentIndex: Int
    ) -> VideoTransportFragment {
        let payloadOffset = fragmentIndex * plan.maxFragmentPayloadBytes
        let fragmentPayloadByteCount = min(
            plan.maxFragmentPayloadBytes,
            plan.framePayloadByteCount - payloadOffset
        )
        return videoTransportFragment(
            frame: frame,
            plan: plan,
            fragmentIndex: fragmentIndex,
            payloadOffset: payloadOffset,
            payload: syntheticPayload(
                sequenceNumber: frame.sequenceNumber,
                payloadOffset: payloadOffset,
                byteCount: fragmentPayloadByteCount
            )
        )
    }

    private static func rawFragment(
        rawFrame: RawCapturedVideoFrame,
        plan: FragmentationPlan,
        fragmentIndex: Int
    ) -> VideoTransportFragment {
        let payloadOffset = fragmentIndex * plan.maxFragmentPayloadBytes
        let end = min(payloadOffset + plan.maxFragmentPayloadBytes, plan.framePayloadByteCount)
        return videoTransportFragment(
            frame: rawFrame.metadata,
            plan: plan,
            fragmentIndex: fragmentIndex,
            payloadOffset: payloadOffset,
            payload: rawFrame.payload.subdata(in: payloadOffset..<end)
        )
    }

    private static func videoTransportFragment(
        frame: CapturedVideoFrame,
        plan: FragmentationPlan,
        fragmentIndex: Int,
        payloadOffset: Int,
        payload: Data
    ) -> VideoTransportFragment {
        var fields = VideoTransportFragmentFields()
        fields.streamID = frame.streamID
        fields.frameSequenceNumber = frame.sequenceNumber
        fields.timestampNanoseconds = frame.timestampNanoseconds
        fields.timestampBasis = frame.timestampBasis
        fields.sourceRole = frame.sourceRole
        fields.width = frame.width
        fields.height = frame.height
        fields.pixelFormat = frame.pixelFormat
        fields.frameRate = frame.frameRate
        fields.framePayloadByteCount = plan.framePayloadByteCount
        fields.fragmentIndex = fragmentIndex
        fields.fragmentCount = plan.fragmentCount
        fields.payloadOffset = payloadOffset
        fields.frameFingerprint = frame.fingerprint
        fields.payload = payload
        return VideoTransportFragment(fields)
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
