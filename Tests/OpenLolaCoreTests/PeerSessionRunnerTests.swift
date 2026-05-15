import CoreAudio
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVRunRejectsOverflowingDuration() throws {
    let manual = DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        controlPort: 0,
        remoteControlPort: 0,
        audioPort: 0,
        videoPort: 0,
        metricsPort: 0,
        packetCount: 1,
        audioChannelCount: 2,
        timeoutSeconds: 1
    )
    let configuration = DirectPeerSessionAVRunConfiguration(
        manual: manual,
        durationSeconds: Int.max,
        inputDeviceUID: "synthetic-a",
        outputDeviceUID: "synthetic-a",
        videoDeviceID: "synthetic-test-device",
        videoWidth: 16,
        videoHeight: 16,
        rxBufferProfile: .adaptive,
        preview: .off,
        mediaSourceMode: .syntheticFixture
    )

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(Int.max)) {
        _ = try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(configuration: configuration)
    }
}

@Test
func directPeerVideoPacketBudgetRejectsOverflowingGeometryWithoutTrap() throws {
    let manual = DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        controlPort: 0,
        remoteControlPort: 0,
        audioPort: 0,
        videoPort: 0,
        metricsPort: 0,
        packetCount: 1,
        audioChannelCount: 2,
        timeoutSeconds: 1
    )
    let configuration = DirectPeerSessionAVRunConfiguration(
        manual: manual,
        durationSeconds: 1,
        inputDeviceUID: "synthetic-a",
        outputDeviceUID: "synthetic-a",
        videoDeviceID: "synthetic-test-device",
        videoWidth: Int.max,
        videoHeight: 2,
        rxBufferProfile: .adaptive,
        preview: .off,
        mediaSourceMode: .syntheticFixture
    )

    #expect(throws: DirectPeerSessionAVRuntimeError.unsafeRawVideoPacketBudget(
        estimatedFragmentsPerFrame: Int.max,
        maxFragmentsPerFrame: 768
    )) {
        _ = try DirectPeerVideoPacketBudget.validate(configuration)
    }
}

@Test
func directPeerPacketCountValidatorRejectsInvalidRangesBeforeLoopConstruction() throws {
    #expect(try directPeerValidatedPacketCount(1) == 1)
    #expect(throws: DirectPeerSessionSocketRunnerError.invalidPacketCount(0)) {
        _ = try directPeerValidatedPacketCount(0)
    }
}

@Test
func audioMetadataExchangeReceivesExpectedControlMessageType() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift"
    )

    #expect(source.contains("ofType: .audioMetadata"))
    #expect(source.contains("maxSkippedMessages: Int = 8"))
    #expect(source.contains("if message.type == expectedType"))
    #expect(!source.contains("receiveMessage(label: \"peer audio metadata\")])"))
}

@Test
func directPeerControlSocketReceivesOnlyExpectedSource() throws {
    let socketSource = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionControlSocket.swift"
    )
    let udpSource = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift"
    )

    #expect(socketSource.contains("expectedSource: SessionNetworkEndpoint"))
    #expect(socketSource.contains("receiveDatagramWithSourceIfAvailable"))
    #expect(socketSource.contains("controlSourceMatches"))
    #expect(socketSource.contains("continue"))
    #expect(udpSource.contains("recvfrom(socket, bytes.baseAddress, byteCount, 0, socketAddress, &addressLength)"))
}

@Test
func directPeerControlSocketFactoriesCloseOnPartialFailure() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionControlSocket.swift"
    )

    #expect(source.contains("var succeeded = false"))
    #expect(source.contains("defer {\n            if !succeeded {\n                closeUdpSocket(descriptor)\n            }\n        }"))
    #expect(source.contains("succeeded = true"))
}

@Test
func peerSessionRunnerAppliesControlStateMachineBeforeMutatingRuntimeState() throws {
    var runner = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    defer { try? runner.shutdown(reason: "state-machine test complete") }
    var negotiated = try PeerSessionRunnerLoopbackPair.make()
    try negotiated.negotiate()
    let acceptedConfiguration = try #require(negotiated.first.acceptedConfiguration)
    defer {
        try? negotiated.first.shutdown(reason: "state-machine fixture complete")
        try? negotiated.second.shutdown(reason: "state-machine fixture complete")
    }

    #expect(throws: SessionStateMachineError.invalidTransition(from: .idle, message: .capabilities)) {
        try runner.receiveControlMessages([.capabilities(OpenLolaCLI.localCapabilitySet())])
    }
    #expect(runner.state == .idle)
    #expect(runner.remoteCapabilities == nil)

    #expect(throws: SessionStateMachineError.invalidTransition(from: .idle, message: .sessionAccept)) {
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
}

@Test
func directPeerSessionManualRunRejectsWildcardAdvertisedHost() throws {
    var manual = DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "0.0.0.0",
        remoteHost: "127.0.0.1",
        controlPort: 57_000,
        remoteControlPort: 57_010,
        audioPort: 57_001,
        videoPort: 57_002,
        metricsPort: 57_003,
        packetCount: 1,
        audioChannelCount: 2,
        timeoutSeconds: 1
    )

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHost("localHost", "0.0.0.0")) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: manual)
    }

    manual.localHost = "127.0.0.1"
    manual.remoteHost = "0.0.0.0"

    #expect(throws: DirectPeerSessionSocketRunnerError.invalidManualHost("remoteHost", "0.0.0.0")) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: manual)
    }
}

@Test
func directPeerSessionManualRunRejectsDuplicateActivePortsBeforeBind() throws {
    let manual = DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        controlPort: 57_000,
        remoteControlPort: 57_010,
        audioPort: 57_000,
        videoPort: 57_002,
        metricsPort: 57_003,
        packetCount: 1,
        audioChannelCount: 2,
        timeoutSeconds: 1
    )

    #expect(throws: DirectPeerSessionSocketRunnerError.duplicateManualPort("audioPort", 57_000)) {
        _ = try DirectPeerSessionSocketRunner.runManualAddress(configuration: manual)
    }
}

@Test
func directPeerSessionReportRejectsMalformedPeerMediaTopology() throws {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    let endpoints = try #require(report.configuration.peerMediaEndpoints)
    report.configuration.peerMediaEndpoints = [
        endpoints[0],
        SessionPeerMediaEndpoints(
            peerID: endpoints[1].peerID,
            controlEndpoint: endpoints[0].controlEndpoint,
            audioEndpoint: endpoints[1].audioEndpoint,
            videoEndpoint: endpoints[1].videoEndpoint,
            metricsEndpoint: endpoints[1].metricsEndpoint
        ),
    ]

    #expect(throws: SessionValidationError.duplicatePeerMediaEndpoint(
        channel: "control",
        host: endpoints[0].controlEndpoint.host,
        port: endpoints[0].controlEndpoint.port
    )) {
        try report.validate()
    }
}

@Test
func directPeerMeshTopologySmokeBuildsThreePeerPartialReport() throws {
    let report = try DirectPeerMeshTopologySmoke.run(peerCount: 3)

    try report.validate()

    #expect(report.configuration.peers.count == 3)
    #expect(report.configuration.peerMediaEndpoints?.count == 3)
    #expect(report.metrics.expectedDirectedRouteCount == 6)
    #expect(report.metrics.configuredDirectedRouteCount == 6)
    #expect(report.metrics.audioStreamCount == 1)
    #expect(report.metrics.enabledVideoStreamCount == 1)
    #expect(report.verdict == .partial)
}

@Test
func directPeerMeshTopologyRejectsMissingDirectedRoute() throws {
    var report = try DirectPeerMeshTopologySmoke.run(peerCount: 3)
    report.routes.removeLast()
    report.metrics.configuredDirectedRouteCount = report.routes.count

    #expect(throws: DirectPeerMeshTopologyError.missingDirectedRoute(
        sender: "peer-c",
        receiver: "peer-b"
    )) {
        try report.validate()
    }
}

@Test
func directPeerMeshTopologyRejectsPassWithoutPhysicalEvidence() throws {
    var report = try DirectPeerMeshTopologySmoke.run(peerCount: 3)
    report.verdict = .pass

    #expect(throws: DirectPeerMeshTopologyError.passRequiresPhysicalMeshEvidence) {
        try report.validate()
    }
}

@Test
func directPeerMeshReportsUseSharedValidationHelpers() throws {
    let helper = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerMeshValidation.swift")
    let topology = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift")
    let runtime = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift")

    #expect(helper.contains("struct DirectPeerMeshDirectedPair: Hashable"))
    #expect(helper.contains("func requireDirectPeerMeshNonEmpty("))
    #expect(helper.contains("func requireDirectPeerMeshNonNegative("))
    #expect(helper.contains("func requireDirectPeerMeshMetric("))
    #expect(topology.contains("Set<DirectPeerMeshDirectedPair>"))
    #expect(runtime.contains("Set<DirectPeerMeshDirectedPair>"))
    #expect(topology.contains("requireDirectPeerMeshNonEmpty(value, field"))
    #expect(runtime.contains("requireDirectPeerMeshNonEmpty(value, field"))
}

@Test
func directPeerMeshRuntimeSmokeRoutesAudioAcrossEveryDirectedPair() throws {
    let report = try DirectPeerMeshRuntimeSmoke.run(peerCount: 3, packetCount: 2)

    try report.validate()

    #expect(report.topology.configuration.peers.count == 3)
    #expect(report.routeMetrics.count == 6)
    #expect(report.metrics.directedRouteCount == 6)
    #expect(report.metrics.audioDeadlinesSent == 12)
    #expect(report.metrics.audioDeadlinesReceived == 12)
    #expect(report.metrics.audioFragmentsSent >= report.metrics.audioDeadlinesSent)
    #expect(report.metrics.audioFragmentsReceived == report.metrics.audioFragmentsSent)
    #expect(report.metrics.incompleteAudioDeadlines == 0)
    #expect(report.metrics.audioPayloadsSentOnControlChannel == 0)
    #expect(report.verdict == .partial)
}

@Test
func directPeerMeshRuntimeRejectsMissingRouteMetric() throws {
    var report = try DirectPeerMeshRuntimeSmoke.run(peerCount: 3, packetCount: 1)
    report.routeMetrics.removeLast()

    #expect(throws: DirectPeerMeshRuntimeError.metricMismatch("routeMetrics.count")) {
        try report.validate()
    }
}

@Test
func directPeerMeshRuntimeRejectsPassWithoutPhysicalEvidence() throws {
    var report = try DirectPeerMeshRuntimeSmoke.run(peerCount: 3, packetCount: 1)
    report.verdict = .pass

    #expect(throws: DirectPeerMeshRuntimeError.passRequiresPhysicalMeshEvidence) {
        try report.validate()
    }
}

@Test
func peerSessionAudioModeCachesAcceptedMTUForFragmentPlanAndMode() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerAudioHelpers.swift")

    #expect(source.contains("let mtuBytes = acceptedConfiguration?.mtuBytes ?? 1_200"))
    #expect(source.contains("maxTransmissionUnitBytes: mtuBytes"))
    #expect(!source.contains("maxTransmissionUnitBytes: acceptedConfiguration?.mtuBytes ?? 1_200"))
}

@Test
func directPeerSessionManualAddressRolesExchangeControlAndMediaOverUdp() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try freeLocalUdpPorts(count: 8)
        let initiator = DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "peer-a",
            remotePeerID: "peer-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[0],
            remoteControlPort: ports[4],
            audioPort: ports[1],
            videoPort: ports[2],
            metricsPort: ports[3],
            packetCount: 2,
            audioChannelCount: 2,
            timeoutSeconds: 10
        )
        let responder = DirectPeerSessionManualRunConfiguration(
            role: .responder,
            localPeerID: "peer-b",
            remotePeerID: "peer-a",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[4],
            remoteControlPort: ports[0],
            audioPort: ports[5],
            videoPort: ports[6],
            metricsPort: ports[7],
            packetCount: 2,
            audioChannelCount: 2,
            timeoutSeconds: 10
        )

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
    }
}

@Test
func directPeerSessionManualAudioVideoModeRoutesAudioAndVideo() async throws {
    try await SocketHeavyTestGate.shared.run {
        let ports = try reservedLocalUdpPorts(count: 8)
        defer { ports.close() }
        let initiatorManual = DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "peer-a",
            remotePeerID: "peer-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[0],
            remoteControlPort: ports[4],
            audioPort: ports[1],
            videoPort: ports[2],
            metricsPort: ports[3],
            packetCount: 3,
            audioChannelCount: 2,
            timeoutSeconds: 30
        )
        let responderManual = DirectPeerSessionManualRunConfiguration(
            role: .responder,
            localPeerID: "peer-b",
            remotePeerID: "peer-a",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: ports[4],
            remoteControlPort: ports[0],
            audioPort: ports[5],
            videoPort: ports[6],
            metricsPort: ports[7],
            packetCount: 3,
            audioChannelCount: 2,
            timeoutSeconds: 30
        )
        let initiator = DirectPeerSessionAVRunConfiguration(
            manual: initiatorManual,
            durationSeconds: 1,
            inputDeviceUID: "synthetic-a",
            outputDeviceUID: "synthetic-a",
            videoDeviceID: "synthetic-test-device",
            videoWidth: 16, videoHeight: 16,
            rxBufferProfile: .adaptive,
            preview: .off,
            mediaSourceMode: .syntheticFixture
        )
        let responder = DirectPeerSessionAVRunConfiguration(
            manual: responderManual,
            durationSeconds: 1,
            inputDeviceUID: "synthetic-b",
            outputDeviceUID: "synthetic-b",
            videoDeviceID: "synthetic-test-device",
            videoWidth: 16, videoHeight: 16,
            rxBufferProfile: .adaptive,
            preview: .off,
            mediaSourceMode: .syntheticFixture
        )

        let responderReady = AsyncReadinessGate()
        ports.close()
        async let responderReport = DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
            configuration: responder,
            onReady: { Task { await responderReady.signal() } }
        )
        #expect(await responderReady.wait(timeout: .seconds(5)))
        let initiatorReport = try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
            configuration: initiator
        )
        let acceptedResponderReport = try await responderReport

        for (report, expectedUID) in [
            (initiatorReport, "synthetic-a"),
            (acceptedResponderReport, "synthetic-b"),
        ] {
            try report.validate()
            #expect(report.configuration.latencyProfile == .multiVideoPerformance)
            #expect(report.configuration.rxBufferProfile == .adaptive)
            #expect(report.avRuntime?.avProfile == .balanced)
            #expect(report.avRuntime?.latencyProfile == .multiVideoPerformance)
            #expect(report.avRuntime?.rxBufferProfile == .adaptive)
            #expect(report.avRuntime?.previewMode == .off)
            #expect(report.avRuntime?.selectedBufferFrameSize == 32)
            try expectAVRuntimeDeviceUIDs(
                in: report,
                inputDeviceUID: expectedUID,
                outputDeviceUID: expectedUID
            )
            try expectSyntheticAVRouteCounters(in: report)
            #expect(report.configuration.videoStreams.filter(\.isEnabled).count == 1)
            #expect(report.metrics.packetsSent > 0)
            #expect(report.metrics.packetsReceived > 0)
            #expect(report.metrics.audioPacketsRouted > 0)
            #expect(report.metrics.videoPacketsRouted > 0)
            #expect(report.verdict == .partial)
        }
    }
}

@Test
func mediaCannotStartBeforeAcceptedConfiguration() throws {
    var runner = try PeerSessionRunner.localhost(
        peerID: "peer-a",
        remotePeerID: "peer-b"
    )

    #expect(throws: PeerSessionRunnerError.mediaStartBeforeAcceptedConfiguration) {
        try runner.startMedia()
    }
}

@Test
func directPeerSessionReconnectStopsAndRestartsMediaAtExplicitBoundaries() throws {
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
}

@Test
func directPeerSessionShutdownIsIdempotentAndClosesMedia() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    try pair.first.shutdown(reason: "operator stop")
    try pair.first.shutdown(reason: "operator stop")

    #expect(pair.first.state == .closed)
    #expect(pair.first.metrics.shutdownRequests == 2)
    #expect(pair.first.metrics.mediaStopBoundaries == 1)
}

@Test
func loopbackPairNegotiationHasExplicitFailureCleanup() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerLoopbackPair.swift"
    )

    #expect(source.contains("catch {"))
    #expect(source.contains("first.shutdown(reason: \"loopback negotiation failed\")"))
    #expect(source.contains("second.shutdown(reason: \"loopback negotiation failed\")"))
    #expect(source.contains("throw error"))
}

@Test
func peerSessionRunnerTransportMetricsUsesWeightedJitter() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMetrics.swift"
    )

    #expect(source.contains("combinedJitterMicroseconds("))
    #expect(source.contains("audioJitterMicroseconds * Double(audioPacketsReceived)"))
    #expect(!source.contains("jitterMicroseconds = max("))
}

@Test
func loopbackNegotiationDoesNotContainBlockingAcceptCall() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift"
    )

    #expect(source.contains("public mutating func acceptProposal("))
    #expect(!source.contains("sleep("))
    #expect(!source.contains("receiveMessage(label: \"accept\")"))
}

@Test
func acceptProposalStoresRemoteCapabilitiesOnlyAfterNegotiation() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift"
    )
    let negotiation = try #require(source.range(of: "var configuration = try SessionNegotiation.negotiate"))
    let remoteStore = try #require(source.range(of: "remoteCapabilities = proposerCapabilities"))

    #expect(remoteStore.lowerBound > negotiation.lowerBound)
}

@Test
func avFoundationRawFrameSourceStartsSessionBeforePublishingCollector() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerAVFoundationRawFrameSource.swift"
    )

    let restoreGuard = try #require(source.range(of: "var restoreOnStartupFailure: AVFoundationDeviceRestorePoint?"))
    let startRunning = try #require(source.range(of: "session.startRunning()"))
    let publishCollector = try #require(source.range(of: "self.collector = collector"))
    let disarmRestore = try #require(source.range(of: "restoreOnStartupFailure = nil"))

    #expect(source.contains("restoreOnStartupFailure?.restore(logger: Self.logger)"))
    #expect(restoreGuard.lowerBound < startRunning.lowerBound)
    #expect(startRunning.lowerBound < publishCollector.lowerBound)
    #expect(publishCollector.lowerBound < disarmRestore.lowerBound)
    #expect(source.contains("guard session.isRunning else"))
}

@Test
func avFoundationRawFrameSourceLogsCleanupRestoreFailures() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerAVFoundationRawFrameSource.swift"
    )

    #expect(source.contains("private static let logger = Logger("))
    #expect(source.contains("restore(logger: Self.logger)"))
    #expect(source.contains("logger.warning(\"AVFoundation device restore failed during raw frame source cleanup:"))
    #expect(!source.contains("Best-effort cleanup: capture has already stopped"))
}

@Test
func avAudioTXLoopPrevalidatesOpusEncoderBeforePollingPayloads() throws {
    let source = try readPeerSessionRunnerRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift"
    )

    #expect(source.contains("let encodeOpus: ((UnsafeRawBufferPointer) throws -> Data)?"))
    #expect(source.contains("throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape(\"missing Opus encoder\")"))
    #expect(source.contains("var sent = 0\n    while true"))
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
            _ = try PeerSessionRunner.boundIPv4(
                peerID: "peer-a",
                remotePeerID: "peer-b",
                localHost: "127.0.0.1",
                controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: ports[0]),
                audioPort: ports[0],
                videoPort: occupiedVideoPort,
                metricsPort: ports[2]
            )
        }

        let reboundAudio = try UdpMediaTransport.bindIPv4(host: "127.0.0.1", port: ports[0])
        reboundAudio.close()
    }
}

private func readPeerSessionRunnerRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
