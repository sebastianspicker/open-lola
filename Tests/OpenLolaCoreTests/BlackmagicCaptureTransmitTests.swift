// Verifies that test-pattern capture frames expose the M08 stream contract.
import Testing

@testable import OpenLolaCore

@Test
func testPatternCaptureFramesExposeM08StreamContract() throws {
    let source = TestPatternCameraSource(
        width: 1_920,
        height: 1_080,
        frameIntervalNanoseconds: 16_666_667,
        streamID: 100,
        sourceRole: .testPattern,
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        pixelFormat: "bgra8"
    )

    let frame = try #require(source.nextFrame())

    #expect(frame.streamID == 100)
    #expect(frame.sourceRole == .testPattern)
    #expect(frame.timestampBasis == .syntheticMonotonicNanoseconds)
    #expect(frame.frameRate == VideoFrameRate(numerator: 60, denominator: 1))
    #expect(frame.pixelFormat == "bgra8")
}

@Test
func videoCaptureReportIncludesM08StreamContract() throws {
    let report = VideoCaptureSyntheticSmoke.run()

    try report.validate()

    #expect(report.stream.streamID == 100)
    #expect(report.stream.sourceRole == .testPattern)
    #expect(report.stream.timestampBasis == .syntheticMonotonicNanoseconds)
    #expect(report.format.width == 1_280)
    #expect(report.format.height == 720)
    #expect(report.format.nominalFrameRate == 30)
    #expect(report.format.pixelFormat == "synthetic-rgb")
}

@Test
func rawVideoTransportFragmentsCarryBlackmagicTxMetadata() throws {
    let frame = CapturedVideoFrame(
        streamID: 200,
        sequenceNumber: 42,
        timestampNanoseconds: 123_456_789,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .blackmagicInput,
        width: 1_920,
        height: 1_080,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        fingerprint: "blackmagic-input-42"
    )

    let packet = RawVideoFrameTransport.packet(for: frame)
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 1_200)
    let decoded = try VideoTransportFragment.decode(try #require(fragments.first).encoded())

    #expect(packet.streamID == 200)
    #expect(packet.sourceRole == .blackmagicInput)
    #expect(packet.timestampBasis == .hostUptimeNanoseconds)
    #expect(packet.width == 1_920)
    #expect(packet.height == 1_080)
    #expect(packet.pixelFormat == "bgra8")
    #expect(packet.frameRate == VideoFrameRate(numerator: 60, denominator: 1))
    #expect(decoded.streamID == 200)
    #expect(decoded.sourceRole == .blackmagicInput)
    #expect(decoded.timestampBasis == .hostUptimeNanoseconds)
    #expect(decoded.width == 1_920)
    #expect(decoded.height == 1_080)
    #expect(decoded.pixelFormat == "bgra8")
    #expect(decoded.frameRate == VideoFrameRate(numerator: 60, denominator: 1))
}

@Test
func videoReassemblerRejectsMixedMetadataInsideOneFrame() throws {
    let frame = try blackmagicTestPatternFrame()
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    var mismatched = fragments[1]
    mismatched.sourceRole = .blackmagicInput
    let reassembler = VideoFrameReassembler()

    #expect(try reassembler.receive(fragments[0]) == nil)
    #expect(throws: VideoTransportFragmentError.inconsistentFrameMetadata) {
        _ = try reassembler.receive(mismatched)
    }
}

private func blackmagicTestPatternFrame() throws -> CapturedVideoFrame {
    let source = TestPatternCameraSource(
        width: 64,
        height: 48,
        frameIntervalNanoseconds: 1
    )
    return try #require(source.nextFrame())
}

@Test
func videoTransmitQueueDropsBeforeAudioImpact() throws {
    var queue = LatestFrameQueue(maxDepth: 1)
    let source = TestPatternCameraSource(width: 320, height: 240, frameIntervalNanoseconds: 1)

    queue.enqueue(try #require(source.nextFrame()))
    queue.enqueue(try #require(source.nextFrame()))
    queue.enqueue(try #require(source.nextFrame()))

    #expect(queue.frames.map(\.sequenceNumber) == [2])
    #expect(queue.droppedFrames == 2)
    #expect(queue.maxDepth == 1)
    #expect(queue.preallocatedFrameSlots == 1)
}
