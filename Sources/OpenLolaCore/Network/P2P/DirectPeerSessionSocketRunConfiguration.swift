// Declares direct-peer session configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Darwin
import Foundation

let directPeerMaximumTimeoutSeconds = 86_400

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerSessionSocketRunnerError: Error, Equatable, Sendable {
    case timedOutWaitingForControlMessage(String)
    case unexpectedControlSource(expected: SessionNetworkEndpoint, actualHost: String, actualPort: UInt16)
    case invalidPacketCount(Int)
    case invalidTimeoutSeconds(Int)
    case invalidAudioChannelCount(Int)
    case invalidManualHost(String, String)
    case invalidManualHostParse(String, String, Int32)
    case invalidManualPort(String, UInt16)
    case duplicateManualPort(String, UInt16)
    case missingExpectedControlMessage(String)
    case missingRemoteCapabilities
}

/// Identifies the initiator or responder role of a manually configured peer.
public enum DirectPeerSessionManualRole: String, Codable, Equatable, Sendable {
    case initiator
    case responder
}

func directPeerValidatedPacketCount(_ packetCount: Int) throws -> Int {
    guard packetCount > 0 else {
        throw DirectPeerSessionSocketRunnerError.invalidPacketCount(packetCount)
    }
    return packetCount
}

/// Configures DirectPeerSessionManualRunConfiguration so callers supply explicit inputs before starting direct peer sessions.
public struct DirectPeerSessionManualRunConfiguration: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var role: DirectPeerSessionManualRole
        public var localPeerID: String
        public var remotePeerID: String

        public init(role: DirectPeerSessionManualRole, localPeerID: String, remotePeerID: String) {
            self.role = role
            self.localPeerID = localPeerID
            self.remotePeerID = remotePeerID
        }
    }

    public typealias Network = DirectPeerManualNetworkShape

    public struct Tuning: Equatable, Sendable {
        public var packetCount: Int
        public var audioChannelCount: Int
        public var timeoutSeconds: Int
        public var dscp: Int?

        public init(packetCount: Int = 3, audioChannelCount: Int = 2, timeoutSeconds: Int = 5, dscp: Int? = nil) {
            self.packetCount = packetCount
            self.audioChannelCount = audioChannelCount
            self.timeoutSeconds = timeoutSeconds
            self.dscp = dscp
        }
    }
    public var role: DirectPeerSessionManualRole
    public var localPeerID: String
    public var remotePeerID: String
    public var localHost: String
    public var remoteHost: String
    public var controlPort: UInt16
    public var remoteControlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var metricsPort: UInt16
    public var packetCount: Int
    public var audioChannelCount: Int
    public var timeoutSeconds: Int
    public var dscp: Int?

    public init(identity: Identity, network: Network, tuning: Tuning = .init()) {
        self.role = identity.role
        self.localPeerID = identity.localPeerID
        self.remotePeerID = identity.remotePeerID
        self.localHost = network.localHost
        self.remoteHost = network.remoteHost
        self.controlPort = network.ports.controlPort
        self.remoteControlPort = network.ports.remoteControlPort
        self.audioPort = network.ports.audioPort
        self.videoPort = network.ports.videoPort
        self.metricsPort = network.ports.metricsPort
        self.packetCount = tuning.packetCount
        self.audioChannelCount = tuning.audioChannelCount
        self.timeoutSeconds = tuning.timeoutSeconds
        self.dscp = tuning.dscp
    }

    public func validateManualNetworkShape() throws {
        try DirectPeerManualNetworkShape(
            localHost: localHost,
            remoteHost: remoteHost,
            ports: DirectPeerPortSet(
                controlPort: controlPort,
                remoteControlPort: remoteControlPort,
                audioPort: audioPort,
                videoPort: videoPort,
                metricsPort: metricsPort
            )
        ).validate()
    }
}

struct DirectPeerManualSocketRunContext {
    var packetCount: Int
    var control: DirectPeerSessionControlSocket
    var runner: PeerSessionRunner
    var remoteControl: SessionNetworkEndpoint
}
