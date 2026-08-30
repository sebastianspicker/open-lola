import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Defines negotiated audio transport mode contracts used by UDP negotiation and packetization.
import Foundation

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

package func udpPcmV2AudioTransportMode(
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
