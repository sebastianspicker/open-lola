// Verifies that the LoLa MJPEG encoder emits JPEG markers and strips extra application metadata.
import Foundation
import Testing
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@testable import OpenLolaCore

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@Test
func lolaMjpegJPEGEncoderEmitsMarkersAndStripsExtraApplicationMetadata() throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try #require(CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let image = try #require(context.makeImage())

    let jpeg = try LoLaMjpegJPEGEncoder.jpegData(from: image)

    #expect(jpeg.starts(with: Data([0xff, 0xd8])))
    #expect(jpeg.suffix(2) == Data([0xff, 0xd9]))

    let metadataJpeg = Data([
        0xff, 0xd8,
        0xff, 0xe0, 0x00, 0x07, 0x4a, 0x46, 0x49, 0x46, 0x00,
        0xff, 0xe1, 0x00, 0x06, 0x45, 0x78, 0x69, 0x66,
        0xff, 0xed, 0x00, 0x06, 0x38, 0x42, 0x49, 0x4d,
        0xff, 0xfe, 0x00, 0x05, 0x58, 0x59, 0x5a,
        0xff, 0xdb, 0x00, 0x04, 0x00, 0x11,
        0xff, 0xda, 0x00, 0x04, 0x03, 0x00,
        0x44, 0x55, 0xff, 0xd9
    ])

    let stripped = LoLaMjpegJPEGEncoder.stripNonJfifMetadata(from: metadataJpeg)

    #expect(stripped.contains(Data([0xff, 0xe0, 0x00, 0x07, 0x4a, 0x46, 0x49, 0x46, 0x00])))
    #expect(!stripped.contains(Data([0x45, 0x78, 0x69, 0x66])))
    #expect(!stripped.contains(Data([0x38, 0x42, 0x49, 0x4d])))
    #expect(!stripped.contains(Data([0xff, 0xfe])))
    #expect(stripped.suffix(2) == Data([0xff, 0xd9]))
}
#endif

@Test
func lolaAudioCodecSerializesDeclaredLivePayloadsAndRejectsWrongSize() throws {
    let fragments = try LoLaCompatibilityMediaCodec.audioFragments(
        sequenceNumber: 0x0102_0304,
        channels: 2
    )

    #expect(fragments.count == 1)
    let fragment = try #require(fragments.first)
    let decoded = try LoLaCompatibilityMediaCodec.decode(fragment.payload)
    let normal = try #require(decoded.normalFragment)

    #expect(fragment.kind == .audioFragment)
    #expect(fragment.stream == .audio)
    #expect(fragment.frameID == 0x0102_0305)
    #expect(fragment.fragmentIndex == 0)
    #expect(fragment.fragmentCount == 1)
    #expect(fragment.finalFragment == true)
    #expect(fragment.fragmentPayloadLength == 264)
    #expect(fragment.payload.count == 1066)
    #expect(fragment.payload[0..<4] == Data([0xfd, 0xfd, 0xfd, 0xfd]))
    #expect(fragment.payload[4..<8] == Data([0xdf, 0xdf, 0xdf, 0xdf]))
    #expect(fragment.payload[8..<12] == Data([0xee, 0xee, 0xee, 0xee]))
    let body = try #require(normal.body)
    #expect(body.sequence == 0x0102_0304)
    #expect(body.payloadLength == 256)
    #expect(body.payload.count == 256)

    let paddedFragment = try #require(LoLaCompatibilityMediaCodec.audioFragments(
        sequenceNumber: 41,
        channels: 2
    ).first)
    let paddedNormal = try #require(LoLaCompatibilityMediaCodec.decode(paddedFragment.payload).normalFragment)
    let paddedBody = try #require(paddedNormal.body)

    #expect(paddedNormal.header.frameID == 42)
#expect(paddedNormal.header.fragmentPayloadLength == 264)
#expect(paddedBody.sequence == 41)
#expect(paddedBody.payloadLength == 256)
}

@Test
func lolaAudioCodecSerializesLivePayloadsAndRejectsWrongSize() throws {
let payload = Data((0..<256).map { UInt8($0 & 0xff) })

let liveFragment = try #require(LoLaCompatibilityMediaCodec.audioFragments(
        sequenceNumber: 12,
        channels: 2,
        payload: payload
    ).first)
    let liveBody = try #require(LoLaCompatibilityMediaCodec.decode(liveFragment.payload).normalFragment?.body)

    #expect(liveFragment.kind == .audioFragment)
    #expect(liveFragment.frameID == 13)
    #expect(liveBody.sequence == 12)
    #expect(liveBody.payload == payload)

    #expect(throws: LoLaCompatibilityMediaCodecError.serializedSizeMismatch(expected: 256, actual: 2)) {
        _ = try LoLaCompatibilityMediaCodec.audioFragments(
            sequenceNumber: 0,
            channels: 2,
            payload: Data([1, 2])
        )
    }
}
@Test
func lolaVideoCodecBuildsPreludeCountsDatagramsAndEnforcesFragmentLimits() throws {
try expectVideoPreludePacket()
try expectVideoDatagramCount()
try expectVideoFragmentLimitBoundaries()
}

@Test
func lolaGeneratedRawVideoPayloadUsesNegotiatedSizePatternAndOverflowChecks() throws {
try expectGeneratedRawVideoPayloadSize()
try expectGeneratedRawVideoPayloadPattern()
try expectGeneratedRawVideoPayloadOverflowChecks()
}

// swiftlint:disable function_body_length
@Test
func lolaFragmentReassemblyRejectsDuplicateMissingWrongPreludeAndInconsistentHeaders() throws {
    let packets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 4,
        payload: Data(repeating: 0x41, count: 2_500),
        maxFragmentBodyByteCount: 900
    )
    let prelude = try #require(LoLaCompatibilityMediaCodec.decode(packets[0].payload).videoPrelude)
    let fragments = try packets.dropFirst().map {
        try #require(LoLaCompatibilityMediaCodec.decode($0.payload).normalFragment)
    }

    let reassembled = try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: fragments)
    #expect(reassembled.sequence == 4)
    #expect(reassembled.payloadLength == 2_500)
    #expect(reassembled.payload == Data(repeating: 0x41, count: 2_500))

    #expect(throws: LoLaCompatibilityMediaCodecError.duplicateFragment(0)) {
        _ = try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: [fragments[0], fragments[0]])
    }
    #expect(throws: LoLaCompatibilityMediaCodecError.missingFragment(1)) {
        _ = try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: fragments.filter {
            $0.header.fragmentIndex != 1
        })
    }
    let networkOrder = try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: [
        fragments[1],
        fragments[0],
        fragments[2]
    ])
    #expect(networkOrder == reassembled)
    let wrongPrelude = LoLaCompatibilityVideoPrelude(frameID: 99, serializedSize: 0, fragmentCount: 1)
    #expect(throws: LoLaCompatibilityMediaCodecError.frameIDMismatch(expected: 99, actual: 4)) {
        _ = try LoLaCompatibilityMediaCodec.reassemble(prelude: wrongPrelude, fragments: [fragments[0]])
    }

    let inconsistentPackets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 9,
        payload: Data(repeating: 0x51, count: 1_300),
        maxFragmentBodyByteCount: 700
    )
let inconsistentPrelude = try #require(
LoLaCompatibilityMediaCodec.decode(inconsistentPackets[0].payload).videoPrelude
)
    let inconsistentFragments = try inconsistentPackets.dropFirst().map {
        try #require(LoLaCompatibilityMediaCodec.decode($0.payload).normalFragment)
    }

    var trailingPayload = inconsistentPackets[1].payload
    trailingPayload.append(0x99)
    #expect(throws: LoLaCompatibilityMediaCodecError.serializedSizeMismatch(
        expected: inconsistentPackets[1].payload.count,
        actual: trailingPayload.count
    )) {
        _ = try LoLaCompatibilityMediaCodec.decode(trailingPayload)
    }

    var wrongCount = inconsistentFragments
    wrongCount[0].header.fragmentCount = 99
#expect(throws: LoLaCompatibilityMediaCodecError.fragmentCountMismatch(
expected: 2,
actual: 99
)) {
        _ = try LoLaCompatibilityMediaCodec.reassemble(prelude: inconsistentPrelude, fragments: wrongCount)
    }

    var wrongFinalFlag = inconsistentFragments
    wrongFinalFlag[0].header.finalFlag = true
#expect(throws: LoLaCompatibilityMediaCodecError.invalidFinalFlag(
fragmentIndex: 0,
expected: false,
actual: true
)) {
        _ = try LoLaCompatibilityMediaCodec.reassemble(prelude: inconsistentPrelude, fragments: wrongFinalFlag)
    }

    var oversizedFragmentCount = Data(repeating: 0, count: LoLaCompatibilityMediaCodec.preludeByteCount)
    oversizedFragmentCount[0..<12] = Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xaa, 0xaa, 0xaa, 0xaa
    ])
    writePreludeLE32(1, to: &oversizedFragmentCount, offset: 0x10)
    writePreludeLE32(8, to: &oversizedFragmentCount, offset: 0x14)
    writePreludeLE32(
        UInt32(LoLaCompatibilityMediaCodec.maxVideoFragmentCount + 1),
        to: &oversizedFragmentCount,
        offset: 0x1c
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(
        LoLaCompatibilityMediaCodec.maxVideoFragmentCount + 1
    )) {
        _ = try LoLaCompatibilityMediaCodec.decode(oversizedFragmentCount)
    }

    var oversizedSerializedSize = oversizedFragmentCount
    writePreludeLE32(1, to: &oversizedSerializedSize, offset: 0x1c)
    writePreludeLE32(
        UInt32(LoLaCompatibilityMediaCodec.maxSerializedMediaByteCount + 1),
        to: &oversizedSerializedSize,
        offset: 0x14
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.serializedSizeTooLarge(
        LoLaCompatibilityMediaCodec.maxSerializedMediaByteCount + 1
    )) {
        _ = try LoLaCompatibilityMediaCodec.decode(oversizedSerializedSize)
    }
}
// swiftlint:enable function_body_length

@Test
func lolaWireFrameUsesRecoveredTTLAndPortEquality() throws {
    let frame = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-ttl.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audio
})
    ).first

    let encoded = try #require(frame?.encodedFrame)
    let decoded = try LoLaCompatibilityWireFrame.decode(encoded)

    #expect(encoded[22] == 0x80)
    #expect(decoded.sourcePort == decoded.destinationPort)
}

private func writePreludeLE32(_ value: UInt32, to data: inout Data, offset: Int) {
    let bytes = withUnsafeBytes(of: value.littleEndian, Array.init)
    data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
}
