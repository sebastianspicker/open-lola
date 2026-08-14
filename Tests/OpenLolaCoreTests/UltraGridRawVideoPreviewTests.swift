// Verifies raw UltraGrid receive frames reach the native BGRA preview boundary without format guesses.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridPreviewSwizzlesRGBAAndPreservesRTPMetadata() throws {
    let sink = RawBGRATestablePreviewSink()
    let adapter = UltraGridRawVideoPreviewAdapter(sink: sink)

    #expect(adapter.submit(ultraGridPreviewFrame(
        fourCC: 0x5247_4241, payload: Data([1, 2, 3, 4, 5, 6, 7, 8]), width: 2, height: 1
    )))
    let frame = try #require(sink.submittedFrames.first)
    #expect(frame.payload == Data([3, 2, 1, 4, 7, 6, 5, 8]))
    #expect(frame.metadata.sequenceNumber == 42)
    #expect(frame.metadata.timestampNanoseconds == 100_000_000)
    #expect(frame.metadata.timestampBasis == .remoteRTP90kNanoseconds)
    #expect(frame.metadata.sourceRole == .remotePeer)
    #expect(frame.metadata.streamID == 3)
    #expect(frame.metadata.pixelFormat == "bgra8")
}

@Test
func ultraGridPreviewExpandsExactRGB3Only() throws {
    let sink = RawBGRATestablePreviewSink()
    let adapter = UltraGridRawVideoPreviewAdapter(sink: sink)

    #expect(adapter.submit(ultraGridPreviewFrame(
        fourCC: 0x5247_4233, payload: Data([1, 2, 3, 4, 5, 6]), width: 2, height: 1
    )))
    #expect(sink.submittedFrames.first?.payload == Data([3, 2, 1, 255, 6, 5, 4, 255]))
}

@Test
func ultraGridPreviewRejectsAmbiguousRGB3SizeAndUnknownFourCC() {
    let sink = RawBGRATestablePreviewSink()
    let adapter = UltraGridRawVideoPreviewAdapter(sink: sink)

    #expect(!adapter.submit(ultraGridPreviewFrame(
        fourCC: 0x5247_4233, payload: Data([1, 2]), width: 2, height: 1
    )))
    #expect(!adapter.submit(ultraGridPreviewFrame(
        fourCC: 0x4A50_4547, payload: Data([1, 2, 3, 4]), width: 1, height: 1
    )))
    #expect(adapter.droppedFrameCount == 2)
    #expect(sink.submittedFrames.isEmpty)
}

@Test
func ultraGridFECReassemblyPreservesFirstRawHeaderAndRTPMetadata() throws {
    let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data(repeating: 0x11, count: 64), id: 8, width: 4, height: 4, frameRate: 30, bitsPerPixel: 32
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 20, timestamp: 6_000, ssrc: 0x4F4C_5556, maxPayloadBytes: 48
        )
    ))
    let fec = try UltraGridCompatibility.fecParityPacket(
        protecting: packets, sequenceNumber: 20 + UInt16(packets.count), timestamp: 6_000, ssrc: 0x4F4C_5556
    )
    let received = packets.enumerated().compactMap { index, packet in index == 1 ? nil : packet } + [fec]
    let expectedHeader = try UltraGridVideoRawFragmentPayload.decode(packets[0].payload).header
    let reassembled = try UltraGridCompatibility.reassembleReceivedVideoFrame(from: received)

    #expect(reassembled.header == expectedHeader)
    #expect(reassembled.sequenceNumber == 20)
    #expect(reassembled.timestamp == 6_000)
    #expect(reassembled.payload == Data(repeating: 0x11, count: 64))
}

@Test
func ultraGridIncrementalAndDeterministicPreviewDeliveryMatch() throws {
    let datagram = try ultraGridPreviewDatagram()
    let deterministicSink = RawBGRATestablePreviewSink()
    let deterministicAdapter = UltraGridRawVideoPreviewAdapter(sink: deterministicSink)
    _ = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        [datagram], encryptionConfiguration: nil, previewAdapter: deterministicAdapter
    )

    let incrementalSink = RawBGRATestablePreviewSink()
    let incrementalAdapter = UltraGridRawVideoPreviewAdapter(sink: incrementalSink)
    let observer = UltraGridIncrementalReceiveObserver(
        encryptionConfiguration: nil, previewAdapter: incrementalAdapter
    )
    observer.record(datagram)
    _ = observer.finish()

    #expect(deterministicSink.submittedFrames == incrementalSink.submittedFrames)
    #expect(deterministicAdapter.deliveredFrameCount == 1)
    #expect(incrementalAdapter.deliveredFrameCount == 1)
}

@Test
func ultraGridPreviewAdapterClosesItsSinkOnce() {
    let sink = UltraGridClosingPreviewSink()
    let adapter = UltraGridRawVideoPreviewAdapter(sink: sink)

    adapter.close()
    adapter.close()
    #expect(sink.closeCount == 1)
}

@Test
func ultraGridRunnerClosesInjectedPreviewSinkAfterDeterministicReceive() throws {
    let sink = UltraGridClosingPreviewSink()
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/ultragrid-preview.json"
    ) { input in
        input.dryRun = true
        input.mediaMode = .video
        input.videoWidth = 1
        input.videoHeight = 1
        input.videoFrameRate = 30
        input.videoBitsPerPixel = 32
        input.mediaPacketCount = 1
    })

    _ = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: [try ultraGridPreviewDatagram()]),
        previewSink: sink
    )
    #expect(sink.closeCount == 1)
}

private func ultraGridPreviewFrame(
    fourCC: UInt32,
    payload: Data,
    width: UInt16,
    height: UInt16
) -> UltraGridReassembledRawVideoFrame {
    UltraGridReassembledRawVideoFrame(
        header: UltraGridVideoPayloadHeader(
            substreamID: 3,
            bufferNumber: 7,
            payloadOffset: 0,
            payloadByteCount: UInt32(payload.count),
            geometry: UltraGridVideoPayloadGeometry(width: width, height: height, fourCC: .init(rawValue: fourCC)),
            timing: UltraGridVideoPayloadTiming(frameRateNumerator: 30)
        ),
        sequenceNumber: 42,
        timestamp: 9_000,
        payload: payload
    )
}

private func ultraGridPreviewDatagram() throws -> UltraGridCompatibilityDatagram {
    let frame = ultraGridPreviewFrame(
        fourCC: 0x5247_4241, payload: Data([1, 2, 3, 4]), width: 1, height: 1
    )
    return UltraGridCompatibilityDatagram(
        stream: .video,
        destinationPort: 50_004,
        rtp: RTPPacket(
            header: RTPPacketHeader(
                payloadType: UltraGridCompatibility.videoPayloadType,
                sequenceNumber: 42,
                timestamp: 9_000,
                ssrc: 0x4F4C_5556
            ),
            payload: try UltraGridVideoRawFragmentPayload(header: frame.header, fragmentPayload: frame.payload).encoded()
        )
    )
}

private final class UltraGridClosingPreviewSink: RawBGRAPreviewSink, @unchecked Sendable {
    var closeCount = 0

    func submit(frame _: RawCapturedVideoFrame) throws {}

    func close() { closeCount += 1 }
}
