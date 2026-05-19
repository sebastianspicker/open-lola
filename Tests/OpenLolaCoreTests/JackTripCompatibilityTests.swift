import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripDefaultPacketCodecMatchesPublicHeaderLayout() throws {
    let payload = Data([0x01, 0x00, 0x03, 0x00, 0x02, 0x00, 0x04, 0x00])
    let packet = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 0x0102_0304_0506_0708,
            sequenceNumber: 0x1122,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: payload
    )

    let encoded = try packet.encoded()

    #expect(encoded.prefix(16) == Data([
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
        0x22, 0x11,
        0x02, 0x00,
        0x03,
        0x02,
        0x02,
        0x00,
    ]))
    #expect(try JackTripAudioPacket.decode(encoded) == packet)
}

@Test
func jackTripDefaultDatagramCodecCarriesCompleteRedundantPackets() throws {
    let first = try jackTripTestPacket(sequenceNumber: 7, payloadByte: 0x01)
    let second = try jackTripTestPacket(sequenceNumber: 8, payloadByte: 0x02)

    let encoded = try JackTripAudioPayloadCodec.encodeDefaultDatagram([second, first])
    let decoded = try JackTripAudioPayloadCodec.decodeDefaultDatagram(encoded)

    #expect(decoded == [second, first])
    #expect(encoded.count == (JackTripDefaultHeader.byteCount + first.planarAudioPayload.count) * 2)
}

@Test
func jackTripDefaultPacketCodecResolvesChannelSentinels() throws {
    let matchingChannelsPacket = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 1,
            sequenceNumber: 1,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data(repeating: 0, count: 8)
    )
    #expect(matchingChannelsPacket.header.payloadChannelCount == 2)

    let noInputPacket = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 1,
            sequenceNumber: 2,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.noInputChannelsSentinel
        ),
        planarAudioPayload: Data()
    )
    #expect(noInputPacket.header.payloadChannelCount == 0)

    #expect(throws: JackTripCompatibilityError.payloadLengthMismatch(expected: 0, actual: 2)) {
        _ = try JackTripAudioPacket(
            header: noInputPacket.header,
            planarAudioPayload: Data([0, 0])
        )
    }
}

@Test
func jackTripCodecRejectsMalformedOrUnsupportedPackets() throws {
    #expect(throws: JackTripCompatibilityError.truncatedPacket(byteCount: 3)) {
        _ = try JackTripAudioPacket.decode(Data([1, 2, 3]))
    }

    var unsupportedSampleRate = Data(repeating: 0, count: JackTripDefaultHeader.byteCount)
    unsupportedSampleRate[0] = 1
    unsupportedSampleRate[10] = 1
    unsupportedSampleRate[12] = 99
    unsupportedSampleRate[13] = JackTripBitResolution.bit16.rawValue
    unsupportedSampleRate[14] = 1
    unsupportedSampleRate[15] = 1
    unsupportedSampleRate.append(contentsOf: [0, 0])
    #expect(throws: JackTripCompatibilityError.unsupportedMode("sample-rate-enum-99")) {
        _ = try JackTripAudioPacket.decode(unsupportedSampleRate)
    }

    let mismatchedPayload = Data([
        1, 0, 0, 0, 0, 0, 0, 0,
        0, 0,
        2, 0,
        JackTripSampleRate.hz48000.rawValue,
        JackTripBitResolution.bit16.rawValue,
        2,
        2,
        0, 0,
    ])
    #expect(throws: JackTripCompatibilityError.payloadLengthMismatch(expected: 8, actual: 2)) {
        _ = try JackTripAudioPacket.decode(mismatchedPayload)
    }

    var unsupportedBitDepthEnum = mismatchedPayload
    unsupportedBitDepthEnum[13] = 99
    #expect(throws: JackTripCompatibilityError.unsupportedMode("bit-resolution-enum-99")) {
        _ = try JackTripAudioPacket.decode(unsupportedBitDepthEnum)
    }
}

@Test
func jackTripReportsAdvancedModesAsImplementedPacketModels() {
    #expect(JackTripCompatibility.unsupportedModes.isEmpty)
    #expect(JackTripCompatibility.evidenceBoundary.contains("WebRTC data-channel"))
    #expect(JackTripCompatibility.evidenceBoundary.contains("WebTransport datagram"))
    #expect(JackTripCompatibility.evidenceBoundary.contains("Opus extension"))
}

@Test
func jackTripCodecConvertsInterleavedAndPlanarInt16Payloads() throws {
    let interleaved = Data([
        0x01, 0x00, 0x02, 0x00,
        0x03, 0x00, 0x04, 0x00,
        0x05, 0x00, 0x06, 0x00,
    ])

    let planar = try JackTripAudioPayloadCodec.planarInt16Payload(
        interleavedLittleEndianPCM: interleaved,
        channels: 2,
        frames: 3
    )

    #expect(planar == Data([
        0x01, 0x00, 0x03, 0x00, 0x05, 0x00,
        0x02, 0x00, 0x04, 0x00, 0x06, 0x00,
    ]))
    #expect(try JackTripAudioPayloadCodec.interleavedInt16Payload(
        planarLittleEndianPCM: planar,
        channels: 2,
        frames: 3
    ) == interleaved)
}

@Test
func jackTripCodecSupportsDefaultPacketsAt8Bit24BitAnd32Bit() throws {
    let interleavedInt16 = Data([
        0x00, 0x80, 0x00, 0x00,
        0xff, 0x7f, 0x00, 0x40,
    ])

    for bitResolution in [JackTripBitResolution.bit8, .bit24, .bit32] {
        let planar = try JackTripAudioPayloadCodec.planarConvertedPayload(
            interleavedLittleEndianInt16PCM: interleavedInt16,
            channels: 2,
            frames: 2,
            bitResolution: bitResolution
        )
        let packet = try JackTripAudioPacket(
            header: JackTripDefaultHeader(
                timestampMicroseconds: 1,
                sequenceNumber: UInt16(bitResolution.bits),
                bufferSizeSamples: 2,
                sampleRate: .hz48000,
                bitResolution: bitResolution,
                incomingChannelsFromNetwork: 2,
                outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
            ),
            planarAudioPayload: planar
        )
        let decoded = try JackTripAudioPacket.decode(try packet.encoded())
        let interleaved = try JackTripAudioPayloadCodec.interleavedPayload(
            planarLittleEndianPCM: decoded.planarAudioPayload,
            channels: 2,
            frames: 2,
            bitResolution: bitResolution
        )

        #expect(decoded.header.bitResolution == bitResolution)
        #expect(decoded.planarAudioPayload.count == 2 * 2 * bitResolution.bytesPerSample)
        #expect(interleaved.count == decoded.planarAudioPayload.count)
    }
}

@Test
func jackTripNativeRunnerBuildsBoundedPacketEvidence() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-native.json",
            peerAudioPort: 4464,
            mediaPacketCount: 3,
            jackTrip: JackTripRunConfiguration(redundancy: 3)
        )
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.transmittedDatagramCount == 3)
    #expect(report.provider.audioSource == "synthetic")
    #expect(report.provider.videoSource == "not-applicable")
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)
    #expect(report.datagrams.map { $0.packet.header.sequenceNumber } == [0, 1, 2])
    #expect(report.datagrams.map { $0.packets.map(\.header.sequenceNumber) } == [
        [0],
        [1, 0],
        [2, 1, 0],
    ])
    #expect(report.datagrams.allSatisfy {
        $0.packet.header.outgoingChannelsToNetwork == JackTripCompatibility.matchingOutgoingChannelSentinel
    })
    #expect(report.datagrams.allSatisfy { $0.destinationPort == 4464 })
}

@Test
func jackTripPublicRunnerSelectsFixtureProviderForPacketBytes() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-public-fixture.json",
            dryRun: true,
            channels: 2,
            framesPerPacket: 2,
            audioCapture: "fixture:0100020003000400",
            mediaPacketCount: 1
        )
    )

    try report.validate()
    #expect(report.provider.audioSource == "fixture")
    #expect(report.observedEvidenceClasses == [ExternalConnectorEvidenceClass.synthetic])
    #expect(report.datagrams[0].packet.planarAudioPayload == Data([
        0x01, 0x00, 0x03, 0x00,
        0x02, 0x00, 0x04, 0x00,
    ]))
}

@Test
func jackTripPublicRunnerBuildsConfiguredNon16BitDefaultPackets() throws {
    for bitResolution in [JackTripBitResolution.bit8, .bit24, .bit32] {
        let report = try JackTripCompatibilityRunner.run(
            configuration: ExternalConnectorSessionConfiguration(
                connector: .jackTrip,
                role: .tx,
                peer: "203.0.113.10",
                outputPath: "/tmp/jacktrip-bit-\(bitResolution.bits).json",
                dryRun: true,
                channels: 2,
                framesPerPacket: 2,
                audioCapture: "fixture:00800000ff7f0040",
                mediaPacketCount: 1,
                jackTrip: JackTripRunConfiguration(bitResolutionBits: bitResolution.bits)
            )
        )

        try report.validate()
        #expect(report.datagrams[0].packet.header.bitResolution == bitResolution)
        #expect(report.datagrams[0].packet.planarAudioPayload.count == 2 * 2 * bitResolution.bytesPerSample)
    }
}

@Test
func jackTripSessionParserAcceptsBitResolutionSelection() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-bit-depth.json",
        "--jacktrip-bit-resolution", "24",
    ])

    #expect(configuration.jackTrip.bitResolutionBits == 24)
}

@Test
func jackTripSessionParserAcceptsAudioBackendSelection() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-backend.json",
        "--jacktrip-audio-backend", "jack-graph",
    ])

    #expect(configuration.jackTrip.audioBackend == .jackGraph)
}

@Test
func jackTripSessionParserAcceptsAdvancedModeSelection() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-advanced.json",
        "--peer-audio-port", "4464",
        "--frames", String(OpusCELTLowDelayConstants.frameCount),
        "--jacktrip-transport", "webtransport",
        "--jacktrip-plugin", "audio-bridge",
        "--jacktrip-payload-encoding", "opus-celt-low-delay",
    ])

    #expect(configuration.jackTrip.transportMode == .webTransport)
    #expect(configuration.jackTrip.pluginMode == .audioBridge)
    #expect(configuration.jackTrip.payloadEncoding == .opusCELTLowDelay)

    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    #expect(plan.arguments.contains("--transport"))
    #expect(plan.arguments.contains("webtransport"))
    #expect(plan.arguments.contains("--plugin"))
    #expect(plan.arguments.contains("audio-bridge"))
    #expect(plan.arguments.contains("--payload-encoding"))
    #expect(plan.arguments.contains("opus-celt-low-delay"))
}

@Test
func jackTripAdvancedTransportCodecsPreserveAudioPackets() throws {
    let packet = try jackTripTestPacket(sequenceNumber: 9, payloadByte: 0x09)
    let webRTC = try JackTripAdvancedModeCodec.encodeTransportDatagram(
        [packet],
        headerMode: .default,
        transportMode: .webRTC
    )
    #expect(try JackTripAdvancedModeCodec.decodeTransportDatagram(
        webRTC,
        headerMode: .default,
        transportMode: .webRTC
    ) == [packet])

    let webTransport = try JackTripAdvancedModeCodec.encodeTransportDatagram(
        [packet],
        headerMode: .default,
        transportMode: .webTransport,
        webTransportQuarterStreamID: 65
    )
    #expect(webTransport.first == 0x40)
    #expect(try JackTripAdvancedModeCodec.decodeTransportDatagram(
        webTransport,
        headerMode: .default,
        transportMode: .webTransport
    ) == [packet])
}

@Test
func jackTripWebRTCSignalingFramesUseBigEndianLengthPrefix() throws {
    let message = JackTripWebRTCSignalingMessage(
        type: "protocol_detect",
        clientName: "open-lola"
    )
    let frame = try JackTripAdvancedModeCodec.encodeWebRTCSignalingFrame(message)
    let length = Int(frame[0]) << 24 | Int(frame[1]) << 16 | Int(frame[2]) << 8 | Int(frame[3])

    #expect(length == frame.count - 4)
    #expect(try JackTripAdvancedModeCodec.decodeWebRTCSignalingFrame(frame) == message)
}

@Test
func jackTripOpusExtensionEnvelopeRoundTripsEncodedPayload() throws {
    let encodedOpus = Data([0x11, 0x22, 0x33, 0x44])
    let packet = try JackTripAdvancedModeCodec.encodeOpusExtensionPacket(
        encodedOpusPayload: encodedOpus,
        sequenceNumber: 10,
        timestampMicroseconds: 1,
        channels: 2
    )

    #expect(packet.header.bitResolution == .bit32)
    #expect(try JackTripAdvancedModeCodec.decodeOpusExtensionPayload(packet) == encodedOpus)
}

@Test
func jackTripJackGraphBackendSelectionRunsDryModeWithoutUnsupportedMode() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-jack-graph.json",
        dryRun: true,
        jackTrip: JackTripRunConfiguration(audioBackend: .jackGraph)
    )

    let report = try JackTripCompatibilityRunner.run(configuration: configuration)
    try report.validate()
    #expect(report.provider.audioSource == "jack-graph-backend")
    #expect(report.unsupportedModes.isEmpty)
}

@Test
func jackTripNativeRunnerBuildsOpusExtensionPayloads() throws {
    let datagrams = try JackTripCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-opus-extension.json",
            sampleRateHertz: OpusCELTLowDelayConstants.sampleRateHertz,
            framesPerPacket: OpusCELTLowDelayConstants.frameCount,
            mediaPacketCount: 1,
            jackTrip: JackTripRunConfiguration(payloadEncoding: .opusCELTLowDelay)
        )
    )

    let encoded = try JackTripAdvancedModeCodec.decodeOpusExtensionPayload(datagrams[0].packet)
    #expect(!encoded.isEmpty)
    #expect(datagrams[0].packet.header.bitResolution == .bit32)
}

@Test
func jackTripLiveProviderSelectionReportsLiveDeviceEvidenceBeforeHardwareStart() throws {
    let provider = try JackTripSessionAudioFrameProvider(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-live-provider.json",
            audioCapture: "coreaudio:input-device-uid",
            audioPlayback: "coreaudio:output-device-uid"
        )
    )

    #expect(provider.providerReport.audioSource == "coreaudio-live")
    #expect(provider.providerReport.videoSource == "not-applicable")
    #expect(provider.providerReport.observedEvidenceClasses == [ExternalConnectorEvidenceClass.liveDevice])
    #expect(
        ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: provider.providerReport.observedEvidenceClasses
        ) == [.referencePeer, .fieldRoute, .packetCapture, .timing, .teardown, .mediaQuality]
    )
}

@Test
func jackTripMediaReportRequiresExplicitRuntimeEvidenceBoundary() throws {
    var report = JackTripCompatibilityMediaReport(
        id: "jacktrip-evidence-boundary",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .tx,
        datagrams: [],
        transmittedDatagramCount: 0,
        receivedDatagramCount: 0,
        realLinkTransmitted: false,
        verdict: .partial,
        notes: "Synthetic boundary test."
    )

    try report.validate()
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)

    report.observedEvidenceClasses = []
    #expect(throws: ExternalConnectorSessionError.emptyList("jackTripMedia.observedEvidenceClasses")) {
        try report.validate()
    }

    report = JackTripCompatibilityMediaReport(
        id: "jacktrip-evidence-boundary",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .tx,
        datagrams: [],
        transmittedDatagramCount: 0,
        receivedDatagramCount: 0,
        missingEvidenceClassesForPass: [],
        realLinkTransmitted: false,
        verdict: .partial,
        notes: "Synthetic boundary test."
    )
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
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-provider.json",
            channels: 2,
            framesPerPacket: 2,
            mediaPacketCount: 1
        ),
        audioProvider: JackTripFixedAudioProvider(
            interleaved: Data([
                0x01, 0x00, 0x02, 0x00,
                0x03, 0x00, 0x04, 0x00,
            ])
        )
    )

    #expect(datagrams.count == 1)
    #expect(datagrams[0].packet.planarAudioPayload == Data([
        0x01, 0x00, 0x03, 0x00,
        0x02, 0x00, 0x04, 0x00,
    ]))
}

@Test
func jackTripNativeRunnerReportsStopControlDatagramsSeparately() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01)
        ),
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(
            datagrams: receivedDatagrams,
            stopControlDatagramCount: 2
        )
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-native-rx.json",
            mediaPacketCount: 3
        ),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.receivedDatagramCount == 1)
    #expect(report.stopControlDatagramCount == 2)
    #expect(report.runtimeError == "received 1 of 3 expected JackTrip UDP audio datagrams")
}

@Test
func jackTripNativeRunnerReportsLearnedPeerAndRedundancyRecovery() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            sourcePort: 54_321,
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01)
        ),
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            sourcePort: 54_321,
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packets: [
                try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x03),
                try jackTripTestPacket(sequenceNumber: 1, payloadByte: 0x02),
            ]
        ),
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(datagrams: receivedDatagrams)
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "0.0.0.0",
            outputPath: "/tmp/jacktrip-native-rx.json",
            mediaPacketCount: 2
        ),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.learnedPeerHost == "203.0.113.10")
    #expect(report.learnedPeerPort == 54_321)
    #expect(report.redundancyRecoveredPacketCount == 1)
    #expect(report.packetLossCount == 0)
    #expect(report.duplicatePacketCount == 0)
    #expect(report.outOfOrderPacketCount == 0)
    #expect(report.sink.audioPacketCount == 3)
    #expect(report.sink.audioPayloadByteCount == 24)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(report.networkServiceClassStatus.contains("not-applied"))
}

@Test
func jackTripSocketReceiverLearnsPeerFromInboundUdpSource() throws {
    let audioPort = try freeLoopbackUdpPort()
    let resultBox = JackTripReceiveResultBox()

    DispatchQueue.global(qos: .userInitiated).async {
        resultBox.store(Result {
            try JackTripSocketMediaReceiver().receive(
                expectedDatagrams: 1,
                localHost: "127.0.0.1",
                peer: "0.0.0.0",
                audioPort: audioPort,
                headerMode: .default,
                emptyHeaderTemplate: nil,
                timeoutSeconds: 2
            )
        })
    }

    usleep(50_000)
    let sender = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(sender) }
    let packet = try jackTripTestPacket(sequenceNumber: 4, payloadByte: 0x04)
    try sendDatagram(
        try JackTripAudioPayloadCodec.encodeDefaultDatagram([packet]),
        socket: sender,
        host: "127.0.0.1",
        port: audioPort.bigEndian
    )

    let result = try resultBox.load()
    #expect(result.datagrams.count == 1)
    #expect(result.datagrams[0].sourceHost == "127.0.0.1")
    #expect(result.datagrams[0].sourcePort != nil)
    #expect(result.datagrams[0].packets.map(\.header.sequenceNumber) == [4])
}

@Test
func jackTripNativeRunnerReportsUnrecoveredGapsDuplicatesAndReordering() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x02)
        ),
        JackTripCompatibilityDatagram(
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packets: [
                try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x00),
                try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x02),
            ]
        ),
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(datagrams: receivedDatagrams)
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-native-rx.json",
            mediaPacketCount: 2
        ),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.packetLossCount == 1)
    #expect(report.duplicatePacketCount == 1)
    #expect(report.outOfOrderPacketCount == 1)
    #expect(report.redundancyRecoveredPacketCount == 0)
    #expect(report.sink.audioPacketCount == 3)
    #expect(report.sink.audioPayloadByteCount == 24)
}
