import Foundation

public enum PeerSessionLifecycleState: String, Codable, Equatable, Sendable {
    case idle
    case handshaking
    case configured
    case mediaStarting
    case running
    case recovering
    case shuttingDown
    case closed
    case failed
}

public enum PeerSessionRunnerError: Error, Equatable, Sendable {
    case mediaStartBeforeAcceptedConfiguration
    case missingAcceptedConfiguration
    case missingRemoteCapabilities
    case missingPeerMediaEndpoint(String)
    case missingAudioTransport
    case missingVideoTransport
    case missingMetricsTransport
    case missingAudioStream
    case missingAudioRouter
    case unsupportedControlMessage(SessionControlMessageType)
    case unsupportedAudioSampleFormat(UdpPcmSampleFormat)
    case unsupportedRTPAudioClock(sampleRateHertz: Int)
}

public struct DirectPeerSessionMetrics: Codable, Equatable, Sendable {
    public var controlMessagesSent: Int = 0
    public var mediaPacketsSent: Int = 0
    public var mediaPacketsReceived: Int = 0
    public var audioPacketsRouted: Int = 0
    public var videoPacketsRouted: Int = 0
    public var audioPayloadsSentOnControlChannel: Int = 0
    public var mediaStartBoundaries: Int = 0
    public var mediaStopBoundaries: Int = 0
    public var recoveryEvents: Int = 0
    public var shutdownRequests: Int = 0
    public var audioMetadataMessagesSent: Int = 0
    public var audioMetadataMessagesReceived: Int = 0
    public var audioMetadataUpdatesRateLimited: Int = 0
    public var audioMetadataUpdatesStaleOrDuplicate: Int = 0
    public var timingProbePacketsSent: Int = 0
    public var timingProbePacketsReceived: Int = 0
    public var timingProbeMaxAgeMicroseconds: Double = 0
    public var metricsMessagesSent: Int = 0
    public var remoteMetricsMessagesReceived: Int = 0
    public var remotePacketsLost: Int = 0
    public var remoteJitterMicroseconds: Double = 0
    public var remoteLatePackets: Int = 0
    public var remoteCallbackDurationP99Microseconds: Double = 0
    public var remoteQueueDepthPackets: Int = 0
    public var remoteCPUPercent: Double = 0
    public var remoteMemoryResidentBytes: UInt64 = 0
    public var remoteUnderruns: Int = 0
    public var remoteOverruns: Int = 0
    public var remoteVideoFramesDropped: Int = 0

    public init() {}
}

struct PeerSessionReceivedAudioMediaPacket {
    var packet: UdpMediaPacket
    var decodedPcmV2: UdpPcmV2Packet?
    var decodedOpusCeltLowDelay: AudioOpusCeltLowDelayPacket?

    init(
        packet: UdpMediaPacket,
        decodedPcmV2: UdpPcmV2Packet? = nil,
        decodedOpusCeltLowDelay: AudioOpusCeltLowDelayPacket? = nil
    ) {
        self.packet = packet
        self.decodedPcmV2 = decodedPcmV2
        self.decodedOpusCeltLowDelay = decodedOpusCeltLowDelay
    }
}

struct PeerSessionReceivedVideoMediaPacket {
    var packet: UdpMediaPacket
    var decodedFragment: VideoTransportFragment?

    init(
        packet: UdpMediaPacket,
        decodedFragment: VideoTransportFragment? = nil
    ) {
        self.packet = packet
        self.decodedFragment = decodedFragment
    }
}
