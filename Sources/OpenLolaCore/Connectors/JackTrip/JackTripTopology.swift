// Describes JackTripTopology peer topology, giving planning and reporting one shared connection model.
import Foundation

/// Enumerates the supported operating modes for JackTrip topology.
public enum JackTripTopologyMode: String, Codable, Equatable, Sendable {
    case directPeer = "direct-peer"
    case hubVirtualStudio = "hub-virtual-studio"
}

/// Identifies direct-peer, hub-server, or hub-client behavior within a JackTrip topology.
public enum JackTripTopologyRole: String, Codable, Equatable, Sendable {
    case direct
    case hubServer = "hub-server"
    case hubClient = "hub-client"
}

/// Defines the supported choices for JackTrip topology state.
public enum JackTripTopologyState: String, Codable, Equatable, Sendable {
    case directPeerReady = "direct-peer-ready"
    case hubServerListening = "hub-server-listening"
    case hubClientReady = "hub-client-ready"
}

/// Enumerates the supported operating modes for JackTrip hub patch.
public enum JackTripHubPatchMode: Int, Codable, Equatable, Sendable {
    case serverToClients = 0
    case clientLoopback = 1
    case clientFanOutInNoLoopback = 2
    case reservedTUB = 3
    case fullMix = 4
    case noAuto = 5

    public var label: String {
        switch self {
        case .serverToClients:
            return "server-to-clients"
        case .clientLoopback:
            return "client-loopback"
        case .clientFanOutInNoLoopback:
            return "client-fan-out-in-no-loopback"
        case .reservedTUB:
            return "reserved-tub"
        case .fullMix:
            return "full-mix"
        case .noAuto:
            return "no-auto"
        }
    }
}

/// Records the evidence and outcome for JackTrip topology report.
public struct JackTripTopologyReport: Codable, Equatable, Sendable {
    public var mode: JackTripTopologyMode
    public var role: JackTripTopologyRole
    public var state: JackTripTopologyState
    public var peerRequired: Bool
    public var peerConfigured: Bool
    public var localHost: String
    public var peer: String
    public var hubPatchMode: JackTripHubPatchMode
    public var notes: String

    public func validate(fieldPrefix: String) throws {
        let requiresDirectRole = mode == .directPeer
        let rejectsDirectRole = mode == .hubVirtualStudio
        try validateExternalConnectorTopology(
            ExternalConnectorTopologyValidationInput(
                localHost: localHost,
                peer: peer,
                peerRequired: peerRequired,
                notes: notes,
                fieldPrefix: fieldPrefix,
                requiresDirectRole: requiresDirectRole,
                isDirectRole: role == .direct,
                invalidRoleError: "jacktrip-topology-role-\(role.rawValue)",
                rejectsDirectRole: rejectsDirectRole,
                directRoleError: "jacktrip-topology-role-direct"
            )
        )
    }
}

func parseJackTripTopologyMode(_ value: String) throws -> JackTripTopologyMode {
    switch value {
    case "direct-peer", "directPeer", "direct", "peer":
        return .directPeer
    case "hub-virtual-studio", "hub", "virtual-studio", "virtualStudio":
        return .hubVirtualStudio
    default:
        throw ExternalConnectorSessionError.unknownArgument("--jacktrip-topology \(value)")
    }
}

func parseJackTripTopologyRole(_ value: String) throws -> JackTripTopologyRole {
    switch value {
    case "direct":
        return .direct
    case "hub-server", "server", "listen", "listener":
        return .hubServer
    case "hub-client", "client", "caller":
        return .hubClient
    default:
        throw ExternalConnectorSessionError.unknownArgument("--jacktrip-topology-role \(value)")
    }
}

func parseJackTripHubPatchMode(_ value: String) throws -> JackTripHubPatchMode {
    if let raw = Int(value), let mode = JackTripHubPatchMode(rawValue: raw) {
        return mode
    }
    switch value {
    case "server-to-clients":
        return .serverToClients
    case "client-loopback":
        return .clientLoopback
    case "client-fan-out-in-no-loopback", "fanout-no-loopback":
        return .clientFanOutInNoLoopback
    case "reserved-tub":
        return .reservedTUB
    case "full-mix":
        return .fullMix
    case "no-auto", "none":
        return .noAuto
    default:
        throw ExternalConnectorSessionError.unknownArgument("--jacktrip-hub-patch \(value)")
    }
}
