import Foundation

public struct PeerIdentity: Codable, Equatable, Hashable, Sendable {
    public var peerID: String
    public var displayName: String
    public var implementationName: String
    public var implementationVersion: String
    public var publicKeyFingerprint: String?

    public init(
        peerID: String,
        displayName: String,
        implementationName: String,
        implementationVersion: String,
        publicKeyFingerprint: String? = nil
    ) {
        self.peerID = peerID
        self.displayName = displayName
        self.implementationName = implementationName
        self.implementationVersion = implementationVersion
        self.publicKeyFingerprint = publicKeyFingerprint
    }

    public func validate(fieldPrefix: String = "peer") throws {
        try SessionValidation.requireNonEmpty(peerID, "\(fieldPrefix).peerID")
        try SessionValidation.requireCLISafeIdentifier(peerID, "\(fieldPrefix).peerID")
        try SessionValidation.requireNonEmpty(displayName, "\(fieldPrefix).displayName")
        try SessionValidation.requireNonEmpty(implementationName, "\(fieldPrefix).implementationName")
        try SessionValidation.requireNonEmpty(
            implementationVersion,
            "\(fieldPrefix).implementationVersion"
        )
        if let publicKeyFingerprint {
            try SessionValidation.requireNonEmpty(
                publicKeyFingerprint,
                "\(fieldPrefix).publicKeyFingerprint"
            )
        }
    }
}

public enum SessionValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case negativeField(String)
    case nonPositiveField(String)
    case invalidPort(String)
    case peerCountBelowMinimum(requested: Int, minimum: Int)
    case duplicatePeerID(String)
    case missingPeerMediaEndpoint(peerID: String)
    case unexpectedPeerMediaEndpoint(peerID: String)
    case duplicatePeerMediaEndpoint(channel: String, host: String, port: UInt16)
    case invalidStreamID(Int)
    case duplicateStreamID(Int)
    case duplicateChannelIndex(Int)
    case peerMismatch(expected: String, actual: String)
    case unsupportedControlVersion(Int)
    case unsupportedLatencyProfile(SessionLatencyProfile)
    case unsupportedRxBufferProfile(RxBufferProfile)
    case unsupportedSampleRate(Int)
    case unsupportedFramesPerPacket(Int)
    case unsupportedSampleFormat(UdpPcmSampleFormat)
    case unsupportedChannelCount(requested: Int, available: Int)
    case audioChannelOrderMismatch(expected: Int, actual: Int)
    case unsupportedPayloadType(SessionPayloadType)
    case unsupportedVideoRole(VideoStreamRole)
    case unsupportedVideoPixelFormat(VideoPixelFormat)
    case unsupportedVideoTransportFormat(VideoTransportFormat)
    case unsupportedVideoResolution(width: Int, height: Int)
    case unsupportedVideoFrameRate(numerator: Int, denominator: Int)
    case videoBandwidthBudgetExceeded(
        streamID: Int,
        requiredMegabitsPerSecond: Double,
        budgetMegabitsPerSecond: Double
    )
    case tooManyEnabledVideoStreams(requested: Int, maximum: Int)
    case profileDisallowsEnabledVideo(SessionLatencyProfile)
    case profileRequiresEnabledVideo(SessionLatencyProfile)
    case mtuOutOfRange(requested: Int, minimum: Int, maximum: Int)
    case invalidMTURange(minimum: Int, maximum: Int)
    case invalidCLIIdentifier(field: String, value: String)
}

public enum SessionValidation {
    public static func requireNonEmpty(_ value: String, _ field: String) throws {
        if value.isEmpty {
            throw SessionValidationError.emptyField(field)
        }
    }

    public static func requirePositive(_ value: Int, _ field: String) throws {
        if value <= 0 {
            throw SessionValidationError.nonPositiveField(field)
        }
    }

    public static func requirePort(_ value: UInt16, _ field: String) throws {
        if value == 0 {
            throw SessionValidationError.invalidPort(field)
        }
    }

    public static func requireCLISafeIdentifier(_ value: String, _ field: String) throws {
        guard value.unicodeScalars.allSatisfy(isCLISafeIdentifierScalar) else {
            throw SessionValidationError.invalidCLIIdentifier(field: field, value: value)
        }
    }

    private static func isCLISafeIdentifierScalar(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || (48...57).contains(scalar.value)
            || scalar == "."
            || scalar == "_"
            || scalar == "-"
    }
}
