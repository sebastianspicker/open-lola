// Verifies that direct peer session preflight rejects unsafe manual inputs before bind.
import CoreAudio
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

// swiftlint:disable function_body_length
@Test
func directPeerSessionPreflightRejectsUnsafeManualInputsBeforeBind() throws {
    let manual = DirectPeerSessionManualRunConfiguration(identity: .init(role: .initiator, localPeerID: "peer-a", remotePeerID: "peer-b"), network: .init(localHost: "127.0.0.1", remoteHost: "127.0.0.1", ports: .init(controlPort: 0, remoteControlPort: 0, audioPort: 0, videoPort: 0, metricsPort: 0)), tuning: .init(packetCount: 1, audioChannelCount: 2, timeoutSeconds: 1, dscp: nil))
    var overflowingDurationFixture = DirectPeerSyntheticAVFixture(manual: manual)
    overflowingDurationFixture.durationSeconds = Int.max
    let overflowingDuration = overflowingDurationFixture.configuration()
    var overflowingGeometryFixture = DirectPeerSyntheticAVFixture(manual: manual)
    overflowingGeometryFixture.videoWidth = Int.max
    overflowingGeometryFixture.videoHeight = 2
    let overflowingGeometry = overflowingGeometryFixture.configuration()

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(Int.max)) {
        _ = try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(configuration: overflowingDuration)
    }
    #expect(throws: DirectPeerSessionAVRuntimeError.unsafeRawVideoPacketBudget(
        estimatedFragmentsPerFrame: Int.max,
        maxFragmentsPerFrame: 768
    )) {
        _ = try DirectPeerVideoPacketBudget.validate(overflowingGeometry)
    }
    #expect(try directPeerValidatedPacketCount(1) == 1)
    #expect(throws: DirectPeerSessionSocketRunnerError.invalidPacketCount(0)) {
        _ = try directPeerValidatedPacketCount(0)
    }

    var invalidHostFixture = DirectPeerManualTestFixture()
    invalidHostFixture.localHost = "0.0.0.0"
    var invalidHostManual = invalidHostFixture.configuration()

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHost("localHost", "0.0.0.0")) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: invalidHostManual)
    }

    invalidHostManual.localHost = "127.0.0.1"
    invalidHostManual.remoteHost = "0.0.0.0"

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHost("remoteHost", "0.0.0.0")) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: invalidHostManual)
    }

    let duplicatePortManual = DirectPeerSessionManualRunConfiguration(identity: .init(role: .initiator, localPeerID: "peer-a", remotePeerID: "peer-b"), network: .init(localHost: "127.0.0.1", remoteHost: "127.0.0.1", ports: .init(controlPort: 57_000, remoteControlPort: 57_010, audioPort: 57_000, videoPort: 57_002, metricsPort: 57_003)), tuning: .init(packetCount: 1, audioChannelCount: 2, timeoutSeconds: 1, dscp: nil))

    #expect(throws: DirectPeerSessionSocketRunnerError.duplicateManualPort("audioPort", 57_000)) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: duplicatePortManual)
    }
}
// swiftlint:enable function_body_length

// swiftlint:disable function_body_length
@Test
func peerSessionRunnerEnforcesStateMachineAndLifecycleBoundaries() throws {
    var runner = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    defer { runner.shutdown(reason: "state-machine test complete") }
    var negotiated = try PeerSessionRunnerLoopbackPair.make()
    try negotiated.negotiate()
    let acceptedConfiguration = try #require(negotiated.first.acceptedConfiguration)
    defer {
        negotiated.first.shutdown(reason: "state-machine fixture complete")
        negotiated.second.shutdown(reason: "state-machine fixture complete")
    }

    #expect(throws: SessionStateMachineError.invalidTransition(from: .idle, message: .capabilities)) {
        try runner.receiveControlMessages([.capabilities(OpenLolaCLI.localCapabilitySet())])
    }
    #expect(runner.state == .idle)
    #expect(runner.remoteCapabilities == nil)

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.sessionAccept)) {
        try runner.receiveControlMessages([.sessionAccept(acceptedConfiguration)])
    }
    #expect(runner.acceptedConfiguration == nil)

    let hello = SessionControlMessage.hello(
        peer: OpenLolaCLI.localCapabilitySet().peer,
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    )
    try runner.receiveControlMessages([hello, .capabilities(OpenLolaCLI.localCapabilitySet())])
    #expect(runner.remoteCapabilities != nil)
    #expect(runner.state == .handshaking)

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.mediaStart)) {
        try runner.receiveControlMessages([.mediaStart(SessionMediaCommand(
            sessionID: "wrong-session",
            hostTimeNanoseconds: 1
        ))])
    }
    #expect(runner.state == .handshaking)
    #expect(runner.acceptedConfiguration == nil)

    var lifecycleRunner = try PeerSessionRunner.localhost(
        peerID: "peer-a",
        remotePeerID: "peer-b"
    )
    defer { lifecycleRunner.shutdown(reason: "lifecycle preflight complete") }

    #expect(throws: PeerSessionRunnerError.mediaStartBeforeAcceptedConfiguration) {
        try lifecycleRunner.startMedia()
    }

    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    try pair.first.beginRecovery(reason: "synthetic socket failure")

    #expect(pair.first.state == .recovering)
    #expect(pair.first.metrics.mediaStopBoundaries == 1)
    #expect(pair.first.metrics.mediaStartBoundaries == 1)

    try pair.first.restartMedia()

    #expect(pair.first.state == .running)
    #expect(pair.first.metrics.recoveryEvents == 1)
    #expect(pair.first.metrics.mediaStartBoundaries == 2)

    pair.first.shutdown(reason: "operator stop")
    pair.first.shutdown(reason: "operator stop")

    #expect(pair.first.state == .closed)
    #expect(pair.first.acceptedConfiguration == nil)
    #expect(pair.first.remoteCapabilities == nil)
    #expect(pair.first.remoteAudioMetadata == nil)
    #expect(pair.first.controlTranscript.isEmpty)
    #expect(pair.first.metrics.shutdownRequests == 2)
    #expect(pair.first.metrics.mediaStopBoundaries == 1)
    #expect(pair.first.metrics.mediaStartBoundaries == 0)
    #expect(pair.first.metrics.controlMessagesSent == 0)
}
// swiftlint:enable function_body_length

@Test
func directPeerSessionManualAddressRolesExchangeControlAndMediaOverUdp() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try freeLocalUdpPorts(count: 8)
        let (initiator, responder) = directPeerManualAddressRoleConfigurations(ports: ports)

        let responderReady = AsyncReadinessGate()
        async let responderReport = DirectPeerSessionSocketRunner.runManualAddress(
            configuration: responder,
            onReady: { Task { await responderReady.signal() } }
        )
        #expect(await responderReady.wait(timeout: .seconds(5)))
        let initiatorReport = try DirectPeerSessionSocketRunner.runManualAddress(
            configuration: initiator
        )
        let acceptedResponderReport = try await responderReport

        for report in [initiatorReport, acceptedResponderReport] {
            try expectManualAddressRoleUdpReport(report)
        }
    }
}

private func directPeerManualAddressRoleConfigurations(
    ports: [UInt16]
) -> (DirectPeerSessionManualRunConfiguration, DirectPeerSessionManualRunConfiguration) {
    pairedDirectPeerManualConfigurations(ports: ports, packetCount: 2)
}

private func expectManualAddressRoleUdpReport(_ report: DirectPeerSessionReport) throws {
    try report.validate()
    #expect(report.configuration.peerMediaEndpoints?.count == 2)
    #expect(report.metrics.controlDatagramsSent == 5)
    #expect(report.metrics.controlDatagramsReceived == 5)
    #expect(report.metrics.audioMetadataMessagesSent == 1)
    #expect(report.metrics.audioMetadataMessagesReceived == 1)
    #expect(report.metrics.timingProbePacketsSent == 1)
    #expect(report.metrics.timingProbePacketsReceived == 1)
    #expect(report.metrics.timingProbeMaxAgeMicroseconds >= 0)
    #expect(report.metrics.packetsSent == 2)
    #expect(report.metrics.packetsReceived == 2)
    #expect(report.metrics.audioPacketsRouted == 2)
    #expect(report.metrics.audioPayloadsSentOnControlChannel == 0)
    #expect(report.verdict == .partial)
}

@Test
func boundIPv4ClosesPartialMediaTransportsWhenLaterBindFails() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try reservedLocalUdpPorts(count: 3)
        let occupiedVideoPort = ports[1]
        ports.close()
        let videoReservation = try UdpMediaTransport.bindIPv4(host: "127.0.0.1", port: occupiedVideoPort)
        defer { videoReservation.close() }

        #expect(throws: (any Error).self) {
            _ = try PeerSessionRunner.boundIPv4(PeerSessionIPv4BindingRequest(
                peerID: "peer-a",
                remotePeerID: "peer-b",
                localHost: "127.0.0.1",
                controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: ports[0]),
                audioPort: ports[0],
                videoPort: occupiedVideoPort,
                metricsPort: ports[2]
            ))
        }

        let reboundAudio = try UdpMediaTransport.bindIPv4(host: "127.0.0.1", port: ports[0])
        reboundAudio.close()
    }
}

@Test
func peerSessionRunnerStartMediaCleansUpOnPartialConnectFailure() throws {
    var local = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    var remote = try PeerSessionRunner.localhost(peerID: "peer-b", remotePeerID: "peer-a")
    defer {
        local.shutdown(reason: "partial connect test complete")
        remote.shutdown(reason: "partial connect fixture complete")
    }

    try local.receiveControlMessages(remote.beginHandshake())
    try remote.receiveControlMessages(local.beginHandshake())

    let proposalMessage = try remote.makeSessionProposal()
    let proposal = try #require(proposalMessage.proposal)
    var invalidVideoProposal = proposal
    invalidVideoProposal.videoEndpoint = .init(
        host: "not-an-ip-address",
        port: proposal.videoEndpoint.port
    )
    _ = try local.acceptProposal(
        .sessionPropose(invalidVideoProposal),
        proposerCapabilities: remote.localCapabilities
    )

    #expect(throws: UdpPcmRouteProbeError.invalidHost("not-an-ip-address")) {
        try local.startMedia()
    }
    #expect(local.audioTransport?.isClosed == true)
    #expect(local.metrics.mediaStartBoundaries == 0)
    #expect(local.state == .failed)
}
