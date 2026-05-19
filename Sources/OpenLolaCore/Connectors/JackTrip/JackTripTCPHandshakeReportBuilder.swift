import Foundation

extension JackTripCompatibilityRunner {
    static func tcpHandshakeReport(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> JackTripTCPHandshakeReport {
        guard configuration.jackTrip.hubTCPHandshakeMode != .none else {
            return JackTripTCPHandshakeReport(
                mode: .none,
                state: .notApplicable,
                clientUDPPort: 0,
                serverUDPPort: 0,
                remoteClientName: nil,
                clientRequestByteCount: 0,
                serverResponseByteCount: 0,
                credentialFrameByteCount: 0,
                notes: "TCP hub handshake is disabled for this JackTrip session."
            )
        }
        guard configuration.jackTrip.topologyMode == .hubVirtualStudio else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-hub-tcp-handshake-direct-peer")
        }
        let serverUDPPort = configuration.peerAudioPort ?? configuration.audioPort
        let clientRequest = try JackTripTCPHandshakeCodec.encodeClientRequest(
            clientUDPPort: configuration.audioPort,
            remoteClientName: configuration.jackTrip.remoteClientName
        )
        let serverResponse = JackTripTCPHandshakeCodec.encodeServerResponse(serverUDPPort: serverUDPPort)
        let state: JackTripTCPHandshakeState
        if configuration.jackTrip.hubTCPHandshakeMode == .authenticatedTLS {
            state = configuration.jackTrip.topologyRole == .hubClient
                ? .authenticationRequestReady
                : .serverResponseReady
        } else {
            state = configuration.jackTrip.topologyRole == .hubClient
                ? .clientRequestReady
                : .serverResponseReady
        }
        return JackTripTCPHandshakeReport(
            mode: configuration.jackTrip.hubTCPHandshakeMode,
            state: state,
            clientUDPPort: configuration.audioPort,
            serverUDPPort: serverUDPPort,
            remoteClientName: configuration.jackTrip.remoteClientName,
            authResponse: configuration.jackTrip.hubTCPHandshakeMode == .authenticatedTLS ? .ok : nil,
            clientRequestByteCount: clientRequest.count,
            serverResponseByteCount: serverResponse.count,
            credentialFrameByteCount: 0,
            notes: configuration.jackTrip.hubTCPHandshakeMode == .authenticatedTLS
                ? "JackTrip hub auth/TLS request and response code handling is modeled without storing credentials in reports. Measured TLS peer evidence remains required before any field claim."
                : "Unauthenticated JackTrip hub TCP handshake bytes are modeled: client sends UDP port and optional fixed name, server returns assigned UDP port. TLS/auth is recorded separately."
        )
    }
}
