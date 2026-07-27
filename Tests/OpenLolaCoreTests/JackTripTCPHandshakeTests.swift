// Verifies that JackTrip TCP handshake codec round-trips unauthenticated port exchange.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripTCPHandshakeCodecRoundTripsUnauthenticatedPortExchange() throws {
    let request = try JackTripTCPHandshakeCodec.encodeClientRequest(
        clientUDPPort: 4464,
        remoteClientName: "cello-left"
    )
    let decodedRequest = try JackTripTCPHandshakeCodec.decodeClientRequest(request)
    let response = JackTripTCPHandshakeCodec.encodeServerResponse(serverUDPPort: 61002)
    let decodedResponse = try JackTripTCPHandshakeCodec.decodeServerResponse(response)

    #expect(request.count == JackTripTCPHandshakeCodec.clientRequestByteCount)
    #expect(request.prefix(4) == Data([0x70, 0x11, 0x00, 0x00]))
    #expect(decodedRequest.clientUDPPort == 4464)
    #expect(decodedRequest.remoteClientName == "cello-left")
    #expect(response == Data([0x4a, 0xee, 0x00, 0x00]))
    #expect(decodedResponse == 61002)
}

@Test
func jackTripTCPHandshakeCodecRejectsAuthCodesAndMalformedFrames() throws {
    #expect(throws: JackTripCompatibilityError.invalidField("serverUDPPort", 65_536)) {
        _ = try JackTripTCPHandshakeCodec.decodeServerResponse(Data([0x00, 0x00, 0x01, 0x00]))
    }
    #expect(throws: JackTripCompatibilityError.payloadLengthMismatch(expected: 68, actual: 5)) {
        _ = try JackTripTCPHandshakeCodec.decodeClientRequest(Data([1, 2, 3, 4, 5]))
    }
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument(
        "jackTrip.remoteClientName",
        String(repeating: "x", count: 64)
    )) {
        _ = try JackTripTCPHandshakeCodec.encodeClientRequest(
            clientUDPPort: 4464,
            remoteClientName: String(repeating: "x", count: 64)
        )
    }
}

@Test
func jackTripAuthenticatedTLSFramesAreModeledWithoutPersistingSecrets() throws {
    let authRequest = JackTripTCPHandshakeCodec.encodeAuthenticationRequest()
    let credentials = try JackTripTCPHandshakeCodec.encodeAuthenticatedClientInfo(
        clientUDPPort: 4464,
        remoteClientName: "cello-left",
        username: "user1",
        password: "secret"
    )
    let response = try JackTripTCPHandshakeCodec.decodeAuthResponse(authRequest)

    #expect(authRequest == Data([0x00, 0x00, 0x01, 0x00]))
    #expect(response == .ok)
    #expect(credentials.count == JackTripTCPHandshakeCodec.clientRequestByteCount + 8 + 5 + 1 + 6 + 1)
    #expect(!credentials.isEmpty)
}

@Test
func jackTripHubTCPHandshakeReportIsRecordedWithoutAuthPassClaim() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-hub-tcp.json"
) { input in
  input.dryRun = true
  input.mediaMode = .audio
  input.audioPort = 4464
  input.peerAudioPort = 61002
        input.jackTrip = JackTripRunConfiguration {
            $0.topologyMode = .hubVirtualStudio
            $0.topologyRole = .hubClient
            $0.hubTCPHandshakeMode = .unauthenticated
            $0.remoteClientName = "cello-left"
        }
})
    )

    try report.validate()
    #expect(report.tcpHandshake.mode == .unauthenticated)
    #expect(report.tcpHandshake.state == .clientRequestReady)
    #expect(report.tcpHandshake.clientUDPPort == 4464)
    #expect(report.tcpHandshake.serverUDPPort == 61002)
    #expect(report.tcpHandshake.remoteClientName == "cello-left")
    #expect(!report.unsupportedModes.contains("tcp-hub-authentication"))
    #expect(!report.unsupportedModes.contains("hub-authentication-tls"))
    #expect(report.verdict == .partial)
}

@Test
func jackTripAuthenticatedTLSHandshakeReportStaysRedactedAndPartial() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-hub-auth.json"
) { input in
  input.dryRun = true
  input.mediaMode = .audio
  input.audioPort = 4464
  input.peerAudioPort = 61002
        input.jackTrip = JackTripRunConfiguration {
            $0.topologyMode = .hubVirtualStudio
            $0.topologyRole = .hubClient
            $0.hubTCPHandshakeMode = .authenticatedTLS
            $0.remoteClientName = "cello-left"
        }
})
    )

    try report.validate()
    #expect(report.tcpHandshake.mode == .authenticatedTLS)
    #expect(report.tcpHandshake.state == .authenticationRequestReady)
    #expect(report.tcpHandshake.authResponse == .ok)
    #expect(report.tcpHandshake.credentialFrameByteCount == 0)
    #expect(!report.notes.contains("secret"))
    #expect(report.verdict == .partial)
}

@Test
func jackTripHubTCPHandshakePropagatesThroughSessionAndConnectionPlan() throws {
    let parsed = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-hub-tcp.json",
        "--peer-audio-port", "61002",
        "--jacktrip-topology", "hub-virtual-studio",
        "--jacktrip-topology-role", "hub-client",
        "--jacktrip-hub-tcp-handshake", "unauthenticated",
        "--jacktrip-remote-client-name", "cello-left"
    ])
    let launchPlan = try ExternalConnectorLaunchPlan.build(configuration: parsed)

    #expect(parsed.jackTrip.hubTCPHandshakeMode == .unauthenticated)
    #expect(commandValue(launchPlan.arguments, "--hub-tcp-handshake") == "unauthenticated")
    #expect(commandValue(launchPlan.arguments, "--remote-client-name") == "cello-left")

    let connectionPlan = try ExternalConnectorConnectionPlanRunner.run(configuration:
        try ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", "jacktrip",
            "--local-host", "203.0.113.10",
            "--remote-host", "203.0.113.20",
            "--output", "/tmp/jacktrip-hub-tcp-plan.json",
            "--media", "audio",
            "--audio-port", "4464",
            "--jacktrip-topology", "hub-virtual-studio",
            "--jacktrip-topology-role", "hub-server",
            "--jacktrip-hub-tcp-handshake", "unauthenticated",
            "--jacktrip-remote-client-name", "cello-left"
        ])
    )
    let client = try #require(connectionPlan.endpoints.first { $0.side == .remote && $0.role == .tx })

    try connectionPlan.validate()
    #expect(commandValue(client.command, "--jacktrip-hub-tcp-handshake") == "unauthenticated")
    #expect(commandValue(client.command, "--jacktrip-remote-client-name") == "cello-left")
}
