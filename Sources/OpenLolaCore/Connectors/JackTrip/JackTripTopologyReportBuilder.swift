// Derives JackTrip topology readiness and peer requirements from the configured hub or direct role.
extension JackTripCompatibilityRunner {
    static func topologyReport(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> JackTripTopologyReport {
        let peerRequired = jackTripPeerRequired(configuration)
        guard !peerRequired || !configuration.peer.isEmpty else {
            if configuration.jackTrip.topologyMode == .directPeer {
                throw ExternalConnectorSessionError.connectorRequiresPeerForTx(.jackTrip)
            }
            throw ExternalConnectorSessionError.missingRequiredArgument("--peer")
        }
        let state: JackTripTopologyState
        let notes: String
        switch (configuration.jackTrip.topologyMode, configuration.jackTrip.topologyRole) {
        case (.directPeer, .direct):
            state = .directPeerReady
            notes = "Direct JackTrip peer topology; bounded runtime evidence remains PARTIAL " +
                "until measured peer route evidence exists."
        case (.hubVirtualStudio, .hubServer):
            state = .hubServerListening
            notes = "JackTrip hub virtual-studio topology; server listens for hub clients " +
                "and does not claim TCP/auth or managed cloud studio evidence."
        case (.hubVirtualStudio, .hubClient):
            state = .hubClientReady
            notes = "JackTrip hub virtual-studio topology; client requires a configured hub peer " +
                "and remains PARTIAL without measured hub route evidence."
        default:
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-topology-\(configuration.jackTrip.topologyMode.rawValue)-" +
                    "\(configuration.jackTrip.topologyRole.rawValue)"
            )
        }
        return JackTripTopologyReport(
            mode: configuration.jackTrip.topologyMode,
            role: configuration.jackTrip.topologyRole,
            state: state,
            peerRequired: peerRequired,
            peerConfigured: !configuration.peer.isEmpty,
            localHost: configuration.localHost,
            peer: configuration.peer,
            hubPatchMode: configuration.jackTrip.hubPatchMode,
            notes: notes
        )
    }

    static func jackTripPeerRequired(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
        if configuration.jackTrip.topologyMode == .hubVirtualStudio,
           configuration.jackTrip.topologyRole == .hubServer {
            return false
        }
        if configuration.jackTrip.topologyMode == .hubVirtualStudio,
           configuration.jackTrip.topologyRole == .hubClient {
            return true
        }
        return configuration.role.transmits || configuration.role == .txRx
    }

    static func receivePeer(_ configuration: ExternalConnectorSessionConfiguration) -> String {
        if configuration.jackTrip.topologyMode == .hubVirtualStudio,
           configuration.jackTrip.topologyRole == .hubServer {
            return "0.0.0.0"
        }
        return configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer
    }

    static func transmitPeer(_ configuration: ExternalConnectorSessionConfiguration) -> String {
        if configuration.peer.isEmpty,
           configuration.jackTrip.topologyMode == .hubVirtualStudio,
           configuration.jackTrip.topologyRole == .hubServer {
            return "0.0.0.0"
        }
        return configuration.peer
    }
}
