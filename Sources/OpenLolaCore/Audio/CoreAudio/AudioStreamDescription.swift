// Implements AudioStreamDescription audio-path behavior, isolating device and sample handling from higher-level routing.
/// Defines `send`, `receive`, `bidirectional`, and `disabled` states used to make media stream direction decisions in CoreAudio discovery.
public enum MediaStreamDirection: String, Codable, Equatable, Sendable {
    case send
    case receive
    case bidirectional
    case disabled
}

/// Defines `audioPcmV2`, `audioTiming`, `audioOpusCeltLowDelayFrame`, and `audioRtpL24` states used to make session payload type decisions in CoreAudio discovery.
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

/// Describes `id`, `direction`, `sampleRateHertz`, and `sampleFormat` so Core Audio discovery can select and identify a compatible source or format.
public struct AudioStreamDescription: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: Int
        public var direction: MediaStreamDirection
        public var clockDomain: String

        public init(id: Int, direction: MediaStreamDirection, clockDomain: String) {
            self.id = id
            self.direction = direction
            self.clockDomain = clockDomain
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var sampleFormat: UdpPcmSampleFormat
        public var channelCount: Int
        public var channelOrder: [AudioChannelDescriptor]

        public init(
            sampleRateHertz: Int,
            sampleFormat: UdpPcmSampleFormat,
            channelCount: Int,
            channelOrder: [AudioChannelDescriptor]
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.sampleFormat = sampleFormat
            self.channelCount = channelCount
            self.channelOrder = channelOrder
        }
    }

    public struct Packet: Equatable, Sendable {
        public var framesPerPacket: Int
        public var payloadType: SessionPayloadType

        public init(framesPerPacket: Int, payloadType: SessionPayloadType) {
            self.framesPerPacket = framesPerPacket
            self.payloadType = payloadType
        }
    }

 public var id: Int
 public var direction: MediaStreamDirection
 public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var channelCount: Int
    public var channelOrder: [AudioChannelDescriptor]
    public var clockDomain: String
    public var framesPerPacket: Int
    public var payloadType: SessionPayloadType

    public init(identity: Identity, format: Format, packet: Packet) {
        self.id = identity.id
        self.direction = identity.direction
        self.sampleRateHertz = format.sampleRateHertz
        self.sampleFormat = format.sampleFormat
        self.channelCount = format.channelCount
        self.channelOrder = format.channelOrder
        self.clockDomain = identity.clockDomain
        self.framesPerPacket = packet.framesPerPacket
        self.payloadType = packet.payloadType
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
