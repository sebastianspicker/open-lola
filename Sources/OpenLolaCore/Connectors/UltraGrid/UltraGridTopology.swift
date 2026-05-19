import Foundation

public enum UltraGridTopologyMode: String, Codable, Equatable, Sendable {
    case directPeer = "direct-peer"
    case serverClient = "server-client"
}

public enum UltraGridTopologyRole: String, Codable, Equatable, Sendable {
    case direct
    case server
    case client
}
