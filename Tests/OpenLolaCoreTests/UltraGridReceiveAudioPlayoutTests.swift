// Verifies UltraGrid PT21 receive playout validates complete PCM before delivery.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridPT21PlayoutRejectsMalformedAudioBeforeQueuingExactPCM() throws {
    let sink = UltraGridCapturingAudioPlayout()
    try sink.start()
    let samples = Data([0x34, 0x12, 0xCC, 0xFF, 0x01, 0x80, 0xFF, 0x7F])
    let malformed = try ultraGridPT21Datagram(
        header: .init(
            substreamID: 2,
            bufferNumber: 1,
            payloadOffset: 0,
            payloadByteCount: UInt32(samples.count),
            quantizationBits: 24,
            sampleRateHertz: 48_000
        ),
        payload: samples
    )
    let valid = try ultraGridPT21Datagram(
        header: .init(
            substreamID: 2,
            bufferNumber: 2,
            payloadOffset: 0,
            payloadByteCount: UInt32(samples.count),
            quantizationBits: 16,
            sampleRateHertz: 48_000
        ),
        payload: samples
    )

    let report = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        [malformed, valid], encryptionConfiguration: nil, audioPlayout: sink
    )

    #expect(report.rejectedMediaCount == 1)
    #expect(report.audioPacketCount == 1)
    #expect(report.audioPayloadByteCount == samples.count)
    let block = try #require(sink.blocks.first)
    #expect(block.payload == samples)
    #expect(block.sampleRateHertz == 48_000)
    #expect(block.channels == 2)
    #expect(block.representation == .int16LittleEndian)
}

@Test
func ultraGridRunnerStopsInjectedAudioPlayoutAfterReceiveFailure() throws {
    let sink = UltraGridCapturingAudioPlayout()
    let configuration = ultraGridAudioReceiveConfiguration(dryRun: false)

    #expect(throws: UltraGridPlayoutTestError.self) {
        _ = try UltraGridCompatibilityRunner.run(
            configuration: configuration,
            transmitter: UltraGridMemoryMediaTransmitter(),
            receiver: UltraGridAlwaysFailReceiver(),
            mediaProvider: UltraGridSyntheticMediaProvider(),
            audioPlayout: sink
        )
    }
    #expect(sink.startCount == 1)
    #expect(sink.stopCount == 1)
}

@Test
func ultraGridInjectedAudioPlayoutCoexistsWithRawVideoPreview() throws {
    let audioSink = UltraGridCapturingAudioPlayout()
    let previewSink = RawBGRATestablePreviewSink()
    let audio = try UltraGridCompatibility.audioPacket(.init(
        sequenceNumber: 1,
        timestamp: 0,
        ssrc: 7,
        channels: 2,
        sampleRateHertz: 48_000,
        framesPerPacket: 1,
        pcmPayload: Data([0x00, 0x80, 0xFF, 0x7F])
    ))
    let video = try ultraGridPlayoutVideoDatagram()
    let configuration = ultraGridAudioReceiveConfiguration(dryRun: true, mediaMode: .audioVideo)

    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: [
            .init(stream: .audio, destinationPort: configuration.audioPort, rtp: audio),
            video,
        ]),
        mediaProvider: UltraGridSyntheticMediaProvider(),
        previewSink: previewSink,
        audioPlayout: audioSink
    )

    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.videoFrameCount == 1)
    #expect(audioSink.blocks.count == 1)
    #expect(previewSink.submittedFrames.count == 1)
    #expect(audioSink.startCount == 1)
    #expect(audioSink.stopCount == 1)
}

@Test
func ultraGridDuplexProviderUsesTransmitOnlyConfigurationWithoutPlayback() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "203.0.113.10",
        outputPath: "/tmp/ultragrid-duplex-provider.json"
    ) { input in
        input.audioPlayback = "coreaudio:receive-output"
    })

    let providerConfiguration = UltraGridCompatibilityRunner.transmitProviderConfiguration(for: configuration)

    #expect(providerConfiguration.role == .tx)
    #expect(providerConfiguration.audioPlayback == nil)
    #expect(configuration.role == .txRx)
    #expect(configuration.audioPlayback == "coreaudio:receive-output")
}

@Test
func ultraGridReceiveReportRejectsPacketWhoseProducedPlayoutIsEntirelyDropped() throws {
    let playout = UltraGridCapturingAudioPlayout(outcome: .init(droppedBlocks: 1))
    let datagram = try ultraGridPT21Datagram(
        header: .init(
            substreamID: 2,
            bufferNumber: 1,
            payloadOffset: 0,
            payloadByteCount: 4,
            quantizationBits: 16,
            sampleRateHertz: 48_000
        ),
        payload: Data([0, 0, 0, 0])
    )

    let report = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        [datagram], encryptionConfiguration: nil, audioPlayout: playout
    )

    #expect(report.audioPacketCount == 0)
    #expect(report.audioPayloadByteCount == 0)
    #expect(report.rejectedMediaCount == 1)
}

@Test
func ultraGridReceiveReportRecordsPartialPlayoutDropsWithoutRejectingPacket() throws {
    let playout = UltraGridCapturingAudioPlayout(outcome: .init(queuedBlocks: 1, droppedBlocks: 1))
    let datagram = try ultraGridPT21Datagram(
        header: .init(
            substreamID: 2,
            bufferNumber: 1,
            payloadOffset: 0,
            payloadByteCount: 4,
            quantizationBits: 16,
            sampleRateHertz: 48_000
        ),
        payload: Data([0, 0, 0, 0])
    )

    let report = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        [datagram], encryptionConfiguration: nil, audioPlayout: playout
    )

    #expect(report.audioPacketCount == 1)
    #expect(report.audioPayloadByteCount == 4)
    #expect(report.rejectedMediaCount == 1)
}

private func ultraGridPT21Datagram(
    header: UltraGridAudioPayloadHeader,
    payload: Data
) throws -> UltraGridCompatibilityDatagram {
    .init(
        stream: .audio,
        destinationPort: 50_006,
        rtp: .init(
            header: .init(
                payloadType: UltraGridCompatibility.audioPayloadType,
                sequenceNumber: UInt16(header.bufferNumber),
                timestamp: 0,
                ssrc: 1
            ),
            payload: try UltraGridAudioPayload(header: header, pcmPayload: payload).encoded()
        )
    )
}

private func ultraGridAudioReceiveConfiguration(
    dryRun: Bool,
    mediaMode: ExternalConnectorMediaMode = .audio
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/ultragrid-audio-playout.json"
    ) { input in
        input.dryRun = dryRun
        input.mediaMode = mediaMode
        input.channels = 2
        input.framesPerPacket = 1
        input.mediaPacketCount = 2
        input.videoWidth = 1
        input.videoHeight = 1
        input.videoFrameRate = 30
        input.videoBitsPerPixel = 32
    })
}

private func ultraGridPlayoutVideoDatagram() throws -> UltraGridCompatibilityDatagram {
    let packets = try UltraGridCompatibility.videoFragments(.init(
        frame: .init(payload: Data([1, 2, 3, 4]), id: 1, width: 1, height: 1, frameRate: 30, bitsPerPixel: 32),
        transport: .init(sequenceStart: 2, timestamp: 3_000, ssrc: 8, maxPayloadBytes: 64)
    ))
    return .init(stream: .video, destinationPort: 5_004, rtp: try #require(packets.first))
}

private enum UltraGridPlayoutTestError: Error {
    case expected
}

private struct UltraGridAlwaysFailReceiver: UltraGridCompatibilityMediaReceiving {
    func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        throw UltraGridPlayoutTestError.expected
    }
}

private final class UltraGridCapturingAudioPlayout: @unchecked Sendable, UltraGridReceiveAudioPlayout {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var blocks: [DecodedInterleavedPCM] = []
    private let outcome: DecodedAudioPlayoutEnqueueOutcome

    init(outcome: DecodedAudioPlayoutEnqueueOutcome = .init(queuedBlocks: 1)) {
        self.outcome = outcome
    }

    func start() throws { startCount += 1 }

    func stop() { stopCount += 1 }

    func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds _: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome {
        blocks.append(block)
        return outcome
    }
}
