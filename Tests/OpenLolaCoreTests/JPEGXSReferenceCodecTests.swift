// Verifies that the JPEG XS reference codec round-trips a BGRA8 frame.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jpegXSReferenceCodecRoundTripsBGRA8Frame() throws {
    let width = 64
    let height = 64
    var payload = Data(count: width * height * 4)
    payload.withUnsafeMutableBytes { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: UInt8.self)
        for index in 0..<(width * height) {
            bytes[index * 4 + 0] = UInt8(index & 0xff)
            bytes[index * 4 + 1] = UInt8((index / width) & 0xff)
            bytes[index * 4 + 2] = UInt8((index / height) & 0xff)
            bytes[index * 4 + 3] = 255
        }
    }
    let metadata = CapturedVideoFrame(
        streamID: 100,
        sequenceNumber: 1,
        timestampNanoseconds: 10,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: width,
        height: height,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "jxs-test-frame"
    )
    let frame = RawCapturedVideoFrame(metadata: metadata, payload: payload)

    let encoded = try JPEGXSReferenceCodec.encode(frame: frame)
    let decoded = try JPEGXSReferenceCodec.decode(codestream: encoded, metadata: metadata)
    var configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    configuration.videoWidth = width
    configuration.videoHeight = height
    configuration.videoCompression = .jpegXS
    let packetBudget = DirectPeerVideoPacketBudget.estimate(configuration)
    let packets = try VideoMediaPacketizer.packets(
        for: RawCapturedVideoFrame(metadata: metadata, payload: encoded),
        maxPacketBytes: DirectPeerVideoPacketBudget.maxUdpPacketBytes,
        payloadType: .videoJpegXSFrameFragment
    )

    #expect(!encoded.isEmpty)
    #expect(decoded.metadata.width == width)
    #expect(decoded.metadata.height == height)
    #expect(decoded.metadata.pixelFormat == "bgra8")
    #expect(decoded.payload.count == width * height * 4)
    #expect(packetBudget.payloadBytesPerFrame == width * height / 2)
    #expect(packets.count <= packetBudget.maxFragmentsPerFrame)
}
