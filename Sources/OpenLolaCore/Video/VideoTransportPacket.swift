// Implements VideoTransportPacket media transport boundary, separating packet I/O from session policy.
import Foundation

/// Stores packet header fields while phantom domains distinguish builders from validated packets.
public struct VideoTransportPacketStorage<Domain>: Codable, Equatable, Sendable {
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

    public init<OtherDomain>(_ fields: VideoTransportPacketStorage<OtherDomain>) {
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

/// Keeps mutable packet-field assembly distinct from packet values passed to transport policy.
public enum VideoTransportPacketFieldsDomain {}
/// Names mutable video transport packet fields used while constructing a packet.
public typealias VideoTransportPacketFields = VideoTransportPacketStorage<VideoTransportPacketFieldsDomain>

/// Keeps validated transport packets distinct from their mutable field builders.
public enum VideoTransportPacketDomain {}
/// Names a validated video transport packet passed to transport policy.
public typealias VideoTransportPacket = VideoTransportPacketStorage<VideoTransportPacketDomain>

private protocol VideoFrameTransportFields: Sendable {
    var streamID: UInt32 { get set }
    var sequenceNumber: UInt64 { get set }
    var timestampNanoseconds: UInt64 { get set }
    var timestampBasis: VideoTimestampBasis { get set }
    var sourceRole: VideoStreamRole { get set }
    var width: Int { get set }
    var height: Int { get set }
    var pixelFormat: String { get set }
    var frameRate: VideoFrameRate { get set }
}

extension VideoTransportPacketStorage: VideoFrameTransportFields {}

/// Exposes `streamID`, `frameSequenceNumber`, `timestampNanoseconds`, and `timestampBasis` as the parsed header fields required to validate video transport data.
public struct VideoTransportFragmentFields: Sendable {
    public var streamID: UInt32 = 0
    public var frameSequenceNumber: UInt64 = 0
    public var framePayloadByteCount = 0
    public var fragmentIndex = 0
    public var fragmentCount = 0
    public var payloadOffset = 0
    public var timestampNanoseconds: UInt64 = 0
    public var timestampBasis: VideoTimestampBasis = .syntheticMonotonicNanoseconds
    public var sourceRole: VideoStreamRole = .testPattern
    public var width = 0
    public var height = 0
    public var pixelFormat = ""
    public var frameRate = VideoFrameRate.disabled
    public var frameFingerprint = ""
    public var payload = Data()

    public init() {}
}

extension VideoTransportFragmentFields: VideoFrameTransportFields {
    fileprivate var sequenceNumber: UInt64 {
        get { frameSequenceNumber }
        set { frameSequenceNumber = newValue }
    }
}

private func populateVideoFrameTransportFields<Fields: VideoFrameTransportFields>(
    _ fields: inout Fields,
    from frame: CapturedVideoFrame
) {
    fields.streamID = frame.streamID
    fields.sequenceNumber = frame.sequenceNumber
    fields.timestampNanoseconds = frame.timestampNanoseconds
    fields.timestampBasis = frame.timestampBasis
    fields.sourceRole = frame.sourceRole
    fields.width = frame.width
    fields.height = frame.height
    fields.pixelFormat = frame.pixelFormat
    fields.frameRate = frame.frameRate
}

/// Associates `streamID`, `frameSequenceNumber`, `timestampNanoseconds`, and `timestampBasis` with one frame fragment during video transport reassembly.
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
        self.framePayloadByteCount = fields.framePayloadByteCount
        self.fragmentIndex = fields.fragmentIndex
        self.fragmentCount = fields.fragmentCount
        self.payloadOffset = fields.payloadOffset
        self.timestampNanoseconds = fields.timestampNanoseconds
        self.frameFingerprint = fields.frameFingerprint
        self.timestampBasis = fields.timestampBasis
        self.sourceRole = fields.sourceRole
        self.width = fields.width
        self.height = fields.height
        self.pixelFormat = fields.pixelFormat
        self.frameRate = fields.frameRate
        self.payload = fields.payload
    }
}

/// Reports `maxPacketTooSmall`, `invalidStreamID`, `invalidTimestampBasis`, and `invalidSourceRole` failures that stop invalid video capture and frame transport work before it reaches a live path.
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

/// Fragments and reconstructs raw video frames while enforcing packet-header and payload consistency.
public enum RawVideoFrameTransport {
    public static let defaultMaxPacketBytes = 9_000

    fileprivate struct FragmentationPlan {
        var framePayloadByteCount: Int
        var maxFragmentPayloadBytes: Int
        var fragmentCount: Int
    }

    /// Produces one synthetic fragment at a time so realtime senders do not
    /// allocate and prepare an entire frame before the first datagram can leave.
    struct SyntheticFragmentCursor {
        private var frame: CapturedVideoFrame
        private var framePayloadByteCount: Int
        private var maxFragmentPayloadBytes: Int
        private var nextFragmentIndex = 0
        let fragmentCount: Int

        fileprivate init(frame: CapturedVideoFrame, plan: FragmentationPlan) {
            self.frame = frame
            framePayloadByteCount = plan.framePayloadByteCount
            maxFragmentPayloadBytes = plan.maxFragmentPayloadBytes
            fragmentCount = plan.fragmentCount
        }

        mutating func next() -> VideoTransportFragment? {
            guard nextFragmentIndex < fragmentCount else {
                return nil
            }
            let plan = FragmentationPlan(
                framePayloadByteCount: framePayloadByteCount,
                maxFragmentPayloadBytes: maxFragmentPayloadBytes,
                fragmentCount: fragmentCount
            )
            defer { nextFragmentIndex += 1 }
            return RawVideoFrameTransport.syntheticFragment(
                frame: frame,
                plan: plan,
                fragmentIndex: nextFragmentIndex
            )
        }
    }

    public static func packet(for frame: CapturedVideoFrame) -> VideoTransportPacket {
        var fields = VideoTransportPacketFields()
        populateVideoFrameTransportFields(&fields, from: frame)
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
        var cursor = try syntheticFragmentCursor(for: frame, maxPacketBytes: maxPacketBytes)
        var fragments: [VideoTransportFragment] = []
        fragments.reserveCapacity(cursor.fragmentCount)
        while let fragment = cursor.next() {
            fragments.append(fragment)
        }
        return fragments
    }

    static func syntheticFragmentCursor(
        for frame: CapturedVideoFrame,
        maxPacketBytes: Int = Self.defaultMaxPacketBytes
    ) throws -> SyntheticFragmentCursor {
        let framePayloadByteCount = payloadByteCount(for: frame)
        let plan = try fragmentationPlan(
            frame: frame,
            framePayloadByteCount: framePayloadByteCount,
            maxPacketBytes: maxPacketBytes
        )
        return SyntheticFragmentCursor(frame: frame, plan: plan)
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
        populateVideoFrameTransportFields(&fields, from: frame)
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
