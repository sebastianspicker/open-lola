// Defines versioned session capabilities, proposals, and negotiated configurations with validation kept beside the wire-facing models.
import Foundation

/// Names the current control-protocol version required during capability validation.
public enum SessionControlProtocol {
    public static let currentVersion = 1
}

/// Selects the latency, resilience, and multi-video trade-off requested for a session.
public enum SessionLatencyProfile: String, Codable, Equatable, Sendable {
    case directAudioFirst
    case balancedAV
    case multiVideoPerformance
    case wanStable
}

/// Selects how video pacing and degradation respond before audio latency is affected.
public enum SessionVideoPressurePolicy: String, Codable, Equatable, Sendable {
    case disabled
    case singleStreamPaced
    case dropVideoBeforeAudioLatency
    case continuityFirstVideo
}

/// Orders latency against continuity when transport pressure forces a policy choice.
public enum SessionContinuityPriority: String, Codable, Equatable, Sendable {
    case latencyFirst
    case balanced
    case continuityFirst
}

/// Identifies one validated host and UDP port used by the session topology.
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

/// Groups one peer's distinct control, audio, video, and metrics endpoints.
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

/// Advertises supported route modes and the valid MTU range for negotiation.
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

/// Advertises one peer's control, media, route, latency, and receive-buffer capabilities.
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

/// Groups the latency and receive-buffer profiles selected for a session.
public struct SessionMediaProfile: Equatable, Sendable {
    public let latencyProfile: SessionLatencyProfile
    public let rxBufferProfile: RxBufferProfile
    public init(latencyProfile: SessionLatencyProfile, rxBufferProfile: RxBufferProfile) {
        self.latencyProfile = latencyProfile; self.rxBufferProfile = rxBufferProfile
    }
}

/// Groups the audio and video streams proposed or configured for a session.
public struct SessionStreamSet: Equatable, Sendable {
    public let audioStreams: [AudioStreamDescription]
    public let videoStreams: [VideoStreamDescription]
    public init(audioStreams: [AudioStreamDescription], videoStreams: [VideoStreamDescription]) {
        self.audioStreams = audioStreams; self.videoStreams = videoStreams
    }
}

/// Groups the control, audio, video, and metrics endpoints for one session peer.
public struct SessionMediaEndpoints: Equatable, Sendable {
    public let control: SessionNetworkEndpoint
    public let audio: SessionNetworkEndpoint
    public let video: SessionNetworkEndpoint
    public let metrics: SessionNetworkEndpoint
    public init(control: SessionNetworkEndpoint, audio: SessionNetworkEndpoint,
                video: SessionNetworkEndpoint, metrics: SessionNetworkEndpoint) {
        self.control = control; self.audio = audio; self.video = video; self.metrics = metrics
    }
}

/// Defines MTU and reconnect timing requested by a session proposal.
public struct SessionProposalTransport: Equatable, Sendable {
    public let mtuBytes: Int
    public let reconnectDeadlineMilliseconds: Int?
    public init(mtuBytes: Int, reconnectDeadlineMilliseconds: Int? = nil) {
        self.mtuBytes = mtuBytes; self.reconnectDeadlineMilliseconds = reconnectDeadlineMilliseconds
    }
}

/// Defines endpoint topology, MTU, metrics, and reconnect timing for a session configuration.
public struct SessionConfigurationTransport: Equatable, Sendable {
    public let peerMediaEndpoints: [SessionPeerMediaEndpoints]?
    public let mtuBytes: Int
    public let metricIntervalMilliseconds: Int
    public let reconnectDeadlineMilliseconds: Int
    public init(peerMediaEndpoints: [SessionPeerMediaEndpoints]? = nil, mtuBytes: Int,
                metricIntervalMilliseconds: Int, reconnectDeadlineMilliseconds: Int) {
        self.peerMediaEndpoints = peerMediaEndpoints; self.mtuBytes = mtuBytes
        self.metricIntervalMilliseconds = metricIntervalMilliseconds
        self.reconnectDeadlineMilliseconds = reconnectDeadlineMilliseconds
    }
}

/// Describes the proposer-selected streams, endpoints, MTU, and latency policy to negotiate.
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

    public struct Identity: Equatable, Sendable {
        public let sessionID: String
        public let proposer: PeerIdentity
        public let responder: PeerIdentity
        public init(sessionID: String, proposer: PeerIdentity, responder: PeerIdentity) {
            self.sessionID = sessionID; self.proposer = proposer; self.responder = responder
        }
    }

    public init(identity: Identity, profile: SessionMediaProfile,
                streams: SessionStreamSet, endpoints: SessionMediaEndpoints,
                transport: SessionProposalTransport) {
        sessionID = identity.sessionID; proposer = identity.proposer; responder = identity.responder
        latencyProfile = profile.latencyProfile; rxBufferProfile = profile.rxBufferProfile
        audioStreams = streams.audioStreams; videoStreams = streams.videoStreams
        controlEndpoint = endpoints.control; audioEndpoint = endpoints.audio
        videoEndpoint = endpoints.video; metricsEndpoint = endpoints.metrics
        mtuBytes = transport.mtuBytes; reconnectDeadlineMilliseconds = transport.reconnectDeadlineMilliseconds
    }
}

/// Records the negotiated peers, streams, endpoints, timing policy, and reconnect bounds.
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

    public struct Identity: Equatable, Sendable {
        public let sessionID: String
        public let peers: [PeerIdentity]
        public init(sessionID: String, peers: [PeerIdentity]) { self.sessionID = sessionID; self.peers = peers }
    }

    public init(identity: Identity, profile: SessionMediaProfile,
                streams: SessionStreamSet, endpoints: SessionMediaEndpoints,
                transport: SessionConfigurationTransport) {
        sessionID = identity.sessionID; peers = identity.peers
        latencyProfile = profile.latencyProfile; rxBufferProfile = profile.rxBufferProfile
        audioStreams = streams.audioStreams; videoStreams = streams.videoStreams
        controlEndpoint = endpoints.control; audioEndpoint = endpoints.audio
        videoEndpoint = endpoints.video; metricsEndpoint = endpoints.metrics
        peerMediaEndpoints = transport.peerMediaEndpoints; mtuBytes = transport.mtuBytes
        metricIntervalMilliseconds = transport.metricIntervalMilliseconds
        reconnectDeadlineMilliseconds = transport.reconnectDeadlineMilliseconds
    }

    public func validatePeerMediaTopology(minimumPeerCount: Int = 2) throws {
        try validateMinimumPeerCount(minimumPeerCount)
        let configuredPeerIDs = try configuredPeerIDSet()
        let endpoints = try requiredPeerMediaEndpoints()
        let endpointPeerIDs = try validatePeerMediaEndpoints(
            endpoints,
            configuredPeerIDs: configuredPeerIDs
        )
        try validatePeerMediaEndpointCoverage(
            configuredPeerIDs: configuredPeerIDs,
            endpointPeerIDs: endpointPeerIDs
        )
    }

    private func validateMinimumPeerCount(_ minimumPeerCount: Int) throws {
        try SessionValidation.requirePositive(minimumPeerCount, "minimumPeerCount")
        if peers.count < minimumPeerCount {
            throw SessionValidationError.peerCountBelowMinimum(
                requested: peers.count,
                minimum: minimumPeerCount
            )
        }
    }

    private func configuredPeerIDSet() throws -> Set<String> {
        var configuredPeerIDs = Set<String>()
        for peer in peers {
            try peer.validate(fieldPrefix: "configuration.peers")
            if !configuredPeerIDs.insert(peer.peerID).inserted {
                throw SessionValidationError.duplicatePeerID(peer.peerID)
            }
        }
        return configuredPeerIDs
    }

    private func requiredPeerMediaEndpoints() throws -> [SessionPeerMediaEndpoints] {
        guard let peerMediaEndpoints else {
            throw SessionValidationError.emptyField("configuration.peerMediaEndpoints")
        }
        return peerMediaEndpoints
    }

    private func validatePeerMediaEndpoints(
        _ peerMediaEndpoints: [SessionPeerMediaEndpoints],
        configuredPeerIDs: Set<String>
    ) throws -> Set<String> {
        var endpointPeerIDs = Set<String>()
        var endpointSets = PeerMediaEndpointSets()

        for endpoint in peerMediaEndpoints {
            try endpoint.validate(fieldPrefix: "configuration.peerMediaEndpoints")
            guard configuredPeerIDs.contains(endpoint.peerID) else {
                throw SessionValidationError.unexpectedPeerMediaEndpoint(peerID: endpoint.peerID)
            }
            if !endpointPeerIDs.insert(endpoint.peerID).inserted {
                throw SessionValidationError.duplicatePeerID(endpoint.peerID)
            }
            try endpointSets.insert(endpoint)
        }

        return endpointPeerIDs
    }

    private func validatePeerMediaEndpointCoverage(
        configuredPeerIDs: Set<String>,
        endpointPeerIDs: Set<String>
    ) throws {
        for peerID in configuredPeerIDs where !endpointPeerIDs.contains(peerID) {
            throw SessionValidationError.missingPeerMediaEndpoint(peerID: peerID)
        }
    }
}

private struct PeerMediaEndpointSets {
    private var controlEndpoints = Set<EndpointIdentity>()
    private var audioEndpoints = Set<EndpointIdentity>()
    private var videoEndpoints = Set<EndpointIdentity>()
    private var metricsEndpoints = Set<EndpointIdentity>()
    private var allMediaEndpoints = Set<EndpointIdentity>()

    mutating func insert(_ endpoint: SessionPeerMediaEndpoints) throws {
        try insertUnique(endpoint.controlEndpoint, channel: "control", into: &controlEndpoints)
        try insertUnique(endpoint.controlEndpoint, channel: "control", into: &allMediaEndpoints)
        try insertUnique(endpoint.audioEndpoint, channel: "audio", into: &audioEndpoints)
        try insertUnique(endpoint.audioEndpoint, channel: "audio", into: &allMediaEndpoints)
        try insertUnique(endpoint.videoEndpoint, channel: "video", into: &videoEndpoints)
        try insertUnique(endpoint.videoEndpoint, channel: "video", into: &allMediaEndpoints)
        try insertUnique(endpoint.metricsEndpoint, channel: "metrics", into: &metricsEndpoints)
        try insertUnique(endpoint.metricsEndpoint, channel: "metrics", into: &allMediaEndpoints)
    }

    private func insertUnique(
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
