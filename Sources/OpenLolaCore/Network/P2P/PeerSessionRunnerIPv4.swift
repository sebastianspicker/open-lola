// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

extension PeerSessionRunner {
    static func makeIPv4Capabilities(
        _ request: PeerSessionIPv4BindingRequest
    ) -> CapabilitySet {
        var capabilities = OpenLolaCLI.localCapabilitySet()
        capabilities.peer = PeerIdentity(
            peerID: request.peerID,
            displayName: "Peer \(request.peerID)",
            implementationName: "open-lola",
            implementationVersion: OpenLolaCLI.implementationVersion
        )
        capabilities.audio.channelSet = .defaultInput(count: request.audioChannelCount)
        return capabilities
    }

    static func makeIPv4Endpoints(
        _ request: PeerSessionIPv4BindingRequest,
        transports: PeerSessionIPv4Transports
    ) throws -> SessionPeerMediaEndpoints {
        SessionPeerMediaEndpoints(
            peerID: request.peerID,
            controlEndpoint: request.controlEndpoint,
            audioEndpoint: try transports.requireAudio().localEndpoint,
            videoEndpoint: try transports.requireVideo().localEndpoint,
            metricsEndpoint: try transports.requireMetrics().localEndpoint
        )
    }
}

struct PeerSessionIPv4Transports {
    var audioTransport: UdpMediaTransport?
    var videoTransport: UdpMediaTransport?
    var metricsTransport: UdpMediaTransport?

    mutating func bind(_ request: PeerSessionIPv4BindingRequest) throws {
        var audioTransport: UdpMediaTransport?
        var videoTransport: UdpMediaTransport?
        var metricsTransport: UdpMediaTransport?
        defer {
            if self.audioTransport == nil {
                audioTransport?.close()
                videoTransport?.close()
                metricsTransport?.close()
            }
        }
        audioTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.audioPort,
            dscp: request.dscp,
            bufferProfile: .minimumLatencyAudio
        )
        videoTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.videoPort,
            dscp: request.dscp,
            bufferProfile: .realtimeVideo
        )
        metricsTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.metricsPort,
            dscp: request.dscp,
            bufferProfile: .realtimeAudio
        )
        self.audioTransport = audioTransport
        self.videoTransport = videoTransport
        self.metricsTransport = metricsTransport
    }

    func close() {
        audioTransport?.close()
        videoTransport?.close()
        metricsTransport?.close()
    }

    func requireAudio() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(audioTransport, "audio")
    }

    func requireVideo() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(videoTransport, "video")
    }

    func requireMetrics() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(metricsTransport, "metrics")
    }
}
