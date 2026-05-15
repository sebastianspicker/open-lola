import Foundation

public enum AudioTransportProtocolVersion: UInt8, Codable, Equatable, Sendable {
    case udpPcmV1 = 1
    case udpPcmV2 = 2
}

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

public enum LatencyProfile: String, Codable, Equatable, Sendable {
    case safeLowLatency
    case ultraLowLatency16
    case extremeLowLatency8
}

public enum AudioChannelSourceKind: String, Codable, Equatable, Sendable {
    case coreAudio
    case documentedTotalMix
    case userProvided
}

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

    public init(
        supportedProtocolVersions: [AudioTransportProtocolVersion],
        supportedPayloadTypes: [SessionPayloadType] = [.audioPcmV2],
        supportedAudioTransports: [DirectPeerSessionAudioTransport] = [.openLolaRaw],
        channelSet: AudioChannelSet,
        sampleRatesHertz: [Int],
        framesPerPacketOptions: [Int],
        sampleFormats: [UdpPcmSampleFormat],
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        latencyProfiles: [LatencyProfile],
        rxBufferProfiles: [RxBufferProfile],
        supportsMatrixMetadata: Bool
    ) {
        self.supportedProtocolVersions = supportedProtocolVersions
        self.supportedPayloadTypes = supportedPayloadTypes
        self.supportedAudioTransports = supportedAudioTransports
        self.channelSet = channelSet
        self.sampleRatesHertz = sampleRatesHertz
        self.framesPerPacketOptions = framesPerPacketOptions
        self.sampleFormats = sampleFormats
        self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
        self.latencyProfiles = latencyProfiles
        self.rxBufferProfiles = rxBufferProfiles
        self.supportsMatrixMetadata = supportsMatrixMetadata
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
        supportedProtocolVersions = try container.decode([AudioTransportProtocolVersion].self, forKey: .supportedProtocolVersions)
        supportedPayloadTypes = try container.decodeIfPresent([SessionPayloadType].self, forKey: .supportedPayloadTypes) ?? [.audioPcmV2]
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

public enum AudioTransportNegotiationWarning: Codable, Equatable, Sendable {
    case fallbackToStereoV1(requestedChannelCount: Int)
    case preferredV2NotAvailable
}

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

    public init(
        protocolVersion: AudioTransportProtocolVersion,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        latencyProfile: LatencyProfile,
        rxBufferProfile: RxBufferProfile,
        maxTransmissionUnitBytes: Int,
        channelOrder: [AudioChannelDescriptor],
        fragments: [UdpPcmV2ChannelFragmentPlan]
    ) {
        self.protocolVersion = protocolVersion
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
        self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        self.channelOrder = channelOrder
        self.fragments = fragments
    }
}

public extension AudioTransportMode {
    var payloadByteCount: Int {
        framesPerPacket * channelCount * sampleFormat.bytesPerSample
    }
}

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

public enum AudioTransportNegotiation {
    public static func negotiate(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest
    ) throws -> AudioTransportNegotiationResult {
        try validateCommonFields(sender: sender, receiver: receiver, request: request)

        let senderChannels = sender.channelSet.sortedByStableSourceIndex
        guard senderChannels.count >= request.channelCount else {
            throw AudioTransportNegotiationError.insufficientSenderChannels(
                requested: request.channelCount,
                available: senderChannels.count
            )
        }

        let receiverChannels = receiver.channelSet.sortedByStableSourceIndex
        let sharedProtocols = Set(sender.supportedProtocolVersions)
            .intersection(receiver.supportedProtocolVersions)

        if request.preferredProtocolVersion == .udpPcmV2,
           sharedProtocols.contains(.udpPcmV2),
           sender.sampleFormats.contains(request.sampleFormat),
           receiver.sampleFormats.contains(request.sampleFormat),
           receiverChannels.count >= request.channelCount {
            return try negotiateV2(
                sender: sender,
                receiver: receiver,
                request: request,
                channelOrder: Array(senderChannels.prefix(request.channelCount))
            )
        }

        if sharedProtocols.contains(.udpPcmV1) {
            return try negotiateStereoV1(
                sender: sender,
                receiver: receiver,
                request: request,
                senderChannels: senderChannels,
                receiverChannels: receiverChannels
            )
        }

        if receiverChannels.count < request.channelCount {
            throw AudioTransportNegotiationError.insufficientReceiverChannels(
                requested: request.channelCount,
                available: receiverChannels.count
            )
        }
        guard sender.sampleFormats.contains(request.sampleFormat),
              receiver.sampleFormats.contains(request.sampleFormat) else {
            throw AudioTransportNegotiationError.unsupportedSampleFormat(request.sampleFormat)
        }
        throw AudioTransportNegotiationError.noCompatibleProtocol
    }

    private static func negotiateV2(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest,
        channelOrder: [AudioChannelDescriptor]
    ) throws -> AudioTransportNegotiationResult {
        let mtu = min(sender.maxTransmissionUnitBytes, receiver.maxTransmissionUnitBytes)
        let fragmentLimit = min(sender.maxFragmentsPerDeadline, receiver.maxFragmentsPerDeadline)
        let fragments: [UdpPcmV2ChannelFragmentPlan]
        do {
            fragments = try UdpPcmV2FragmentPlanner.plan(
                UdpPcmV2FragmentPlanRequest(
                    streamID: 1,
                    totalChannelCount: request.channelCount,
                    framesPerPacket: request.framesPerPacket,
                    sampleRateHertz: request.sampleRateHertz,
                    sampleFormat: request.sampleFormat,
                    maxTransmissionUnitBytes: mtu,
                    maxFragmentsPerDeadline: fragmentLimit,
                    metadataRevision: 0,
                    packingMode: .interleavedChannelRange
                )
            )
        } catch let error as UdpPcmV2FragmentPlanningError {
            throw AudioTransportNegotiationError.v2FragmentationFailed(error)
        }

        return AudioTransportNegotiationResult(
            mode: AudioTransportMode(
                protocolVersion: .udpPcmV2,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                channelCount: request.channelCount,
                sampleFormat: request.sampleFormat,
                latencyProfile: request.latencyProfile,
                rxBufferProfile: request.rxBufferProfile,
                maxTransmissionUnitBytes: mtu,
                channelOrder: channelOrder,
                fragments: fragments
            ),
            warnings: []
        )
    }

    private static func negotiateStereoV1(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest,
        senderChannels: [AudioChannelDescriptor],
        receiverChannels: [AudioChannelDescriptor]
    ) throws -> AudioTransportNegotiationResult {
        guard senderChannels.count >= 2, receiverChannels.count >= 2 else {
            throw AudioTransportNegotiationError.noCompatibleV1StereoMode
        }
        guard let sampleFormat = v1SampleFormat(sender: sender, receiver: receiver) else {
            throw AudioTransportNegotiationError.noCompatibleV1StereoMode
        }

        return AudioTransportNegotiationResult(
            mode: AudioTransportMode(
                protocolVersion: .udpPcmV1,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                channelCount: 2,
                sampleFormat: sampleFormat,
                latencyProfile: request.latencyProfile,
                rxBufferProfile: request.rxBufferProfile,
                maxTransmissionUnitBytes: min(
                    sender.maxTransmissionUnitBytes,
                    receiver.maxTransmissionUnitBytes
                ),
                channelOrder: Array(senderChannels.prefix(2)),
                fragments: []
            ),
            warnings: stereoV1FallbackWarnings(request: request)
        )
    }

    private static func stereoV1FallbackWarnings(
        request: AudioTransportModeRequest
    ) -> [AudioTransportNegotiationWarning] {
        var warnings: [AudioTransportNegotiationWarning] = []
        if request.preferredProtocolVersion == .udpPcmV2 {
            warnings.append(.preferredV2NotAvailable)
        }
        if request.channelCount != 2 {
            warnings.append(.fallbackToStereoV1(requestedChannelCount: request.channelCount))
        }
        return warnings
    }

    private static func validateCommonFields(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities,
        request: AudioTransportModeRequest
    ) throws {
        guard sender.sampleRatesHertz.contains(request.sampleRateHertz),
              receiver.sampleRatesHertz.contains(request.sampleRateHertz) else {
            throw AudioTransportNegotiationError.unsupportedSampleRate(request.sampleRateHertz)
        }
        guard sender.framesPerPacketOptions.contains(request.framesPerPacket),
              receiver.framesPerPacketOptions.contains(request.framesPerPacket) else {
            throw AudioTransportNegotiationError.unsupportedFramesPerPacket(
                request.framesPerPacket
            )
        }
        guard sender.latencyProfiles.contains(request.latencyProfile),
              receiver.latencyProfiles.contains(request.latencyProfile) else {
            throw AudioTransportNegotiationError.unsupportedLatencyProfile(request.latencyProfile)
        }
        guard sender.rxBufferProfiles.contains(request.rxBufferProfile),
              receiver.rxBufferProfiles.contains(request.rxBufferProfile) else {
            throw AudioTransportNegotiationError.unsupportedRxBufferProfile(request.rxBufferProfile)
        }
    }

    private static func v1SampleFormat(
        sender: AudioTransportCapabilities,
        receiver: AudioTransportCapabilities
    ) -> UdpPcmSampleFormat? {
        if sender.sampleFormats.contains(.int16LittleEndian),
           receiver.sampleFormats.contains(.int16LittleEndian) {
            return .int16LittleEndian
        }
        if sender.sampleFormats.contains(.float32LittleEndian),
           receiver.sampleFormats.contains(.float32LittleEndian) {
            return .float32LittleEndian
        }
        return nil
    }
}
