import Foundation

public struct JackTripRunConfiguration: Codable, Equatable, Sendable {
    public var queueDepth: Int
    public var redundancy: Int
    public var bitResolutionBits: Int
    public var audioBackend: JackTripAudioBackend
    public var topologyMode: JackTripTopologyMode
    public var topologyRole: JackTripTopologyRole
    public var hubPatchMode: JackTripHubPatchMode
    public var hubTCPHandshakeMode: JackTripHubTCPHandshakeMode
    public var remoteClientName: String?
    public var packetHeaderMode: JackTripPacketHeaderMode
    public var transportMode: JackTripTransportMode
    public var pluginMode: JackTripPluginMode
    public var payloadEncoding: JackTripPayloadEncoding

    public init(
        queueDepth: Int = 4,
        redundancy: Int = 1,
        bitResolutionBits: Int = 16,
        audioBackend: JackTripAudioBackend = .coreAudio,
        topologyMode: JackTripTopologyMode = .directPeer,
        topologyRole: JackTripTopologyRole = .direct,
        hubPatchMode: JackTripHubPatchMode = .serverToClients,
        hubTCPHandshakeMode: JackTripHubTCPHandshakeMode = .none,
        remoteClientName: String? = nil,
        packetHeaderMode: JackTripPacketHeaderMode = .default,
        transportMode: JackTripTransportMode = .udp,
        pluginMode: JackTripPluginMode = .disabled,
        payloadEncoding: JackTripPayloadEncoding = .pcm
    ) {
        self.queueDepth = queueDepth
        self.redundancy = redundancy
        self.bitResolutionBits = bitResolutionBits
        self.audioBackend = audioBackend
        self.topologyMode = topologyMode
        self.topologyRole = topologyRole
        self.hubPatchMode = hubPatchMode
        self.hubTCPHandshakeMode = hubTCPHandshakeMode
        self.remoteClientName = remoteClientName
        self.packetHeaderMode = packetHeaderMode
        self.transportMode = transportMode
        self.pluginMode = pluginMode
        self.payloadEncoding = payloadEncoding
    }
}
