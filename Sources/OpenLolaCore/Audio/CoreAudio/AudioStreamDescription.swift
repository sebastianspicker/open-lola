public enum MediaStreamDirection: String, Codable, Equatable, Sendable {
    case send
    case receive
    case bidirectional
    case disabled
}

public enum SessionPayloadType: Int, Codable, Equatable, Hashable, Sendable {
    case audioPcmV2 = 1
    case audioTiming = 2
    case audioOpusCeltLowDelayFrame = 3
    case audioRtpL24 = 4
    case videoRawFrameFragment = 16
    case videoVideoToolboxFragment = 17
    case videoJpegXSFrameFragment = 18
    case metrics = 32
    case keepalive = 48
}

public struct AudioStreamDescription: Codable, Equatable, Sendable {
    public var id: Int
    public var direction: MediaStreamDirection
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var channelCount: Int
    public var channelOrder: [AudioChannelDescriptor]
    public var clockDomain: String
    public var framesPerPacket: Int
    public var payloadType: SessionPayloadType

    public init(
        id: Int,
        direction: MediaStreamDirection,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        channelCount: Int,
        channelOrder: [AudioChannelDescriptor],
        clockDomain: String,
        framesPerPacket: Int,
        payloadType: SessionPayloadType
    ) {
        self.id = id
        self.direction = direction
        self.sampleRateHertz = sampleRateHertz
        self.sampleFormat = sampleFormat
        self.channelCount = channelCount
        self.channelOrder = channelOrder
        self.clockDomain = clockDomain
        self.framesPerPacket = framesPerPacket
        self.payloadType = payloadType
    }

    public func validate() throws {
        try SessionValidation.requirePositive(id, "audioStream.id")
        try SessionValidation.requirePositive(sampleRateHertz, "audioStream.sampleRateHertz")
        try SessionValidation.requirePositive(channelCount, "audioStream.channelCount")
        try SessionValidation.requirePositive(framesPerPacket, "audioStream.framesPerPacket")
        try SessionValidation.requireNonEmpty(clockDomain, "audioStream.clockDomain")
        guard payloadType == .audioPcmV2
            || payloadType == .audioOpusCeltLowDelayFrame
            || payloadType == .audioRtpL24 else {
            throw SessionValidationError.unsupportedPayloadType(payloadType)
        }
        guard channelOrder.count == channelCount else {
            throw SessionValidationError.audioChannelOrderMismatch(
                expected: channelCount,
                actual: channelOrder.count
            )
        }
        try validateUniqueChannelIndices()
    }

    private func validateUniqueChannelIndices() throws {
        var seen = Set<Int>()
        for channel in channelOrder {
            if channel.stableSourceIndex < 0 {
                throw SessionValidationError.negativeField("audioStream.channelOrder.stableSourceIndex")
            }
            if !seen.insert(channel.stableSourceIndex).inserted {
                throw SessionValidationError.duplicateChannelIndex(channel.stableSourceIndex)
            }
        }
    }
}
