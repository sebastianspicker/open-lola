// Shared LoLa compatibility media codec video helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func expectVideoPreludePacket() throws {
let packets = try LoLaCompatibilityMediaCodec.videoPackets(
sequenceNumber: 7,
payload: Data((0..<32).map(UInt8.init))
)
let prelude = try #require(LoLaCompatibilityMediaCodec.decode(packets[0].payload).videoPrelude)
let fragment = try #require(LoLaCompatibilityMediaCodec.decode(packets[1].payload).normalFragment)
let body = try #require(fragment.body)

#expect(packets.count == 2)
#expect(packets[0].kind == .videoPrelude)
#expect(packets[1].kind == .videoFragment)
#expect(packets[0].payload.count == 0x40)
#expect(packets[0].payload[0..<12] == Data([
0xfd, 0xfd, 0xfd, 0xfd,
0xdf, 0xdf, 0xdf, 0xdf,
0xaa, 0xaa, 0xaa, 0xaa
]))
#expect(packets[0].payload[0x10..<0x14] == Data([7, 0, 0, 0]))
#expect(packets[0].payload[0x14..<0x18] == Data([40, 0, 0, 0]))
#expect(packets[0].payload[0x1c..<0x20] == Data([1, 0, 0, 0]))
#expect(prelude.frameID == 7)
#expect(prelude.serializedSize == 40)
#expect(prelude.fragmentCount == 1)
#expect(fragment.header.frameID == 7)
#expect(fragment.header.fragmentCount == 1)
#expect(body.payloadLength == 32)
#expect(body.payload == Data((0..<32).map(UInt8.init)))
}

func expectVideoDatagramCount() throws {
let fragmentedPayload = Data(repeating: 0x42, count: 1_920 * 1_080 * 3)
let fragmentedPackets = try LoLaCompatibilityMediaCodec.videoPackets(
sequenceNumber: 1,
payload: fragmentedPayload
)
let expected = LoLaCompatibilityMediaCodec.expectedDatagramCount(
mediaMode: .audioVideo,
videoWidth: 1_920,
videoHeight: 1_080,
videoBitsPerPixel: 24,
frameCountPerStream: 1
)

#expect(expected == 1 + fragmentedPackets.count)
#expect(expected > 2)
}

func expectVideoFragmentLimitBoundaries() throws {
let belowMaxFragmentPayload = Data(
repeating: 0x40,
count: LoLaCompatibilityMediaCodec.maxVideoFragmentCount - 1 - 8
)
let belowMaxPackets = try LoLaCompatibilityMediaCodec.videoPackets(
sequenceNumber: 7,
payload: belowMaxFragmentPayload,
maxFragmentBodyByteCount: 1
)
let maxFragmentPayload = Data(
repeating: 0x41,
count: LoLaCompatibilityMediaCodec.maxVideoFragmentCount - 8
)
let maxPackets = try LoLaCompatibilityMediaCodec.videoPackets(
sequenceNumber: 8,
payload: maxFragmentPayload,
maxFragmentBodyByteCount: 1
)
let overflowingPayload = Data(
repeating: 0x42,
count: LoLaCompatibilityMediaCodec.maxVideoFragmentCount + 1 - 8
)

#expect(belowMaxPackets.count == LoLaCompatibilityMediaCodec.maxVideoFragmentCount)
#expect(maxPackets.count == LoLaCompatibilityMediaCodec.maxVideoFragmentCount + 1)
#expect(throws: LoLaCompatibilityMediaCodecError.fragmentCountTooLarge(
LoLaCompatibilityMediaCodec.maxVideoFragmentCount + 1
)) {
_ = try LoLaCompatibilityMediaCodec.videoPackets(
sequenceNumber: 9,
payload: overflowingPayload,
maxFragmentBodyByteCount: 1
)
}
}

func expectGeneratedRawVideoPayloadSize() throws {
let sizeConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-generated-video-size.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .video
  input.videoWidth = 640
  input.videoHeight = 480
  input.videoBitsPerPixel = 8
})
    let payload = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: sizeConfiguration,
        sequenceNumber: 0
    )
    let packets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 3,
        payload: payload
    )
    let prelude = try #require(LoLaCompatibilityMediaCodec.decode(packets[0].payload).videoPrelude)

#expect(payload.count == 307_200)
#expect(prelude.serializedSize == 307_208)
}

func expectGeneratedRawVideoPayloadPattern() throws {
let patternConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-generated-video-pattern.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .video
  input.videoWidth = 64
  input.videoHeight = 48
  input.videoBitsPerPixel = 8
})

    let first = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: patternConfiguration,
        sequenceNumber: 0
    )
    let later = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: patternConfiguration,
        sequenceNumber: 5
    )

    #expect(first[24 * 64 + 32] == 255)
    #expect(first[2 * 64 + 2] == 220)
    #expect(later[2 * 64 + 2] != 220)
#expect(later[25 * 64 + 35] == 255 || later[25 * 64 + 35] == 32)
#expect(first != later)
}

func expectGeneratedRawVideoPayloadOverflowChecks() throws {
let overflowConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-generated-video-overflow.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .video
  input.videoWidth = Int.max
  input.videoHeight = 2
  input.videoBitsPerPixel = 8
})

    #expect(throws: MediaGeometrySizingError.byteCountOverflow("rawVideoFrameBytes")) {
        _ = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
            configuration: overflowConfiguration,
            sequenceNumber: 0
        )
    }
    #expect(LoLaCompatibilityMediaCodec.expectedDatagramCount(
        mediaMode: .video,
        videoWidth: Int.max,
        videoHeight: 2,
        videoBitsPerPixel: 8,
        frameCountPerStream: 2
) > LoLaCompatibilityMediaCodec.maxVideoFragmentCount)
}
