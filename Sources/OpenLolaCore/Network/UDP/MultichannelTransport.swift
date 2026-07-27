// Implements MultichannelTransport media transport boundary, separating packet I/O from session policy.
import Foundation

/// Selects the UDP PCM wire version negotiated between peers.
public enum AudioTransportProtocolVersion: UInt8, Codable, Equatable, Sendable {
    case udpPcmV1 = 1
    case udpPcmV2 = 2
}
/// Defines how multichannel PCM samples are partitioned across UDP payloads.
public enum AudioWirePackingMode: String, Codable, Equatable, Sendable {
    case interleavedChannelRange

    public var wireValue: UInt8 {
        switch self {
        case .interleavedChannelRange:
            1
        }
    }

    public init?(wireValue: UInt8) {
        switch wireValue {
        case 1:
            self = .interleavedChannelRange
        default:
            return nil
        }
    }
}

/// Selects the latency-versus-resilience preset used during audio transport negotiation.
public enum LatencyProfile: String, Codable, Equatable, Sendable {
    case safeLowLatency
    case ultraLowLatency16
    case extremeLowLatency8
}

/// Classifies the hardware or synthetic source behind a negotiated audio channel.
public enum AudioChannelSourceKind: String, Codable, Equatable, Sendable {
    case coreAudio
    case documentedTotalMix
    case userProvided
}

/// Represents AudioChannelDescriptor values used by UDP media transport.
public struct AudioChannelDescriptor: Codable, Equatable, Hashable, Sendable {
    public var stableSourceIndex: Int
    public var label: String
    public var sourceKind: AudioChannelSourceKind

    public init(
        stableSourceIndex: Int,
        label: String? = nil,
        sourceKind: AudioChannelSourceKind = .coreAudio
    ) {
        self.stableSourceIndex = stableSourceIndex
        self.label = label ?? "channel-\(stableSourceIndex + 1)"
        self.sourceKind = sourceKind
    }
}

/// Represents AudioChannelSet values used by UDP media transport.
public struct AudioChannelSet: Codable, Equatable, Sendable {
    public var channels: [AudioChannelDescriptor]

    public init(channels: [AudioChannelDescriptor]) {
        self.channels = channels
    }

    public static func defaultInput(count: Int) -> AudioChannelSet {
        defaultSet(prefix: "input", count: count)
    }

    public static func defaultOutput(count: Int) -> AudioChannelSet {
        defaultSet(prefix: "output", count: count)
    }

    public var sortedByStableSourceIndex: [AudioChannelDescriptor] {
        channels.sorted { lhs, rhs in
            if lhs.stableSourceIndex == rhs.stableSourceIndex {
                return lhs.label < rhs.label
            }
            return lhs.stableSourceIndex < rhs.stableSourceIndex
        }
    }

    private static func defaultSet(prefix: String, count: Int) -> AudioChannelSet {
        guard count > 0 else {
            return AudioChannelSet(channels: [])
        }
        return AudioChannelSet(
            channels: (0..<count).map { index in
                AudioChannelDescriptor(
                    stableSourceIndex: index,
                    label: "\(prefix)-\(index + 1)"
                )
            }
        )
    }
}

/// Defines the AudioTransportCapabilities contract used to negotiate behavior across UDP media transport.
public struct AudioTransportCapabilities: Codable, Equatable, Sendable {
    public var supportedProtocolVersions: [AudioTransportProtocolVersion]
    public var supportedPayloadTypes: [SessionPayloadType]
    public var supportedAudioTransports: [DirectPeerSessionAudioTransport]
    public var channelSet: AudioChannelSet
    public var sampleRatesHertz: [Int]
    public var framesPerPacketOptions: [Int]
    public var sampleFormats: [UdpPcmSampleFormat]
    public var maxTransmissionUnitBytes: Int
    public var maxFragmentsPerDeadline: Int
    public var latencyProfiles: [LatencyProfile]
    public var rxBufferProfiles: [RxBufferProfile]
    public var supportsMatrixMetadata: Bool

    public struct TransportSupport: Equatable, Sendable {
        public var protocolVersions: [AudioTransportProtocolVersion]
        public var payloadTypes: [SessionPayloadType]
        public var audioTransports: [DirectPeerSessionAudioTransport]

        public init(
            protocolVersions: [AudioTransportProtocolVersion],
            payloadTypes: [SessionPayloadType] = [.audioPcmV2],
            audioTransports: [DirectPeerSessionAudioTransport] = [.openLolaRaw]
        ) {
            self.protocolVersions = protocolVersions
            self.payloadTypes = payloadTypes
            self.audioTransports = audioTransports
        }
    }

    public struct AudioSupport: Equatable, Sendable {
        public var channelSet: AudioChannelSet
        public var sampleRatesHertz: [Int]
        public var framesPerPacketOptions: [Int]
        public var sampleFormats: [UdpPcmSampleFormat]

        public init(
            channelSet: AudioChannelSet,
            sampleRatesHertz: [Int],
            framesPerPacketOptions: [Int],
            sampleFormats: [UdpPcmSampleFormat]
        ) {
            self.channelSet = channelSet
            self.sampleRatesHertz = sampleRatesHertz
            self.framesPerPacketOptions = framesPerPacketOptions
            self.sampleFormats = sampleFormats
        }
    }

    public struct OperationalLimits: Equatable, Sendable {
        public var maxTransmissionUnitBytes: Int
        public var maxFragmentsPerDeadline: Int
        public var latencyProfiles: [LatencyProfile]
        public var rxBufferProfiles: [RxBufferProfile]
        public var supportsMatrixMetadata: Bool

        public init(
            maxTransmissionUnitBytes: Int,
            maxFragmentsPerDeadline: Int,
            latencyProfiles: [LatencyProfile],
            rxBufferProfiles: [RxBufferProfile],
            supportsMatrixMetadata: Bool
        ) {
            self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
            self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
            self.latencyProfiles = latencyProfiles
            self.rxBufferProfiles = rxBufferProfiles
            self.supportsMatrixMetadata = supportsMatrixMetadata
        }
    }

    public init(transport: TransportSupport, audio: AudioSupport, limits: OperationalLimits) {
        supportedProtocolVersions = transport.protocolVersions
        supportedPayloadTypes = transport.payloadTypes
        supportedAudioTransports = transport.audioTransports
        channelSet = audio.channelSet
        sampleRatesHertz = audio.sampleRatesHertz
        framesPerPacketOptions = audio.framesPerPacketOptions
        sampleFormats = audio.sampleFormats
        maxTransmissionUnitBytes = limits.maxTransmissionUnitBytes
        maxFragmentsPerDeadline = limits.maxFragmentsPerDeadline
        latencyProfiles = limits.latencyProfiles
        rxBufferProfiles = limits.rxBufferProfiles
        supportsMatrixMetadata = limits.supportsMatrixMetadata
    }

    enum CodingKeys: String, CodingKey {
        case supportedProtocolVersions
        case supportedPayloadTypes
        case supportedAudioTransports
        case channelSet
        case sampleRatesHertz
        case framesPerPacketOptions
        case sampleFormats
        case maxTransmissionUnitBytes
        case maxFragmentsPerDeadline
        case latencyProfiles
        case rxBufferProfiles
        case supportsMatrixMetadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        supportedProtocolVersions = try container.decode(
[AudioTransportProtocolVersion].self,
forKey: .supportedProtocolVersions
)
        supportedPayloadTypes = try container.decodeIfPresent(
[SessionPayloadType].self,
forKey: .supportedPayloadTypes
) ?? [.audioPcmV2]
        supportedAudioTransports = try container.decodeIfPresent(
            [DirectPeerSessionAudioTransport].self,
            forKey: .supportedAudioTransports
        ) ?? supportedPayloadTypes.compactMap { payloadType in
            switch payloadType {
            case .audioPcmV2:
                return .openLolaRaw
            case .audioOpusCeltLowDelayFrame:
                return .openLolaOpusCeltLowDelay
            case .audioRtpL24:
                return .aes67ST2110L24
            default:
                return nil
            }
        }
        channelSet = try container.decode(AudioChannelSet.self, forKey: .channelSet)
        sampleRatesHertz = try container.decode([Int].self, forKey: .sampleRatesHertz)
        framesPerPacketOptions = try container.decode([Int].self, forKey: .framesPerPacketOptions)
        sampleFormats = try container.decode([UdpPcmSampleFormat].self, forKey: .sampleFormats)
        maxTransmissionUnitBytes = try container.decode(Int.self, forKey: .maxTransmissionUnitBytes)
        maxFragmentsPerDeadline = try container.decode(Int.self, forKey: .maxFragmentsPerDeadline)
        latencyProfiles = try container.decode([LatencyProfile].self, forKey: .latencyProfiles)
        rxBufferProfiles = try container.decode([RxBufferProfile].self, forKey: .rxBufferProfiles)
        supportsMatrixMetadata = try container.decode(Bool.self, forKey: .supportsMatrixMetadata)
    }
}

extension AudioTransportCapabilities: SessionAudioCapabilityNegotiating {
    public func validateForSessionCapabilities() throws {
        guard !channelSet.channels.isEmpty else {
            throw SessionValidationError.unsupportedChannelCount(requested: 1, available: 0)
        }
        try SessionValidation.requirePositive(
            maxTransmissionUnitBytes,
            "audio.maxTransmissionUnitBytes"
        )
        try SessionValidation.requirePositive(
            maxFragmentsPerDeadline,
            "audio.maxFragmentsPerDeadline"
        )
    }
}

/// Configures AudioTransportModeRequest so callers supply explicit inputs before starting UDP media transport.
public struct AudioTransportModeRequest: Codable, Equatable, Sendable {
    public var preferredProtocolVersion: AudioTransportProtocolVersion
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var latencyProfile: LatencyProfile
    public var rxBufferProfile: RxBufferProfile

    public init(
        preferredProtocolVersion: AudioTransportProtocolVersion,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        latencyProfile: LatencyProfile,
        rxBufferProfile: RxBufferProfile
    ) {
        self.preferredProtocolVersion = preferredProtocolVersion
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
    }
}

/// Reports a non-fatal downgrade made while selecting a compatible audio transport mode.
public enum AudioTransportNegotiationWarning: Codable, Equatable, Sendable {
    case fallbackToStereoV1(requestedChannelCount: Int)
    case preferredV2NotAvailable
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum AudioTransportNegotiationError: Error, Equatable, Sendable {
    case unsupportedSampleRate(Int)
    case unsupportedFramesPerPacket(Int)
    case unsupportedSampleFormat(UdpPcmSampleFormat)
    case unsupportedLatencyProfile(LatencyProfile)
    case unsupportedRxBufferProfile(RxBufferProfile)
    case insufficientSenderChannels(requested: Int, available: Int)
    case insufficientReceiverChannels(requested: Int, available: Int)
    case noCompatibleProtocol
    case noCompatibleV1StereoMode
    case v2FragmentationFailed(UdpPcmV2FragmentPlanningError)
}

/// Represents AudioTransportMode values used by UDP media transport.
public struct AudioTransportMode: Codable, Equatable, Sendable {
    public var protocolVersion: AudioTransportProtocolVersion
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var latencyProfile: LatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var maxTransmissionUnitBytes: Int
    public var channelOrder: [AudioChannelDescriptor]
    public var fragments: [UdpPcmV2ChannelFragmentPlan]

    public struct Transport: Equatable, Sendable {
        public var protocolVersion: AudioTransportProtocolVersion
        public var latencyProfile: LatencyProfile
        public var rxBufferProfile: RxBufferProfile
        public var maxTransmissionUnitBytes: Int

        public init(
            protocolVersion: AudioTransportProtocolVersion,
            latencyProfile: LatencyProfile,
            rxBufferProfile: RxBufferProfile,
            maxTransmissionUnitBytes: Int
        ) {
            self.protocolVersion = protocolVersion
            self.latencyProfile = latencyProfile
            self.rxBufferProfile = rxBufferProfile
            self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var framesPerPacket: Int
        public var channelCount: Int
        public var sampleFormat: UdpPcmSampleFormat

        public init(
            sampleRateHertz: Int,
            framesPerPacket: Int,
            channelCount: Int,
            sampleFormat: UdpPcmSampleFormat
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.channelCount = channelCount
            self.sampleFormat = sampleFormat
        }
    }

    public struct Layout: Equatable, Sendable {
        public var channelOrder: [AudioChannelDescriptor]
        public var fragments: [UdpPcmV2ChannelFragmentPlan]

        public init(
            channelOrder: [AudioChannelDescriptor],
            fragments: [UdpPcmV2ChannelFragmentPlan]
        ) {
            self.channelOrder = channelOrder
            self.fragments = fragments
        }
    }

    public init(transport: Transport, format: Format, layout: Layout) {
        protocolVersion = transport.protocolVersion
        sampleRateHertz = format.sampleRateHertz
        framesPerPacket = format.framesPerPacket
        channelCount = format.channelCount
        sampleFormat = format.sampleFormat
        latencyProfile = transport.latencyProfile
        rxBufferProfile = transport.rxBufferProfile
        maxTransmissionUnitBytes = transport.maxTransmissionUnitBytes
        channelOrder = layout.channelOrder
        fragments = layout.fragments
    }
}

func udpPcmV2AudioTransportMode(
    stream: AudioStreamDescription,
    fragments: [UdpPcmV2ChannelFragmentPlan],
    latencyProfile: LatencyProfile,
    rxBufferProfile: RxBufferProfile,
    maxTransmissionUnitBytes: Int
) -> AudioTransportMode {
    AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: latencyProfile,
            rxBufferProfile: rxBufferProfile,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes
        ),
        format: .init(
            sampleRateHertz: stream.sampleRateHertz,
            framesPerPacket: stream.framesPerPacket,
            channelCount: stream.channelCount,
            sampleFormat: stream.sampleFormat
        ),
        layout: .init(channelOrder: stream.channelOrder, fragments: fragments)
    )
}

public extension AudioTransportMode {
    var payloadByteCount: Int {
        framesPerPacket * channelCount * sampleFormat.bytesPerSample
    }
}

/// Represents the AudioTransportNegotiationResult produced by UDP media transport without exposing its execution state.
public struct AudioTransportNegotiationResult: Codable, Equatable, Sendable {
    public var mode: AudioTransportMode
    public var warnings: [AudioTransportNegotiationWarning]

    public init(
        mode: AudioTransportMode,
        warnings: [AudioTransportNegotiationWarning]
    ) {
        self.mode = mode
        self.warnings = warnings
    }
}
