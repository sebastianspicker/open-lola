// Verifies that UltraGrid runner sends each captured audio packet before capturing the next.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridRunnerSendsEachCapturedAudioPacketBeforeCapturingTheNext() throws {
    let probe = UltraGridStreamingOrderProbe()
    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ultragrid-streaming.json"
        ) { input in
            input.dryRun = true
            input.mediaMode = .audio
            input.mediaPacketCount = 3
        }),
        transmitter: UltraGridStreamingOrderTransmitter(probe: probe),
        receiver: UltraGridMemoryMediaReceiver(datagrams: []),
        mediaProvider: UltraGridStreamingOrderProvider(probe: probe)
    )

    #expect(report.transmittedDatagramCount == 3)
    #expect(probe.emittedDatagramCount == 3)
    #expect(!probe.capturedAheadOfTransmit)
}

@Test
func ultraGridLiveAudioAndVideoUseFairPerFrameCaptureScheduling() throws {
    let provider = UltraGridLiveSchedulingProbeProvider()
    _ = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ultragrid-live-stream-order.json"
        ) { input in
            input.dryRun = true
            input.mediaMode = .audioVideo
            input.mediaPacketCount = 3
            input.videoWidth = 1
            input.videoHeight = 1
            input.videoBitsPerPixel = 8
        }),
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: []),
        mediaProvider: provider
    )

    #expect(provider.captureOrder == ["audio", "video", "audio", "video", "audio", "video"])
}

@Test
func ultraGridSocketReceiveDrainBudgetBoundsEachStreamTurn() {
    var budget = UltraGridSocketReceiveDrainBudget(limit: ultraGridSocketPerStreamDrainPacketLimit)

    for _ in 0..<100 where budget.hasCapacity {
        budget.recordProcessedDatagram()
    }

    #expect(budget.processed == 32)
    #expect(!budget.hasCapacity)
}

@Test
func ultraGridSocketReceiveDeadlineAndRetainedEvidenceLimitsAreBounded() {
    assertUltraGridReceiveDeadlineAndEvidenceLimits()
    assertUltraGridReceiveEvidenceLedgerLimit()
    assertUltraGridFullDuplexCompletionRules()
}

private func assertUltraGridReceiveDeadlineAndEvidenceLimits() {
    #expect(ultraGridReceiveDeadlineNanoseconds(nowNanoseconds: 10, timeoutSeconds: 2) == 2_000_000_010)
    #expect(ultraGridReceiveDeadlineNanoseconds(nowNanoseconds: UInt64.max - 4, timeoutSeconds: 1) == UInt64.max)
    #expect(ultraGridSocketReceiveEvidencePacketLimit(receivedCount: 0) == 32)
    #expect(ultraGridSocketReceiveEvidencePacketLimit(
        receivedCount: ultraGridSocketConcurrentReceiveEvidenceLimit - 1
    ) == 32)
    #expect(ultraGridSocketReceiveEvidencePacketLimit(
        receivedCount: ultraGridSocketConcurrentReceiveEvidenceLimit
    ) == 32)
}

private func assertUltraGridReceiveEvidenceLedgerLimit() {
    var ledger = UltraGridSocketReceiveEvidenceLedger(evidenceLimit: 2)
    for sequenceNumber in 0..<3 {
        ledger.record(ultraGridTransmitDropDatagram(
            stream: .audio,
            marker: false,
            payloadType: 21,
            sequenceNumber: UInt16(sequenceNumber)
        ))
    }
    #expect(ledger.receivedDatagramCount == 3)
    #expect(ledger.evidence.map(\.rtp.header.sequenceNumber) == [0, 1])
}

private func assertUltraGridFullDuplexCompletionRules() {
    #expect(!ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: false,
        expectedDatagrams: 2,
        receivedDatagramCount: 2
    ))
    #expect(ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: true,
        expectedDatagrams: 2,
        receivedDatagramCount: 2
    ))
    #expect(!ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: true,
        expectedDatagrams: nil,
        receivedDatagramCount: 100
    ))
    #expect(ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: true,
        expectedDatagrams: 0,
        receivedDatagramCount: 0
    ))
    let completedTransmit = Result<UltraGridCompatibilityTransmitResult, Error>.success(
        UltraGridCompatibilityTransmitResult(
            successfulDatagramCount: 0,
            attemptedDatagramCount: 3
        )
    )
    #expect(ultraGridExpectedFullDuplexReceiveCount(
        requestedDatagrams: 0,
        transmitResult: completedTransmit
    ) == 3)
    #expect(ultraGridExpectedFullDuplexReceiveCount(
        requestedDatagrams: 2,
        transmitResult: completedTransmit
    ) == 2)
}

@Test
func ultraGridReportUsesTotalReceiveCountBeyondRetainedEvidence() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "203.0.113.20",
        outputPath: "/tmp/ug-counted-evidence.json"
    ) { input in
        input.dryRun = false
        input.mediaMode = .audio
        input.mediaPacketCount = 300
    })
    let evidence = try #require(
        UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration).first
    )
    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridCountedEvidenceReceiver(
            result: UltraGridCompatibilityReceiveResult(
                datagrams: [evidence],
                receivedDatagramCount: 300
            )
        )
    )

    #expect(report.receivedDatagramCount == 300)
    #expect(report.runtimeError == nil)
}

@Test
func ultraGridIncrementalSocketObserverAnalyzesCompleteFrameBeyondEvidenceCap() throws {
    let frame = Data(repeating: 0x5a, count: 400_000)
    let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: frame,
            id: 44,
            width: 800,
            height: 500,
            frameRate: 30,
            bitsPerPixel: 8
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 1,
            timestamp: 90_000,
            ssrc: 77
        )
    ))
    #expect(packets.count > ultraGridSocketConcurrentReceiveEvidenceLimit)
    var ledger = UltraGridSocketReceiveEvidenceLedger(
        evidenceLimit: ultraGridSocketConcurrentReceiveEvidenceLimit,
        observer: UltraGridIncrementalReceiveObserver(encryptionConfiguration: nil)
    )
    for packet in packets {
        ledger.record(UltraGridCompatibilityDatagram(
            stream: .video,
            destinationPort: 50_004,
            rtp: packet
        ))
    }

    let summary = try #require(ledger.observationSummary())
    #expect(ledger.receivedDatagramCount == packets.count)
    #expect(ledger.evidence.count == ultraGridSocketConcurrentReceiveEvidenceLimit)
    #expect(summary.sink.videoFrameCount == 1)
    #expect(summary.sink.videoPayloadByteCount == frame.count)
    #expect(summary.sink.rejectedMediaCount == 0)
    #expect(summary.analysis.lost == 0)
    #expect(summary.analysis.videoFrameReassemblyFailures == 0)
    #expect(!summary.analysis.videoFrameRecoveryFailed)
}

@Test
func ultraGridReceiveOnlyUsesAnalyticCountWithoutCallingTheProvider() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "203.0.113.20",
        outputPath: "/tmp/ug-rx-only-analytic.json"
    ) { input in
        input.dryRun = false
        input.mediaMode = .video
        input.mediaPacketCount = 1
        input.videoWidth = 640
        input.videoHeight = 480
        input.videoBitsPerPixel = 8
    })
    let expected = try UltraGridCompatibilityRunner.expectedReceiveDatagramCount(configuration)
    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridCountedEvidenceReceiver(
            result: UltraGridCompatibilityReceiveResult(datagrams: [], receivedDatagramCount: expected)
        ),
        mediaProvider: UltraGridFailingMediaProvider()
    )

    #expect(report.receivedDatagramCount == expected)
    #expect(report.runtimeError == nil)
}

@Test
func ultraGridZeroSuccessfulTxDoesNotClaimLinkOrSuppressRxContract() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "127.0.0.1",
        outputPath: "/tmp/ug-zero-success.json"
    ) { input in
        input.dryRun = false
        input.mediaMode = .audio
        input.mediaPacketCount = 2
    })

    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridZeroSendTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: [])
    )

    #expect(report.transmittedDatagramCount == 0)
    #expect(!report.realLinkTransmitted)
    #expect(report.verdict == .fail)
    #expect(report.runtimeError?.contains("received 0 of 2 expected") == true)
    #expect(report.notes.contains("runtime verdict is FAIL"))
}

@Test
func ultraGridSocketTransmitDropsOnlyTheBlockedVideoFrameAndOptionalFEC() {
    var state = UltraGridSocketTransmitDropState()
    let firstVideoFragment = ultraGridTransmitDropDatagram(stream: .video, marker: false, payloadType: 20)
    let lastVideoFragment = ultraGridTransmitDropDatagram(stream: .video, marker: true, payloadType: 20)
    let fec = ultraGridTransmitDropDatagram(stream: .video, marker: false, payloadType: 22)
    let nextFrame = ultraGridTransmitDropDatagram(stream: .video, marker: true, payloadType: 20)
    let audio = ultraGridTransmitDropDatagram(stream: .audio, marker: false, payloadType: 21)

    let shouldAttemptFirstVideoFragment = state.shouldAttempt(firstVideoFragment)
    #expect(shouldAttemptFirstVideoFragment)
    state.recordWouldBlock(firstVideoFragment)
    let shouldAttemptLastVideoFragment = state.shouldAttempt(lastVideoFragment)
    #expect(!shouldAttemptLastVideoFragment)
    let shouldAttemptFEC = state.shouldAttempt(fec)
    #expect(!shouldAttemptFEC)
    let shouldAttemptNextFrame = state.shouldAttempt(nextFrame)
    #expect(shouldAttemptNextFrame)
    state.recordWouldBlock(audio)
    let shouldAttemptAudio = state.shouldAttempt(audio)
    #expect(shouldAttemptAudio)
}

@Test
func ultraGridTxRxPreparesReceiveSocketsBeforeTheFirstTransmit() throws {
    let probe = UltraGridStreamingOrderProbe()
    probe.requiresReceiverBound = true
    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .mvtpUltraGrid,
            role: .txRx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ultragrid-bound-before-send.json"
        ) { input in
            input.dryRun = true
            input.mediaMode = .audio
            input.mediaPacketCount = 2
        }),
        transmitter: UltraGridStreamingOrderTransmitter(probe: probe),
        receiver: UltraGridBoundOrderReceiver(probe: probe),
        mediaProvider: UltraGridStreamingOrderProvider(probe: probe)
    )

    #expect(report.transmittedDatagramCount == 2)
    #expect(probe.receiverBound)
    #expect(!probe.transmitStartedBeforeReceiverBound)
}

@Test
func ultraGridAudioPayloadType21RoundTripsThroughRTP() throws {
    let pcm = Data([0, 1, 2, 3, 4, 5, 6, 7])
    let packet = try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
        sequenceNumber: 7,
        timestamp: 128,
        ssrc: 0x1234_5678,
        channels: 2,
        sampleRateHertz: 48_000,
        framesPerPacket: 128,
        pcmPayload: pcm
    ))

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
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
    ]))
}

@Test
func ultraGridRawVideoPayloadType20FragmentsAndReassembles() throws {
    let frame = Data((0..<4_096).map { UInt8($0 & 0xff) })
    let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: frame,
            id: 42,
            width: 64,
            height: 32,
            frameRate: 30,
            bitsPerPixel: 24
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 100,
            timestamp: 9_000,
            ssrc: 0x8765_4321,
            maxPayloadBytes: 600
        )
    ))

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
    #expect(fragments[0].header.fourCC == (try UltraGridFourCC("RGB3")))
    #expect(fragments[0].header.frameRateNumerator == 30)
    #expect(try fragments[0].encoded().prefix(UltraGridVideoPayloadHeader.byteCount) == Data([
        0x00, 0x00, 0xa8, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x10, 0x00,
        0x00, 0x20, 0x00, 0x40,
        0x52, 0x47, 0x42, 0x33,
        0x00, 0x00, 0x00, 0xf0
    ]))
    #expect(reassembled == frame)
}

@Test
func ultraGridMultiFrameVideoSequencesAdvanceByActualFragmentAndFECCount() throws {
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ultragrid-video-sequences.json"
        ) { input in
            input.dryRun = true
            input.mediaMode = .video
            input.mediaPacketCount = 2
            input.videoWidth = 128
            input.videoHeight = 128
            input.videoBitsPerPixel = 8
            input.ultraGridFECMode = .singleParity
        })
    )
    let video = datagrams.filter { $0.stream == .video }
    let firstFrameFragments = video.filter {
        $0.rtp.header.payloadType == UltraGridCompatibility.videoPayloadType
            && (try? UltraGridVideoRawFragmentPayload.decode($0.rtp.payload).frameID) == 0
    }
    let secondFrameFirstSequence = try #require(video.first {
        $0.rtp.header.payloadType == UltraGridCompatibility.videoPayloadType
            && (try? UltraGridVideoRawFragmentPayload.decode($0.rtp.payload).frameID) == 1
    }).rtp.header.sequenceNumber

    #expect(firstFrameFragments.count > 8)
    #expect(secondFrameFirstSequence == UInt16(firstFrameFragments.count + 1))
    #expect(video.map(\.rtp.header.sequenceNumber) == (0..<UInt16(video.count)).map { $0 })
    #expect(Set(video.map(\.rtp.header.sequenceNumber)).count == video.count)
}

private func ultraGridTransmitDropDatagram(
    stream: LoLaCompatibilityMediaStream,
    marker: Bool,
    payloadType: UInt8,
    sequenceNumber: UInt16 = 1
) -> UltraGridCompatibilityDatagram {
    UltraGridCompatibilityDatagram(
        stream: stream,
        destinationPort: 50_004,
        rtp: RTPPacket(
            header: RTPPacketHeader(
                payloadType: payloadType,
                marker: marker,
                sequenceNumber: sequenceNumber,
                timestamp: 1,
                ssrc: 1
            ),
            payload: Data([0x01])
        )
    )
}
