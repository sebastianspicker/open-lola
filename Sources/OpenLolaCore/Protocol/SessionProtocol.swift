import Foundation

public enum SessionControlProtocol {
    public static let currentVersion = 1
}

public enum SessionLatencyProfile: String, Codable, Equatable, Sendable {
    case directAudioFirst
    case balancedAV
    case multiVideoPerformance
    case wanStable
}

public enum SessionVideoPressurePolicy: String, Codable, Equatable, Sendable {
    case disabled
    case singleStreamPaced
    case dropVideoBeforeAudioLatency
    case continuityFirstVideo
}

public enum SessionContinuityPriority: String, Codable, Equatable, Sendable {
    case latencyFirst
    case balanced
    case continuityFirst
}

public struct SessionLatencyProfilePolicy: Codable, Equatable, Sendable {
    public var profile: SessionLatencyProfile
    public var defaultRxBufferProfile: RxBufferProfile
    public var allowedRxBufferProfiles: [RxBufferProfile]
    public var maximumEnabledVideoStreams: Int
    public var requiresEnabledVideo: Bool
    public var fastestAudioPassEligible: Bool
    public var benchmarkEvidenceRequired: Bool
    public var videoPressurePolicy: SessionVideoPressurePolicy
    public var continuityPriority: SessionContinuityPriority

    public static func policy(for profile: SessionLatencyProfile) -> SessionLatencyProfilePolicy {
        let policy = switch profile {
        case .directAudioFirst:
            SessionLatencyProfilePolicy(
                profile: profile,
                defaultRxBufferProfile: .direct,
                allowedRxBufferProfiles: [.direct],
                maximumEnabledVideoStreams: 1,
                requiresEnabledVideo: false,
                fastestAudioPassEligible: true,
                benchmarkEvidenceRequired: false,
                videoPressurePolicy: .dropVideoBeforeAudioLatency,
                continuityPriority: .latencyFirst
            )
        case .balancedAV:
            SessionLatencyProfilePolicy(
                profile: profile,
                defaultRxBufferProfile: .small,
                allowedRxBufferProfiles: [.small],
                maximumEnabledVideoStreams: 1,
                requiresEnabledVideo: false,
                fastestAudioPassEligible: false,
                benchmarkEvidenceRequired: true,
                videoPressurePolicy: .singleStreamPaced,
                continuityPriority: .balanced
            )
        case .multiVideoPerformance:
            SessionLatencyProfilePolicy(
                profile: profile,
                defaultRxBufferProfile: .adaptive,
                allowedRxBufferProfiles: [.small, .adaptive],
                maximumEnabledVideoStreams: 4,
                requiresEnabledVideo: true,
                fastestAudioPassEligible: false,
                benchmarkEvidenceRequired: true,
                videoPressurePolicy: .dropVideoBeforeAudioLatency,
                continuityPriority: .balanced
            )
        case .wanStable:
            SessionLatencyProfilePolicy(
                profile: profile,
                defaultRxBufferProfile: .stableWan,
                allowedRxBufferProfiles: [.stableWan],
                maximumEnabledVideoStreams: 1,
                requiresEnabledVideo: false,
                fastestAudioPassEligible: false,
                benchmarkEvidenceRequired: true,
                videoPressurePolicy: .continuityFirstVideo,
                continuityPriority: .continuityFirst
            )
        }
        precondition(
            policy.allowedRxBufferProfiles.contains(policy.defaultRxBufferProfile),
            "SessionLatencyProfilePolicy default RX buffer must be allowed"
        )
        return policy
    }
}

public struct SessionNetworkEndpoint: Codable, Equatable, Sendable {
    public var host: String
    public var port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public func validate(fieldPrefix: String) throws {
        try SessionValidation.requireNonEmpty(host, "\(fieldPrefix).host")
        try SessionValidation.requirePort(port, "\(fieldPrefix).port")
    }
}

public struct SessionPeerMediaEndpoints: Codable, Equatable, Sendable {
    public var peerID: String
    public var controlEndpoint: SessionNetworkEndpoint
    public var audioEndpoint: SessionNetworkEndpoint
    public var videoEndpoint: SessionNetworkEndpoint
    public var metricsEndpoint: SessionNetworkEndpoint

    public init(
        peerID: String,
        controlEndpoint: SessionNetworkEndpoint,
        audioEndpoint: SessionNetworkEndpoint,
        videoEndpoint: SessionNetworkEndpoint,
        metricsEndpoint: SessionNetworkEndpoint
    ) {
        self.peerID = peerID
        self.controlEndpoint = controlEndpoint
        self.audioEndpoint = audioEndpoint
        self.videoEndpoint = videoEndpoint
        self.metricsEndpoint = metricsEndpoint
    }

    public func validate(fieldPrefix: String) throws {
        try SessionValidation.requireNonEmpty(peerID, "\(fieldPrefix).peerID")
        try controlEndpoint.validate(fieldPrefix: "\(fieldPrefix).controlEndpoint")
        try audioEndpoint.validate(fieldPrefix: "\(fieldPrefix).audioEndpoint")
        try videoEndpoint.validate(fieldPrefix: "\(fieldPrefix).videoEndpoint")
        try metricsEndpoint.validate(fieldPrefix: "\(fieldPrefix).metricsEndpoint")
    }
}

public struct SessionTransportCapabilities: Codable, Equatable, Sendable {
    public var supportsDirectUDP: Bool
    public var supportsRendezvous: Bool
    public var minMTUBytes: Int
    public var maxMTUBytes: Int

    public init(
        supportsDirectUDP: Bool,
        supportsRendezvous: Bool,
        minMTUBytes: Int,
        maxMTUBytes: Int
    ) {
        self.supportsDirectUDP = supportsDirectUDP
        self.supportsRendezvous = supportsRendezvous
        self.minMTUBytes = minMTUBytes
        self.maxMTUBytes = maxMTUBytes
    }

    public func validate() throws {
        try SessionValidation.requirePositive(minMTUBytes, "transport.minMTUBytes")
        try SessionValidation.requirePositive(maxMTUBytes, "transport.maxMTUBytes")
        if minMTUBytes > maxMTUBytes {
            throw SessionValidationError.invalidMTURange(
                minimum: minMTUBytes,
                maximum: maxMTUBytes
            )
        }
    }
}

public struct CapabilitySet: PrettyJSONCodable, Equatable, Sendable {
    public var peer: PeerIdentity
    public var supportedControlVersions: [Int]
    public var audio: AudioTransportCapabilities
    public var video: VideoCapabilities
    public var transport: SessionTransportCapabilities
    public var latencyProfiles: [SessionLatencyProfile]
    public var rxBufferProfiles: [RxBufferProfile]

    public init(
        peer: PeerIdentity,
        supportedControlVersions: [Int],
        audio: AudioTransportCapabilities,
        video: VideoCapabilities,
        transport: SessionTransportCapabilities,
        latencyProfiles: [SessionLatencyProfile],
        rxBufferProfiles: [RxBufferProfile]
    ) {
        self.peer = peer
        self.supportedControlVersions = supportedControlVersions
        self.audio = audio
        self.video = video
        self.transport = transport
        self.latencyProfiles = latencyProfiles
        self.rxBufferProfiles = rxBufferProfiles
    }

    public func validate() throws {
        try peer.validate()
        guard supportedControlVersions.contains(SessionControlProtocol.currentVersion) else {
            throw SessionValidationError.unsupportedControlVersion(
                SessionControlProtocol.currentVersion
            )
        }
        try audio.validateForSessionCapabilities()
        try video.validateForSessionCapabilities()
        try transport.validate()
        for profile in latencyProfiles {
            _ = SessionLatencyProfilePolicy.policy(for: profile)
        }
    }
}

public struct SessionProposal: PrettyJSONCodable, Equatable, Sendable {
    public var sessionID: String
    public var proposer: PeerIdentity
    public var responder: PeerIdentity
    public var latencyProfile: SessionLatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var audioStreams: [AudioStreamDescription]
    public var videoStreams: [VideoStreamDescription]
    public var controlEndpoint: SessionNetworkEndpoint
    public var audioEndpoint: SessionNetworkEndpoint
    public var videoEndpoint: SessionNetworkEndpoint
    public var metricsEndpoint: SessionNetworkEndpoint
    public var mtuBytes: Int
    public var reconnectDeadlineMilliseconds: Int?

    public init(
        sessionID: String,
        proposer: PeerIdentity,
        responder: PeerIdentity,
        latencyProfile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        audioStreams: [AudioStreamDescription],
        videoStreams: [VideoStreamDescription],
        controlEndpoint: SessionNetworkEndpoint,
        audioEndpoint: SessionNetworkEndpoint,
        videoEndpoint: SessionNetworkEndpoint,
        metricsEndpoint: SessionNetworkEndpoint,
        mtuBytes: Int,
        reconnectDeadlineMilliseconds: Int? = nil
    ) {
        self.sessionID = sessionID
        self.proposer = proposer
        self.responder = responder
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
        self.audioStreams = audioStreams
        self.videoStreams = videoStreams
        self.controlEndpoint = controlEndpoint
        self.audioEndpoint = audioEndpoint
        self.videoEndpoint = videoEndpoint
        self.metricsEndpoint = metricsEndpoint
        self.mtuBytes = mtuBytes
        self.reconnectDeadlineMilliseconds = reconnectDeadlineMilliseconds
    }
}

public struct SessionConfiguration: PrettyJSONCodable, Equatable, Sendable {
    public var sessionID: String
    public var peers: [PeerIdentity]
    public var latencyProfile: SessionLatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var audioStreams: [AudioStreamDescription]
    public var videoStreams: [VideoStreamDescription]
    public var controlEndpoint: SessionNetworkEndpoint
    public var audioEndpoint: SessionNetworkEndpoint
    public var videoEndpoint: SessionNetworkEndpoint
    public var metricsEndpoint: SessionNetworkEndpoint
    public var peerMediaEndpoints: [SessionPeerMediaEndpoints]?
    public var mtuBytes: Int
    public var metricIntervalMilliseconds: Int
    public var reconnectDeadlineMilliseconds: Int

    public init(
        sessionID: String,
        peers: [PeerIdentity],
        latencyProfile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        audioStreams: [AudioStreamDescription],
        videoStreams: [VideoStreamDescription],
        controlEndpoint: SessionNetworkEndpoint,
        audioEndpoint: SessionNetworkEndpoint,
        videoEndpoint: SessionNetworkEndpoint,
        metricsEndpoint: SessionNetworkEndpoint,
        peerMediaEndpoints: [SessionPeerMediaEndpoints]? = nil,
        mtuBytes: Int,
        metricIntervalMilliseconds: Int,
        reconnectDeadlineMilliseconds: Int
    ) {
        self.sessionID = sessionID
        self.peers = peers
        self.latencyProfile = latencyProfile
        self.rxBufferProfile = rxBufferProfile
        self.audioStreams = audioStreams
        self.videoStreams = videoStreams
        self.controlEndpoint = controlEndpoint
        self.audioEndpoint = audioEndpoint
        self.videoEndpoint = videoEndpoint
        self.metricsEndpoint = metricsEndpoint
        self.peerMediaEndpoints = peerMediaEndpoints
        self.mtuBytes = mtuBytes
        self.metricIntervalMilliseconds = metricIntervalMilliseconds
        self.reconnectDeadlineMilliseconds = reconnectDeadlineMilliseconds
    }

    public func validatePeerMediaTopology(minimumPeerCount: Int = 2) throws {
        try SessionValidation.requirePositive(minimumPeerCount, "minimumPeerCount")
        if peers.count < minimumPeerCount {
            throw SessionValidationError.peerCountBelowMinimum(
                requested: peers.count,
                minimum: minimumPeerCount
            )
        }

        var configuredPeerIDs = Set<String>()
        for peer in peers {
            try peer.validate(fieldPrefix: "configuration.peers")
            if !configuredPeerIDs.insert(peer.peerID).inserted {
                throw SessionValidationError.duplicatePeerID(peer.peerID)
            }
        }

        guard let peerMediaEndpoints else {
            throw SessionValidationError.emptyField("configuration.peerMediaEndpoints")
        }

        var endpointPeerIDs = Set<String>()
        var controlEndpoints = Set<EndpointIdentity>()
        var audioEndpoints = Set<EndpointIdentity>()
        var videoEndpoints = Set<EndpointIdentity>()
        var metricsEndpoints = Set<EndpointIdentity>()
        var allMediaEndpoints = Set<EndpointIdentity>()

        for endpoint in peerMediaEndpoints {
            try endpoint.validate(fieldPrefix: "configuration.peerMediaEndpoints")
            guard configuredPeerIDs.contains(endpoint.peerID) else {
                throw SessionValidationError.unexpectedPeerMediaEndpoint(peerID: endpoint.peerID)
            }
            if !endpointPeerIDs.insert(endpoint.peerID).inserted {
                throw SessionValidationError.duplicatePeerID(endpoint.peerID)
            }
            try insertUniqueEndpoint(
                endpoint.controlEndpoint,
                channel: "control",
                into: &controlEndpoints
            )
            try insertUniqueEndpoint(endpoint.controlEndpoint, channel: "control", into: &allMediaEndpoints)
            try insertUniqueEndpoint(endpoint.audioEndpoint, channel: "audio", into: &audioEndpoints)
            try insertUniqueEndpoint(endpoint.audioEndpoint, channel: "audio", into: &allMediaEndpoints)
            try insertUniqueEndpoint(endpoint.videoEndpoint, channel: "video", into: &videoEndpoints)
            try insertUniqueEndpoint(endpoint.videoEndpoint, channel: "video", into: &allMediaEndpoints)
            try insertUniqueEndpoint(
                endpoint.metricsEndpoint,
                channel: "metrics",
                into: &metricsEndpoints
            )
            try insertUniqueEndpoint(endpoint.metricsEndpoint, channel: "metrics", into: &allMediaEndpoints)
        }

        for peerID in configuredPeerIDs where !endpointPeerIDs.contains(peerID) {
            throw SessionValidationError.missingPeerMediaEndpoint(peerID: peerID)
        }
    }

    private func insertUniqueEndpoint(
        _ endpoint: SessionNetworkEndpoint,
        channel: String,
        into endpoints: inout Set<EndpointIdentity>
    ) throws {
        let identity = EndpointIdentity(host: endpoint.host, port: endpoint.port)
        if !endpoints.insert(identity).inserted {
            throw SessionValidationError.duplicatePeerMediaEndpoint(
                channel: channel,
                host: endpoint.host,
                port: endpoint.port
            )
        }
    }
}

private struct EndpointIdentity: Hashable {
    var host: String
    var port: UInt16
}
