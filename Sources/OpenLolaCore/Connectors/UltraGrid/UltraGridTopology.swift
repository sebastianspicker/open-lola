// Describes UltraGridTopology peer topology, giving planning and reporting one shared connection model.
import Foundation

/// Enumerates the supported operating modes for UltraGrid topology.
public enum UltraGridTopologyMode: String, Codable, Equatable, Sendable {
    case directPeer = "direct-peer"
    case serverClient = "server-client"
}

/// Defines the supported choices for UltraGrid topology role.
public enum UltraGridTopologyRole: String, Codable, Equatable, Sendable {
    case direct
    case server
    case client
}
