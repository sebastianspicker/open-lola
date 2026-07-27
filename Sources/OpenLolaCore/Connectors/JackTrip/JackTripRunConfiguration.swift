// Validates caller-selected JackTrip queueing, redundancy, backend, topology, and transport settings.
import Foundation

/// Defines the validated fields for JackTrip run configuration.
public struct JackTripRunConfiguration: Codable, Equatable, Sendable {
    public var queueDepth: Int = 1
    public var redundancy: Int = 1
    public var bitResolutionBits: Int = 16
    public var audioBackend: JackTripAudioBackend = .coreAudio
    public var topologyMode: JackTripTopologyMode = .directPeer
    public var topologyRole: JackTripTopologyRole = .direct
    public var hubPatchMode: JackTripHubPatchMode = .serverToClients
    public var hubTCPHandshakeMode: JackTripHubTCPHandshakeMode = .none
    public var remoteClientName: String?
    public var packetHeaderMode: JackTripPacketHeaderMode = .default
    public var transportMode: JackTripTransportMode = .udp
    public var pluginMode: JackTripPluginMode = .disabled
    public var payloadEncoding: JackTripPayloadEncoding = .pcm

    public init() {}

    public init(_ configure: (inout JackTripRunConfiguration) throws -> Void) rethrows {
        try configure(&self)
    }
}
