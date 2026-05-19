import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridAudioPayloadType21RoundTripsThroughRTP() throws {
    let pcm = Data([0, 1, 2, 3, 4, 5, 6, 7])
    let packet = try UltraGridCompatibility.audioPacket(
        sequenceNumber: 7,
        timestamp: 128,
        ssrc: 0x1234_5678,
        channels: 2,
        sampleRateHertz: 48_000,
        framesPerPacket: 128,
        pcmPayload: pcm
    )

    let decodedRTP = try RTPPacket.decode(try packet.encoded())
    let decodedPayload = try UltraGridAudioPayload.decode(decodedRTP.payload)

    #expect(decodedRTP.header.payloadType == 21)
    #expect(decodedRTP.header.sequenceNumber == 7)
    #expect(decodedPayload.header.substreamID == 2)
    #expect(decodedPayload.header.bufferNumber == 7)
    #expect(decodedPayload.header.payloadOffset == 0)
    #expect(decodedPayload.header.payloadByteCount == 8)
    #expect(decodedPayload.header.quantizationBits == 16)
    #expect(decodedPayload.header.sampleRateHertz == 48_000)
    #expect(decodedPayload.header.audioTag == UltraGridPCMAudioTag.littleEndianPCM)
    #expect(decodedPayload.pcmPayload == pcm)
    #expect(try packet.encoded() == Data([
        0x80, 0x15, 0x00, 0x07, 0x00, 0x00, 0x00, 0x80,
        0x12, 0x34, 0x56, 0x78, 0x00, 0x00, 0x1c, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08,
        0x00, 0x2e, 0xe0, 0x10, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    ]))
}

@Test
func ultraGridRawVideoPayloadType20FragmentsAndReassembles() throws {
    let frame = Data((0..<4_096).map { UInt8($0 & 0xff) })
    let packets = try UltraGridCompatibility.videoFragments(
        framePayload: frame,
        frameID: 42,
        sequenceStart: 100,
        timestamp: 9_000,
        ssrc: 0x8765_4321,
        width: 64,
        height: 32,
        frameRate: 30,
        bitsPerPixel: 24,
        maxPayloadBytes: 600
    )

    let fragments = try packets.map { packet in
        let decoded = try RTPPacket.decode(try packet.encoded())
        #expect(decoded.header.payloadType == 20)
        return try UltraGridVideoRawFragmentPayload.decode(decoded.payload)
    }
    let reassembled = try UltraGridCompatibility.reassembleVideoFrame(fragments)

    #expect(packets.count > 1)
    #expect(packets.last?.header.marker == true)
    #expect(fragments[0].header.bufferNumber == 42)
    #expect(fragments[0].header.payloadOffset == 0)
    #expect(fragments[0].header.payloadByteCount == UInt32(frame.count))
    #expect(fragments[0].header.width == 64)
    #expect(fragments[0].header.height == 32)
    #expect(fragments[0].header.fourCC == UltraGridMediaFormatRegistry.rgb24)
    #expect(fragments[0].header.frameRateNumerator == 30)
    #expect(try fragments[0].encoded().prefix(UltraGridVideoPayloadHeader.byteCount) == Data([
        0x00, 0x00, 0xa8, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x10, 0x00,
        0x00, 0x20, 0x00, 0x40,
        0x52, 0x47, 0x42, 0x33,
        0x00, 0x00, 0x00, 0xf0,
    ]))
    #expect(reassembled == frame)
}

@Test
func ultraGridCodecRejectsUnsupportedPayloadTypesAndModes() throws {
    let unsupportedRTP = RTPPacket(
        header: RTPPacketHeader(payloadType: 45, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedPayloadType(45)) {
        _ = try UltraGridCompatibility.decode(unsupportedRTP)
    }

    let unsupportedDynamicRTP = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("dynamic-rtp-unmapped-96")) {
        _ = try UltraGridCompatibility.decode(unsupportedDynamicRTP)
    }

    let unsupportedAudioTag = UltraGridAudioPayload(
        header: UltraGridAudioPayloadHeader(
            bufferNumber: 1,
            payloadOffset: 0,
            payloadByteCount: 4,
            quantizationBits: 16,
            sampleRateHertz: 48_000,
            audioTag: 2
        ),
        pcmPayload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("audio-tag-2")) {
        _ = try unsupportedAudioTag.encoded()
    }
}

@Test
func ultraGridReportsAdvancedModesAsUnsupportedUntilScoped() throws {
    #expect(UltraGridCompatibility.unsupportedModes.isEmpty)

    let encryptedVideo = RTPPacket(
        header: RTPPacketHeader(payloadType: 24, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("encrypted-video-missing-key")) {
        _ = try UltraGridCompatibility.decode(encryptedVideo)
    }

    let encryptedAudio = RTPPacket(
        header: RTPPacketHeader(payloadType: 25, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("encrypted-audio-missing-key")) {
        _ = try UltraGridCompatibility.decode(encryptedAudio)
    }
}

@Test
func ultraGridControlCommandsEncodeAndReportWithoutClaimingPeerControlPlane() throws {
    let command = try UltraGridControlCommand.parse("stats on")
    #expect(try command.encodedLine() == "stats on\r\n")
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument(
        "ultraGrid.controlCommand",
        "stats on\nexit"
    )) {
        _ = try UltraGridControlCommand.parse("stats on\nexit")
    }

    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ug-control.json",
            dryRun: true,
            ultraGridControlMode: .localTCP,
            ultraGridControlCommands: [.stats(true), .avDelayMilliseconds(15)]
        )
    )

    try report.validate()
    #expect(report.control.mode == .localTCP)
    #expect(report.control.port == 5054)
    #expect(report.control.commands == ["stats on\r\n", "av-delay 15\r\n"])
    #expect(report.verdict == .partial)
}

@Test
func ultraGridCompatibilityRunnerBuildsNativeTxRxReports() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/ug-native.json",
        dryRun: false,
        mediaMode: .audioVideo,
        audioPort: 50_006,
        videoPort: 50_004,
        videoWidth: 16,
        videoHeight: 16,
        videoFrameRate: 30,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration)
    let transmitter = UltraGridMemoryMediaTransmitter()
    let receiver = UltraGridMemoryMediaReceiver(datagrams: datagrams.map {
        UltraGridCompatibilityDatagram(
            stream: $0.stream,
            sourceHost: "127.0.0.1",
            sourcePort: 40_000,
            destinationPort: $0.destinationPort,
            rtp: $0.rtp
        )
    })

    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: transmitter,
        receiver: receiver
    )

    try report.validate()
    #expect(report.transmittedDatagramCount == datagrams.count)
    #expect(report.receivedDatagramCount == datagrams.count)
    #expect(report.audioDatagramCount == 1)
    #expect(report.videoDatagramCount >= 1)
    #expect(!report.unsupportedModes.contains("fec"))
    #expect(report.provider.audioSource == "synthetic")
    #expect(report.provider.videoSource == "synthetic")
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)
    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.audioPayloadByteCount == configuration.channels * configuration.framesPerPacket * 2)
    #expect(report.sink.videoFrameCount == 1)
    #expect(report.sink.videoPayloadByteCount == configuration.videoWidth * configuration.videoHeight)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(report.realLinkTransmitted)
    #expect(transmitter.transmittedDatagrams.count == datagrams.count)
}

@Test
func ultraGridServerClientTopologyListensWithoutPeerAndReportsPartialEvidence() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "",
        localHost: "0.0.0.0",
        outputPath: "/tmp/ug-server.json",
        dryRun: false,
        mediaMode: .audio,
        audioPort: 50_006,
        mediaPacketCount: 1,
        ultraGridTopologyMode: .serverClient,
        ultraGridTopologyRole: .server
    )
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
    ]
    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: received)
    )

    try report.validate()
    #expect(report.topology.mode == .serverClient)
    #expect(report.topology.role == .server)
    #expect(report.topology.state == .serverListening)
    #expect(!report.topology.peerRequired)
    #expect(!report.topology.peerConfigured)
    #expect(report.receivedDatagramCount == 1)
    #expect(report.verdict == .partial)
    #expect(report.missingEvidenceClassesForPass.contains(.fieldRoute))
}

@Test
func ultraGridServerClientClientRequiresPeer() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "",
        outputPath: "/tmp/ug-client.json",
        mediaMode: .audio,
        ultraGridTopologyMode: .serverClient,
        ultraGridTopologyRole: .client
    )

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.mvtpUltraGrid)) {
        _ = try UltraGridCompatibilityRunner.run(
            configuration: configuration,
            transmitter: UltraGridMemoryMediaTransmitter(),
            receiver: UltraGridMemoryMediaReceiver(datagrams: [])
        )
    }
}

@Test
func ultraGridPublicRunnerSelectsFixtureProvidersForPacketBytes() throws {
    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-public-fixture.json",
            dryRun: true,
            mediaMode: .audioVideo,
            framesPerPacket: 2,
            videoWidth: 2,
            videoHeight: 2,
            videoFrameRate: 30,
            videoBitsPerPixel: 8,
            audioCapture: "fixture:0102030405060708",
            videoCapture: "fixture:11121314",
            mediaPacketCount: 1
        )
    )

    try report.validate()
    let audio = try #require(report.datagrams.first { $0.stream == LoLaCompatibilityMediaStream.audio })
    let audioPayload = try UltraGridAudioPayload.decode(audio.rtp.payload)
    let videoFragments = try report.datagrams
        .filter { $0.stream == LoLaCompatibilityMediaStream.video }
        .map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }

    #expect(report.provider.audioSource == "fixture")
    #expect(report.provider.videoSource == "fixture")
    #expect(report.observedEvidenceClasses == [ExternalConnectorEvidenceClass.synthetic])
    #expect(audioPayload.pcmPayload == Data([1, 2, 3, 4, 5, 6, 7, 8]))
    #expect(try UltraGridCompatibility.reassembleVideoFrame(videoFragments) == Data([0x11, 0x12, 0x13, 0x14]))
}

@Test
func ultraGridLiveProviderSelectionReportsLiveDeviceEvidenceBeforeHardwareStart() throws {
    let provider = try UltraGridSessionMediaProvider(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-live-provider.json",
            mediaMode: .audioVideo,
            videoWidth: 2,
            videoHeight: 2,
            videoFrameRate: 30,
            videoBitsPerPixel: 8,
            audioCapture: "coreaudio:input-device-uid",
            audioPlayback: "coreaudio:output-device-uid",
            videoCapture: "avfoundation:camera-uid"
        )
    )

    #expect(provider.providerReport.audioSource == "coreaudio-live")
    #expect(provider.providerReport.videoSource == "avfoundation-raw8-live")
    #expect(provider.providerReport.observedEvidenceClasses == [ExternalConnectorEvidenceClass.liveDevice])
    #expect(
        ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: provider.providerReport.observedEvidenceClasses
        ) == [.referencePeer, .fieldRoute, .packetCapture, .timing, .teardown, .mediaQuality]
    )
}

@Test
func ultraGridMediaReportRequiresExplicitRuntimeEvidenceBoundary() throws {
    var report = UltraGridCompatibilityMediaReport(
        id: "ug-evidence-boundary",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .tx,
        mediaMode: .audio,
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
    #expect(throws: ExternalConnectorSessionError.emptyList("ultraGridMedia.observedEvidenceClasses")) {
        try report.validate()
    }

    report = UltraGridCompatibilityMediaReport(
        id: "ug-evidence-boundary",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .tx,
        mediaMode: .audio,
        datagrams: [],
        transmittedDatagramCount: 0,
        receivedDatagramCount: 0,
        missingEvidenceClassesForPass: [],
        realLinkTransmitted: false,
        verdict: .partial,
        notes: "Synthetic boundary test."
    )
    #expect(throws: ExternalConnectorSessionError.emptyList("ultraGridMedia.missingEvidenceClassesForPass")) {
        try report.validate()
    }

    report.missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.verdict = .pass
    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }

    report.realLinkTransmitted = true
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.missingEvidenceClassesForPass"
    )) {
        try report.validate()
    }

    report.missingEvidenceClassesForPass = []
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "ultraGridMedia.observedEvidenceClasses"
    )) {
        try report.validate()
    }

    report.observedEvidenceClasses = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    report.runtimeError = "late media failure"
    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeError")) {
        try report.validate()
    }
}

@Test
func ultraGridMediaReportAllowsPassOnlyWithCompleteRuntimeEvidence() throws {
    let report = UltraGridCompatibilityMediaReport(
        id: "ug-runtime-pass",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .txRx,
        mediaMode: .audioVideo,
        datagrams: [
            try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        ],
        transmittedDatagramCount: 1,
        receivedDatagramCount: 1,
        topology: UltraGridTopologyReport(
            mode: .directPeer,
            role: .direct,
            state: .directPeerReady,
            peerRequired: true,
            peerConfigured: true,
            localHost: "198.51.100.10",
            peer: "198.51.100.20",
            notes: "Measured direct-peer route evidence attached."
        ),
        provider: ExternalConnectorMediaProviderReport(
            audioSource: "coreaudio-live",
            videoSource: "avfoundation-raw8-live",
            observedEvidenceClasses: [.liveDevice],
            notes: "Measured live-device provider evidence."
        ),
        sink: ExternalConnectorMediaSinkReport(
            audioPacketCount: 1,
            audioPayloadByteCount: 8,
            videoFrameCount: 0,
            videoPayloadByteCount: 0,
            rejectedMediaCount: 0,
            notes: "Measured sink evidence."
        ),
        observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
        missingEvidenceClassesForPass: [],
        realLinkTransmitted: true,
        verdict: .pass,
        notes: "Complete measured evidence test."
    )

    try report.validate()
}

@Test
func ultraGridInvalidSyntheticPassFixtureIsRejected() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/UltraGridCompatibilityMediaReports/invalid/ultragrid-synthetic-pass.json")
    let report = try UltraGridCompatibilityMediaReport.decode(from: Data(contentsOf: url))

    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}

@Test
func ultraGridDatagramBuilderUsesInjectedMediaProviderBytes() throws {
    let videoFrame = Data((0..<128).map { UInt8($0) })
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-provider.json",
            mediaMode: .audioVideo,
            channels: 2,
            framesPerPacket: 2,
            videoWidth: 8,
            videoHeight: 8,
            videoFrameRate: 30,
            videoBitsPerPixel: 24,
            mediaPacketCount: 1
        ),
        mediaProvider: UltraGridFixedMediaProvider(
            audio: Data([0x01, 0x02, 0x03, 0x04]),
            video: videoFrame
        )
    )

    let audio = try #require(datagrams.first { $0.stream == .audio })
    let audioPayload = try UltraGridAudioPayload.decode(audio.rtp.payload)
    #expect(audioPayload.pcmPayload == Data([0x01, 0x02, 0x03, 0x04]))

    let videoFragments = try datagrams
        .filter { $0.stream == .video }
        .map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }
    #expect(try UltraGridCompatibility.reassembleVideoFrame(videoFragments) == videoFrame)
}

@Test
func ultraGridGeneratedRawVideoUsesFullConfiguredFrameAndCounters() throws {
    let width = 640
    let height = 360
    let bitsPerPixel = 24
    let frameByteCount = width * height * (bitsPerPixel / 8)
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-generated-frame.json",
            mediaMode: .video,
            videoWidth: width,
            videoHeight: height,
            videoFrameRate: 30,
            videoBitsPerPixel: bitsPerPixel,
            mediaPacketCount: 1
        )
    )

    let fragments = try datagrams.map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }
    let reassembled = try UltraGridCompatibility.reassembleVideoFrame(fragments)
    let expectedFragmentCount = (frameByteCount + 1_200 - UltraGridVideoPayloadHeader.byteCount - 1)
        / (1_200 - UltraGridVideoPayloadHeader.byteCount)
    let report = UltraGridCompatibilityMediaReport(
        id: "ug-generated-frame",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .tx,
        mediaMode: .video,
        datagrams: datagrams,
        transmittedDatagramCount: datagrams.count,
        receivedDatagramCount: 0,
        realLinkTransmitted: false,
        verdict: .partial,
        notes: "Generated raw-video sizing test."
    )

    try report.validate()
    #expect(datagrams.count == expectedFragmentCount)
    #expect(reassembled.count == frameByteCount)
    #expect(report.videoDatagramCount == expectedFragmentCount)
    #expect(report.videoFramePayloadByteCount == frameByteCount)
    #expect(report.rtpPayloadByteCount >= frameByteCount)
}

@Test
func ultraGridReceiveAnalysisReportsRtpQualityCounters() throws {
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 128, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 256, ssrc: 2),
        try ultraGridAudioDatagram(sequence: 3, timestamp: 512, ssrc: 2),
        try ultraGridAudioDatagram(sequence: 1, timestamp: 64, ssrc: 2),
    ]
    let receiver = UltraGridMemoryMediaReceiver(datagrams: received)

    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-rx.json",
            dryRun: false,
            mediaMode: .audio,
            audioPort: 50_006,
            mediaPacketCount: received.count
        ),
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.rtpPacketsLost == 0)
    #expect(report.rtpDuplicatePacketCount == 1)
    #expect(report.rtpOutOfOrderPacketCount == 1)
    #expect(report.rtpSsrcChangeCount == 1)
    #expect(report.rtpTimestampRegressionCount == 1)
    #expect(report.rtpJitterLikeArrivalDeltaCount == 1)
}

@Test
func ultraGridReceiveAnalysisReportsLossAndVideoReassemblyFailures() throws {
    let frame = Data((0..<2_048).map { UInt8($0 & 0xff) })
    let videoPackets = try UltraGridCompatibility.videoFragments(
        framePayload: frame,
        frameID: 9,
        sequenceStart: 10,
        timestamp: 3_000,
        ssrc: 3,
        width: 32,
        height: 32,
        frameRate: 30,
        bitsPerPixel: 24,
        maxPayloadBytes: 600
    )
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1),
        try ultraGridAudioDatagram(sequence: 2, timestamp: 128, ssrc: 1),
        UltraGridCompatibilityDatagram(
            stream: .video,
            sourceHost: "203.0.113.10",
            destinationPort: 50_004,
            rtp: try #require(videoPackets.first)
        ),
    ]
    let receiver = UltraGridMemoryMediaReceiver(datagrams: received)

    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-rx.json",
            dryRun: false,
            mediaMode: .audio,
            audioPort: 50_006,
            videoPort: 50_004,
            mediaPacketCount: received.count
        ),
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.rtpPacketsLost == 1)
    #expect(report.videoFrameReassemblyFailureCount == 1)
    #expect(report.sink.audioPacketCount == 2)
    #expect(report.sink.videoFrameCount == 0)
    #expect(report.sink.rejectedMediaCount == 1)
}

private func ultraGridAudioDatagram(
    sequence: UInt16,
    timestamp: UInt32,
    ssrc: UInt32
) throws -> UltraGridCompatibilityDatagram {
    UltraGridCompatibilityDatagram(
        stream: .audio,
        sourceHost: "203.0.113.10",
        destinationPort: 50_006,
        rtp: try UltraGridCompatibility.audioPacket(
            sequenceNumber: sequence,
            timestamp: timestamp,
            ssrc: ssrc,
            channels: 2,
            sampleRateHertz: 48_000,
            framesPerPacket: 128,
            pcmPayload: Data(repeating: 0, count: 8)
        )
    )
}

private struct UltraGridFixedMediaProvider: UltraGridMediaProviding {
    var audio: Data
    var video: Data

    func audioPCM(sequenceNumber _: Int, channels _: Int, framesPerPacket _: Int) throws -> Data {
        audio
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        video
    }
}
