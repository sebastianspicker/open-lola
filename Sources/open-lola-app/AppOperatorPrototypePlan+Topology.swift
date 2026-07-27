// Topology peer/host labels derived from the operator prototype plan.
import OpenLolaCore

extension AppOperatorPrototypePlan {
    var topologyLocalPeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.peerID ?? "local Mac"
        case .windowsLoLa:
            return "local Mac"
        case .jackTrip, .ultraGrid:
            return "local connector"
        }
    }

    var topologyRemotePeer: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.peerID ?? "remote Mac"
        case .windowsLoLa:
            return "Windows LoLa"
        case .jackTrip, .ultraGrid:
            return "\(sessionMode.displayName) peer"
        }
    }

    var topologyLocalHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macA?.host ?? windowsLoLaFields.localHost
        case .windowsLoLa:
            return windowsLoLaFields.localHost
        case .jackTrip, .ultraGrid:
            return externalConnectorFields.localHost
        }
    }

    var topologyRemoteHost: String {
        switch sessionMode {
        case .directMacPeer:
            return macB?.host ?? windowsLoLaFields.windowsHost
        case .windowsLoLa:
            return windowsLoLaFields.windowsHost
        case .jackTrip, .ultraGrid:
            return externalConnectorFields.peerHost
        }
    }
}
