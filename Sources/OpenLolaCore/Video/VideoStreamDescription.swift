public enum VideoStreamRole: String, Codable, Equatable, Sendable {
    case disabled
    case blackmagicInput
    case atemProgram
    case atemPreview
    case avFoundationDevice
    case testPattern
}

public enum VideoPixelFormat: String, Codable, Equatable, Sendable {
    case disabled
    case bgra8
    case yuv422
    case rgb24

    public var bytesPerPixel: Double {
        self == .disabled ? 0 : Double(videoBytesPerPixel(for: rawValue))
    }
}

public enum VideoTransportFormat: String, Codable, Equatable, Sendable {
    case disabled
    case rawFrameFragment
    case videoToolboxH264
    case videoToolboxHEVC
    case jpegXSFrameFragment

    public static let magic = [UInt8]("OLVF".utf8)
    public static let currentVersion: UInt8 = 2
    public static let fixedHeaderByteCount = 72
    public static let headerGuard: UInt32 = 0x3146_564F
    public static let magicByteCount = 4
    public static let versionOffset = 4
    public static let timestampBasisOffset = 5
    public static let fingerprintByteCountOffset = 6
    public static let streamIDOffset = 8
    public static let sourceRoleByteCountOffset = 12
    public static let pixelFormatByteCountOffset = 14
    public static let frameSequenceNumberOffset = 16
    public static let timestampNanosecondsOffset = 24
    public static let framePayloadByteCountOffset = 32
    public static let fragmentIndexOffset = 36
    public static let fragmentCountOffset = 40
    public static let payloadOffsetOffset = 44
    public static let payloadByteCountOffset = 48
    public static let widthOffset = 52
    public static let heightOffset = 56
    public static let frameRateNumeratorOffset = 60
    public static let frameRateDenominatorOffset = 64
    public static let headerGuardOffset = 68
}

public struct VideoResolution: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let disabled = VideoResolution(width: 0, height: 0)
}

public struct VideoFrameRate: Codable, Equatable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let disabled = VideoFrameRate(numerator: 0, denominator: 1)
}

public struct VideoStreamDescription: Codable, Equatable, Sendable {
    public var id: Int
    public var direction: MediaStreamDirection
    public var role: VideoStreamRole
    public var resolution: VideoResolution
    public var frameRate: VideoFrameRate
    public var pixelFormat: VideoPixelFormat
    public var transportFormat: VideoTransportFormat
    public var sourceLabel: String
    public var payloadType: SessionPayloadType
    public var priority: Int
    public var captureEnabled: Bool
    public var queueDepth: Int
    public var bandwidthBudgetMegabitsPerSecond: Double

    public var isEnabled: Bool {
        direction != .disabled && role != .disabled && transportFormat != .disabled
    }

    public var canSendMedia: Bool {
        isEnabled && captureEnabled
    }

    public var estimatedBandwidthMegabitsPerSecond: Double {
        guard frameRate.denominator > 0 else {
            return 0
        }
        guard isEnabled && captureEnabled else {
            return 0
        }
        let pixels = Double(resolution.width) * Double(resolution.height)
        let framesPerSecond = Double(frameRate.numerator) / Double(frameRate.denominator)
        return pixels * pixelFormat.bytesPerPixel * framesPerSecond * 8 / 1_000_000
    }

    public init(
        id: Int,
        direction: MediaStreamDirection,
        role: VideoStreamRole,
        resolution: VideoResolution,
        frameRate: VideoFrameRate,
        pixelFormat: VideoPixelFormat,
        transportFormat: VideoTransportFormat,
        sourceLabel: String,
        payloadType: SessionPayloadType,
        priority: Int = 100,
        captureEnabled: Bool = true,
        queueDepth: Int = 1,
        bandwidthBudgetMegabitsPerSecond: Double = 10_000
    ) {
        self.id = id
        self.direction = direction
        self.role = role
        self.resolution = resolution
        self.frameRate = frameRate
        self.pixelFormat = pixelFormat
        self.transportFormat = transportFormat
        self.sourceLabel = sourceLabel
        self.payloadType = payloadType
        self.priority = direction == .disabled ? 0 : priority
        self.captureEnabled = direction != .disabled && role != .disabled && captureEnabled
        self.queueDepth = direction == .disabled ? 0 : queueDepth
        self.bandwidthBudgetMegabitsPerSecond = direction == .disabled ? 0 : bandwidthBudgetMegabitsPerSecond
    }

    public static func disabled(id: Int, sourceLabel: String) -> VideoStreamDescription {
        VideoStreamDescription(
            id: id,
            direction: .disabled,
            role: .disabled,
            resolution: .disabled,
            frameRate: .disabled,
            pixelFormat: .disabled,
            transportFormat: .disabled,
            sourceLabel: sourceLabel,
            payloadType: .videoRawFrameFragment,
            priority: 0,
            captureEnabled: false,
            queueDepth: 0,
            bandwidthBudgetMegabitsPerSecond: 0
        )
    }

    public func validate() throws {
        try SessionValidation.requirePositive(id, "videoStream.id")
        try SessionValidation.requireNonEmpty(sourceLabel, "videoStream.sourceLabel")
        if !isEnabled {
            guard role == .disabled,
                  direction == .disabled,
                  pixelFormat == .disabled,
                  transportFormat == .disabled else {
                throw SessionValidationError.unsupportedVideoTransportFormat(transportFormat)
            }
            return
        }
        try SessionValidation.requirePositive(priority, "videoStream.priority")
        try SessionValidation.requirePositive(queueDepth, "videoStream.queueDepth")
        guard bandwidthBudgetMegabitsPerSecond.isFinite,
              bandwidthBudgetMegabitsPerSecond > 0 else {
            throw SessionValidationError.nonPositiveField(
                "videoStream.bandwidthBudgetMegabitsPerSecond"
            )
        }
        try SessionValidation.requirePositive(resolution.width, "videoStream.resolution.width")
        try SessionValidation.requirePositive(resolution.height, "videoStream.resolution.height")
        try SessionValidation.requirePositive(frameRate.numerator, "videoStream.frameRate.numerator")
        try SessionValidation.requirePositive(frameRate.denominator, "videoStream.frameRate.denominator")
        guard payloadType == .videoRawFrameFragment
            || payloadType == .videoVideoToolboxFragment
            || payloadType == .videoJpegXSFrameFragment else {
            throw SessionValidationError.unsupportedPayloadType(payloadType)
        }
        if estimatedBandwidthMegabitsPerSecond >= bandwidthBudgetMegabitsPerSecond {
            throw SessionValidationError.videoBandwidthBudgetExceeded(
                streamID: id,
                requiredMegabitsPerSecond: estimatedBandwidthMegabitsPerSecond,
                budgetMegabitsPerSecond: bandwidthBudgetMegabitsPerSecond
            )
        }
    }
}

public struct VideoCapabilities: Codable, Equatable, Sendable {
    public var supportedRoles: [VideoStreamRole]
    public var supportedPixelFormats: [VideoPixelFormat]
    public var supportedTransportFormats: [VideoTransportFormat]
    public var maxWidth: Int
    public var maxHeight: Int
    public var maxFrameRateNumerator: Int
    public var maxEnabledStreams: Int

    public init(
        supportedRoles: [VideoStreamRole],
        supportedPixelFormats: [VideoPixelFormat],
        supportedTransportFormats: [VideoTransportFormat],
        maxWidth: Int,
        maxHeight: Int,
        maxFrameRateNumerator: Int,
        maxEnabledStreams: Int
    ) {
        self.supportedRoles = supportedRoles
        self.supportedPixelFormats = supportedPixelFormats
        self.supportedTransportFormats = supportedTransportFormats
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.maxFrameRateNumerator = maxFrameRateNumerator
        self.maxEnabledStreams = maxEnabledStreams
    }

    public func validate() throws {
        try SessionValidation.requirePositive(maxWidth, "video.maxWidth")
        try SessionValidation.requirePositive(maxHeight, "video.maxHeight")
        try SessionValidation.requirePositive(maxFrameRateNumerator, "video.maxFrameRateNumerator")
        if maxEnabledStreams < 0 {
            throw SessionValidationError.nonPositiveField("video.maxEnabledStreams")
        }
    }
}

extension VideoCapabilities: SessionVideoCapabilityNegotiating {
    public func validateForSessionCapabilities() throws {
        try validate()
    }
}
