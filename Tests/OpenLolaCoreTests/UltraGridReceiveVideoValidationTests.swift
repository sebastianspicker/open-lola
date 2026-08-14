// Verifies receive-side UltraGrid raw-video validation before allocation or preview delivery.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridRawVideoRejectsHugeDeclaredFrameBeforeReassemblyAllocation() throws {
    let fragment = UltraGridVideoRawFragmentPayload(
        header: ultraGridValidationHeader(payloadByteCount: UInt32.max),
        fragmentPayload: Data([0])
    )

    #expect(throws: UltraGridCompatibilityError.invalidField("video.payloadByteCount", Int(UInt32.max))) {
        _ = try UltraGridCompatibility.reassembleVideoFrame([fragment])
    }
}

@Test(arguments: [false, true])
func ultraGridRawVideoRejectsMismatchedFragmentHeaders(timingMismatch: Bool) throws {
    let first = UltraGridVideoRawFragmentPayload(
        header: ultraGridValidationHeader(payloadByteCount: 4), fragmentPayload: Data([1, 2])
    )
    var secondHeader = ultraGridValidationHeader(payloadByteCount: 4, payloadOffset: 2)
    if timingMismatch {
        secondHeader.frameRateNumerator = 60
    } else {
        secondHeader.width = 2
    }
    let second = UltraGridVideoRawFragmentPayload(header: secondHeader, fragmentPayload: Data([3, 4]))

    #expect(throws: UltraGridCompatibilityError.unsupportedMode("mixed-video-fragments")) {
        _ = try UltraGridCompatibility.reassembleVideoFrame([first, second])
    }
}

@Test
func ultraGridFECRecoversMissingFirstRawFragment() throws {
    let payload = Data([1, 2, 3, 4, 5, 6, 7, 8])
    let packets = try UltraGridCompatibility.videoFragments(.init(
        frame: .init(payload: payload, id: 4, width: 2, height: 1, frameRate: 30, bitsPerPixel: 32),
        transport: .init(sequenceStart: 10, timestamp: 90_000, ssrc: 9, maxPayloadBytes: 28)
    ))
    let parity = try UltraGridCompatibility.fecParityPacket(
        protecting: packets, sequenceNumber: 12, timestamp: 90_000, ssrc: 9
    )

    #expect(try UltraGridCompatibility.reassembleReceivedVideoFrame(from: [packets[1], parity]).payload == payload)
}

@Test
func ultraGridPreviewRejectsFailedSubmitAndUsesRemoteRTPMetadata() throws {
    let packet = try ultraGridValidationVideoPacket()
    let datagram = UltraGridCompatibilityDatagram(stream: .video, destinationPort: 50_004, rtp: packet)
    let failingPreview = UltraGridRejectingPreviewSink()
    let report = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        [datagram], encryptionConfiguration: nil, previewAdapter: .init(sink: failingPreview)
    )
    #expect(report.videoFrameCount == 0)
    #expect(report.rejectedMediaCount == 1)

    let preview = RawBGRATestablePreviewSink()
    #expect(UltraGridRawVideoPreviewAdapter(sink: preview).submit(
        try UltraGridCompatibility.reassembleReceivedVideoFrame(from: [packet])
    ))
    let frame = try #require(preview.submittedFrames.first)
    #expect(frame.metadata.timestampNanoseconds == 1_000_000_000)
    #expect(frame.metadata.timestampBasis == .remoteRTP90kNanoseconds)
    #expect(frame.metadata.sourceRole == .remotePeer)
}

private func ultraGridValidationHeader(
    payloadByteCount: UInt32,
    payloadOffset: UInt32 = 0
) -> UltraGridVideoPayloadHeader {
    UltraGridVideoPayloadHeader(
        bufferNumber: 1,
        payloadOffset: payloadOffset,
        payloadByteCount: payloadByteCount,
        geometry: .init(width: 1, height: 1, fourCC: .init(rawValue: 0x5247_4241)),
        timing: .init(frameRateNumerator: 30)
    )
}

private func ultraGridValidationVideoPacket() throws -> RTPPacket {
    try #require(UltraGridCompatibility.videoFragments(.init(
        frame: .init(payload: Data([1, 2, 3, 4]), id: 1, width: 1, height: 1, frameRate: 30, bitsPerPixel: 32),
        transport: .init(sequenceStart: 1, timestamp: 90_000, ssrc: 1, maxPayloadBytes: 64)
    )).first)
}

private enum UltraGridPreviewRejectingError: Error {
    case expected
}

private final class UltraGridRejectingPreviewSink: RawBGRAPreviewSink, @unchecked Sendable {
    func submit(frame _: RawCapturedVideoFrame) throws { throw UltraGridPreviewRejectingError.expected }
}
