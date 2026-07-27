// Verifies that JackTrip runner sends each captured packet before capturing the next.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripRunnerSendsEachCapturedPacketBeforeCapturingTheNext() throws {
    let probe = JackTripStreamingOrderProbe()
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-streaming.json"
        ) { input in
            input.dryRun = true
            input.mediaPacketCount = 3
        }),
        transmitter: JackTripStreamingOrderTransmitter(probe: probe),
        receiver: JackTripMemoryMediaReceiver(datagrams: []),
        audioProvider: JackTripStreamingOrderProvider(probe: probe)
    )

    #expect(report.transmittedDatagramCount == 3)
    #expect(probe.emittedDatagramCount == 3)
    #expect(!probe.capturedAheadOfTransmit)
}

@Test
func jackTripTxRxPreparesReceiveSocketBeforeTheFirstTransmit() throws {
    let probe = JackTripStreamingOrderProbe()
    probe.requiresReceiverBound = true
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .txRx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-bound-before-send.json"
        ) { input in
            input.dryRun = true
            input.mediaPacketCount = 2
        }),
        transmitter: JackTripStreamingOrderTransmitter(probe: probe),
        receiver: JackTripBoundOrderReceiver(probe: probe),
        audioProvider: JackTripStreamingOrderProvider(probe: probe)
    )

    #expect(report.transmittedDatagramCount == 2)
    #expect(probe.receiverBound)
    #expect(!probe.transmitStartedBeforeReceiverBound)
}

@Test
func jackTripDuplexReceiveContractDoesNotDependOnSuccessfulTransmitCount() throws {
    let inbound = JackTripCompatibilityDatagram(
        sourceHost: "203.0.113.10",
        destinationPort: JackTripCompatibility.defaultAudioPort,
        packet: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01)
    )
    let receiver = JackTripIndependentDuplexReceiver(inbound: [inbound])
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .txRx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-independent-duplex.json"
        ) { input in
            input.dryRun = false
            input.mediaPacketCount = 1
        }),
        transmitter: JackTripZeroSuccessTransmitter(),
        receiver: receiver
    )

    #expect(receiver.expectedReceiveCount == 1)
    #expect(report.receivedDatagramCount == 1)
    #expect(report.transmittedDatagramCount == 0)
    #expect(!report.realLinkTransmitted)
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "no JackTrip UDP audio datagrams were successfully transmitted")
}

@Test
func jackTripReportKeepsTotalReceiveCountWhenEvidenceIsCapped() throws {
    let retained = Array(repeating: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01), count: 1)
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(
            datagrams: [JackTripCompatibilityDatagram(
                sourceHost: "203.0.113.10",
                destinationPort: JackTripCompatibility.defaultAudioPort,
                packets: retained
            )],
            receivedDatagramCount: JackTripMediaReceiveRequest.maximumRetainedReceiveEvidenceDatagrams + 1
        )
    )
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-capped-evidence.json"
        ) { input in
            input.mediaPacketCount = 1
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    #expect(report.receivedDatagramCount == JackTripMediaReceiveRequest.maximumRetainedReceiveEvidenceDatagrams + 1)
    #expect(report.datagrams.count == 1)
}

@Test
func jackTripRxDoesNotCaptureOrBuildSyntheticDatagrams() throws {
    let provider = JackTripCallCountingAudioProvider()
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-rx-no-provider.json"
        ) { input in
            input.mediaPacketCount = 3
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: JackTripStaticReceiveResultReceiver(result: JackTripCompatibilityReceiveResult(datagrams: [])),
        audioProvider: provider
    )

    #expect(provider.callCount == 0)
    #expect(report.receivedDatagramCount == 0)
    #expect(report.runtimeError == "received 0 of 3 expected JackTrip UDP audio datagrams")
}

@Test
func jackTripTransmitEvidenceIsBoundedWithoutChangingTransmissionCount() throws {
    let packetCount = JackTripMediaReceiveRequest.maximumRetainedGeneratedEvidenceDatagrams + 1
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-capped-tx-evidence.json"
        ) { input in
            input.mediaPacketCount = packetCount
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: JackTripMemoryMediaReceiver(datagrams: [])
    )

    #expect(report.transmittedDatagramCount == packetCount)
    #expect(report.datagrams.count == JackTripMediaReceiveRequest.maximumRetainedGeneratedEvidenceDatagrams)
}

@Test
func jackTripOpusEncoderIsCreatedOnceForOneDatagramGeneration() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-opus-encoder-reuse.json"
    ) { input in
        input.channels = 1
        input.sampleRateHertz = OpusCELTLowDelayConstants.sampleRateHertz
        input.framesPerPacket = OpusCELTLowDelayConstants.frameCount
        input.mediaPacketCount = 3
        input.jackTrip.payloadEncoding = .opusCELTLowDelay
    })
    var encoderCreationCount = 0
    var emittedCount = 0

    try JackTripCompatibilityRunner.forEachDatagram(
        configuration: configuration,
        audioProvider: JackTripSyntheticAudioFrameProvider(),
        opusEncoderFactory: { channels in
            encoderCreationCount += 1
            return try OpusCELTLowDelayEncoder(channelCount: channels)
        }
    ) { _ in
        emittedCount += 1
    }

    #expect(encoderCreationCount == 1)
    #expect(emittedCount == 3)
}

@Test
func jackTripSocketReceiverReturnsAtDeadlineWithoutJoiningLateTransmit() throws {
    let audioPort = try freeLoopbackUdpPort()
    let deadline = DispatchTime.now().uptimeNanoseconds + 1_000_000
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let receiver = JackTripSocketMediaReceiver()
    let began = DispatchTime.now().uptimeNanoseconds

    #expect(throws: ExternalConnectorSessionError.socketFailed(
        "JackTrip transmit did not complete before the exchange deadline"
    )) {
        try receiver.receiveWhileBound(
            JackTripMediaReceiveRequest(
                expectedDatagrams: 0,
                localHost: "127.0.0.1",
                peer: "127.0.0.1",
                audioPort: audioPort,
                headerMode: .default,
                emptyHeaderTemplate: nil,
                timeoutSeconds: 1,
                exchangeDeadlineNanoseconds: deadline
            )
        ) {
            started.signal()
            release.wait()
            finished.signal()
            return 0
        }
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - began
    #expect(elapsed < 500_000_000)
    #expect(started.wait(timeout: .now() + .seconds(1)) == .success)

    // Cleanup only: the timed-out transmit worker deliberately outlives the exchange deadline.
    release.signal()
    #expect(finished.wait(timeout: .now() + .seconds(1)) == .success)
}

@Test
func jackTripJackGraphBackendSelectionRunsDryModeWithoutUnsupportedMode() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-jack-graph.json"
) { input in
  input.dryRun = true
  input.jackTrip = JackTripRunConfiguration { $0.audioBackend = .jackGraph }
})

    let report = try JackTripCompatibilityRunner.run(configuration: configuration)
    try report.validate()
    #expect(report.provider.audioSource == "jack-graph-backend")
    #expect(report.unsupportedModes.isEmpty)
}

@Test
func jackTripNativeRunnerBuildsOpusExtensionPayloads() throws {
    let datagrams = try JackTripCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-opus-extension.json"
) { input in
  input.sampleRateHertz = OpusCELTLowDelayConstants.sampleRateHertz
  input.framesPerPacket = OpusCELTLowDelayConstants.frameCount
  input.mediaPacketCount = 1
  input.jackTrip = JackTripRunConfiguration { $0.payloadEncoding = .opusCELTLowDelay }
})
    )

    let encoded = try JackTripAdvancedModeCodec.decodeOpusExtensionPayload(datagrams[0].packet)
    #expect(!encoded.isEmpty)
    #expect(datagrams[0].packet.header.bitResolution == .bit32)
}

@Test
func jackTripOpusReceiveSinkUsesOpusDecoderRatherThanPCMConversion() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-opus-rx.json"
    ) { input in
        input.dryRun = true
        input.channels = 1
        input.sampleRateHertz = OpusCELTLowDelayConstants.sampleRateHertz
        input.framesPerPacket = OpusCELTLowDelayConstants.frameCount
        input.mediaPacketCount = 1
        input.jackTrip = JackTripRunConfiguration { $0.payloadEncoding = .opusCELTLowDelay }
    })
    let encoded = try JackTripCompatibilityRunner.buildDatagrams(configuration: configuration)
    let report = try JackTripCompatibilityRunner.run(
        configuration: configuration,
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: JackTripStaticReceiveResultReceiver(
            result: JackTripCompatibilityReceiveResult(datagrams: encoded)
        )
    )

    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(report.sink.audioPayloadByteCount == OpusCELTLowDelayConstants.frameCount * MemoryLayout<Float>.size)
    #expect(report.sink.notes.contains("Opus CELT extension"))
}

@Test(arguments: ["webrtc", "webtransport", "plugin", "jack-graph", "hub", "opus-rx"])
func jackTripNativeSocketRunnerRejectsUnwiredMode(_ mode: String) throws {
    var expected: String = ""
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: mode == "opus-rx" ? .rx : .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-native-mode.json"
    ) { input in
        input.dryRun = false
        switch mode {
        case "webrtc":
            input.jackTrip.transportMode = .webRTC
            expected = "jacktrip-native-transport-webrtc"
        case "webtransport":
            input.jackTrip.transportMode = .webTransport
            expected = "jacktrip-native-transport-webtransport"
        case "plugin":
            input.jackTrip.pluginMode = .audioBridge
            expected = "jacktrip-native-plugin-audio-bridge"
        case "jack-graph":
            input.jackTrip.audioBackend = .jackGraph
            expected = "jacktrip-native-audio-backend-jack-graph"
        case "hub":
            input.jackTrip.topologyMode = .hubVirtualStudio
            input.jackTrip.topologyRole = .hubClient
            expected = "jacktrip-native-hub-topology-unwired"
        case "opus-rx":
            input.channels = 1
            input.sampleRateHertz = OpusCELTLowDelayConstants.sampleRateHertz
            input.framesPerPacket = OpusCELTLowDelayConstants.frameCount
            input.jackTrip.payloadEncoding = .opusCELTLowDelay
            expected = "jacktrip-native-opus-rx-playout-unwired"
        default:
            Issue.record("unexpected test mode: \(mode)")
        }
    })

    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(expected)) {
        _ = try JackTripCompatibilityRunner.run(configuration: configuration)
    }
}

@Test
func jackTripNativeUdpPcmModeRemainsSupported() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-native-udp-pcm.json"
        ) { input in
            input.dryRun = false
            input.mediaPacketCount = 0
        })
    )

    #expect(report.transmittedDatagramCount == 0)
    #expect(report.runtimeError == nil)
}

@Test
func jackTripLiveProviderSelectionReportsLiveDeviceEvidenceBeforeHardwareStart() throws {
    let provider = try JackTripSessionAudioFrameProvider(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-live-provider.json"
) { input in
  input.audioCapture = "coreaudio:input-device-uid"
  input.audioPlayback = "coreaudio:output-device-uid"
})
    )

    assertLiveDeviceProviderEvidence(
        provider.providerReport, audioSource: "coreaudio-live", videoSource: "not-applicable"
    )
}

@Test
func jackTripMediaReportRequiresExplicitRuntimeEvidenceBoundary() throws {
    var report = jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-evidence-boundary"
        $0.capturedAt = "2026-05-18T00:00:00Z"
        $0.role = .tx
        $0.realLinkTransmitted = false
        $0.verdict = .partial
        $0.notes = "Synthetic boundary test."
    }

    try report.validate()
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)

    report.observedEvidenceClasses = []
    #expect(throws: ExternalConnectorSessionError.emptyList("jackTripMedia.observedEvidenceClasses")) {
        try report.validate()
    }

    report = jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-evidence-boundary"
        $0.capturedAt = "2026-05-18T00:00:00Z"
        $0.role = .tx
        $0.missingEvidenceClassesForPass = []
        $0.realLinkTransmitted = false
        $0.verdict = .partial
        $0.notes = "Synthetic boundary test."
    }
    #expect(throws: ExternalConnectorSessionError.emptyList("jackTripMedia.missingEvidenceClassesForPass")) {
        try report.validate()
    }

    report.missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.verdict = .pass
    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }

    report.realLinkTransmitted = true
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "jackTripMedia.missingEvidenceClassesForPass"
    )) {
        try report.validate()
    }

    report.missingEvidenceClassesForPass = []
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "jackTripMedia.observedEvidenceClasses"
    )) {
        try report.validate()
    }

    report.observedEvidenceClasses = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.runtimeError = "late audio failure"
    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("jackTripMedia.runtimeError")) {
        try report.validate()
    }
}

@Test
func jackTripDatagramBuilderUsesInjectedAudioProviderBytes() throws {
    let datagrams = try JackTripCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-provider.json"
) { input in
  input.channels = 2
  input.framesPerPacket = 2
  input.mediaPacketCount = 1
}),
        audioProvider: JackTripFixedAudioProvider(
            interleaved: Data([
                0x01, 0x00, 0x02, 0x00,
                0x03, 0x00, 0x04, 0x00
            ])
        )
    )

    #expect(datagrams.count == 1)
    #expect(datagrams[0].packet.planarAudioPayload == Data([
        0x01, 0x00, 0x03, 0x00,
        0x02, 0x00, 0x04, 0x00
    ]))
}

@Test
func jackTripNativeRunnerReportsStopControlDatagramsSeparately() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01)
        )
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(
            datagrams: receivedDatagrams,
            stopControlDatagramCount: 2
        )
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-native-rx.json"
) { input in
  input.mediaPacketCount = 3
}),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.receivedDatagramCount == 1)
    #expect(report.stopControlDatagramCount == 2)
    #expect(report.runtimeError == "received 1 of 3 expected JackTrip UDP audio datagrams")
}
