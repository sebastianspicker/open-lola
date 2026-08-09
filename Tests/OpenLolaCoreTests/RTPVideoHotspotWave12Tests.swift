// Covers deterministic RTP, AES67 SDP, PCM, and video-fragment hotspot branches.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave12RTPDecodeRejectsTruncatedHeader() {
    #expect(throws: RTPPacketError.truncatedPacket(byteCount: 11)) {
        _ = try RTPPacket.decode(Data(repeating: 0, count: 11))
    }
}

@Test
func wave12RTPDecodeRejectsUnsupportedVersion() {
    #expect(throws: RTPPacketError.unsupportedVersion(1)) {
        _ = try RTPPacket.decode(wave12RTPWire(firstByte: 0x40))
    }
}

@Test
func wave12RTPDecodeRejectsPadding() {
    #expect(throws: RTPPacketError.unsupportedPadding) {
        _ = try RTPPacket.decode(wave12RTPWire(firstByte: 0xa0))
    }
}

@Test
func wave12RTPDecodeRejectsExtensions() {
    #expect(throws: RTPPacketError.unsupportedExtension) {
        _ = try RTPPacket.decode(wave12RTPWire(firstByte: 0x90))
    }
}

@Test
func wave12RTPDecodeRejectsCSRCEntries() {
    #expect(throws: RTPPacketError.unsupportedCSRCCount(1)) {
        _ = try RTPPacket.decode(wave12RTPWire(firstByte: 0x81))
    }
}

@Test
func wave12RTPDecodeAndEncodeRejectZeroSSRC() {
    #expect(throws: RTPPacketError.invalidSSRC(0)) {
        _ = try RTPPacket.decode(wave12RTPWire())
    }
    #expect(throws: RTPPacketError.invalidSSRC(0)) {
        _ = try RTPPacket(
            header: RTPPacketHeader(sequenceNumber: 1, timestamp: 2, ssrc: 0),
            payload: Data()
        ).encoded()
    }
}

@Test
func wave12RTPEncodingPreservesMarkerAndMasksPayloadType() throws {
    let packet = RTPPacket(
        header: RTPPacketHeader(payloadType: 0xff, marker: true, sequenceNumber: 0x1020, timestamp: 3, ssrc: 4),
        payload: Data([0xaa])
    )

    let encoded = try packet.encoded()

    #expect(encoded[0] == 0x80)
    #expect(encoded[1] == 0xff)
    #expect(Data(encoded[2...3]) == Data([0x10, 0x20]))
    #expect(try RTPPacket.decode(encoded).header.marker)
    #expect(try RTPPacket.decode(encoded).header.payloadType == 127)
}

@Test
func wave12RTPPCMValueAPIsRejectEmptyPayloads() {
    #expect(throws: L24PCMCodecError.invalidFloatPayloadByteCount(0)) {
        _ = try L24PCMCodec.encodeFloat32InterleavedStereo(Data())
    }
    #expect(throws: L24PCMCodecError.invalidL24PayloadByteCount(0)) {
        _ = try L24PCMCodec.decodeFloat32InterleavedStereo(Data())
    }
}

@Test
func wave12RTPPCMEncodeRejectsShortInputBuffer() {
    let input = Data(count: 1)
    var output = Data(count: AES67ST2110L24Profile.payloadByteCount)

    _ = input.withUnsafeBytes { source in
        output.withUnsafeMutableBytes { destination in
            #expect(throws: L24PCMCodecError.invalidFloatPayloadByteCount(1)) {
                try L24PCMCodec.encodeFloat32InterleavedStereo(source, into: destination)
            }
        }
    }
}

@Test
func wave12RTPPCMEncodeRejectsShortOutputBuffer() {
    let input = Data(count: AES67ST2110L24Profile.framesPerPacket * AES67ST2110L24Profile.channelCount * 4)
    var output = Data(count: AES67ST2110L24Profile.payloadByteCount - 1)
    let expectedOutputCount = output.count

    _ = input.withUnsafeBytes { source in
        output.withUnsafeMutableBytes { destination in
            #expect(throws: L24PCMCodecError.invalidL24PayloadByteCount(expectedOutputCount)) {
                try L24PCMCodec.encodeFloat32InterleavedStereo(source, into: destination)
            }
        }
    }
}

@Test
func wave12RTPPCMDecodeRejectsShortInputAndOutputBuffers() {
    let shortInput = Data(count: 1)
    var validInput = Data(count: AES67ST2110L24Profile.payloadByteCount)
    var output = Data(count: 1)

    _ = shortInput.withUnsafeBytes { source in
        validInput.withUnsafeMutableBytes { destination in
            #expect(throws: L24PCMCodecError.invalidL24PayloadByteCount(1)) {
                try L24PCMCodec.decodeFloat32InterleavedStereo(source, into: destination)
            }
        }
    }
    _ = validInput.withUnsafeBytes { source in
        output.withUnsafeMutableBytes { destination in
            #expect(throws: L24PCMCodecError.invalidFloatPayloadByteCount(1)) {
                try L24PCMCodec.decodeFloat32InterleavedStereo(source, into: destination)
            }
        }
    }
}

@Test
func wave12RTPValidatorRejectsForwardGapWithWrongTimestamp() throws {
    var validator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 8)
    let payload = wave12RTPPayload()
    try validator.validate(wave12RTPPacket(sequence: 10, timestamp: 480, payload: payload))

    #expect(throws: RTPPacketError.timestampStepMismatch(expected: 576, actual: 577)) {
        try validator.validate(wave12RTPPacket(sequence: 12, timestamp: 577, payload: payload))
    }
    #expect(validator.lostPackets == 0)
}

@Test
func wave12RTPValidatorRejectsLargeSequenceDiscontinuity() throws {
    var validator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 8)
    let payload = wave12RTPPayload()
    try validator.validate(wave12RTPPacket(sequence: 10, timestamp: 480, payload: payload))

    #expect(throws: RTPPacketError.sequenceDiscontinuity(expected: 11, actual: 1_036)) {
        try validator.validate(wave12RTPPacket(sequence: 1_036, timestamp: 49_680, payload: payload))
    }
}

@Test
func wave12RTPSDPRejectsMissingAndMalformedMediaLines() {
    #expect(throws: AES67ST2110L24SDPError.missingLine("m=audio")) {
        _ = try AES67ST2110L24SDP.parse("v=0\n")
    }
    #expect(throws: AES67ST2110L24SDPError.invalidLine("m=audio not-a-port RTP/AVP")) {
        _ = try AES67ST2110L24SDP.parse("m=audio not-a-port RTP/AVP\n")
    }
}

@Test
func wave12RTPSDPRejectsUnsupportedMediaAndRTPMap() {
    let valid = wave12RTPSDPText()
    #expect(throws: AES67ST2110L24SDPError.unsupportedMedia("m=audio 5004 UDP 96")) {
        _ = try AES67ST2110L24SDP.parse(valid.replacingOccurrences(of: "RTP/AVP", with: "UDP"))
    }
    #expect(throws: AES67ST2110L24SDPError.unsupportedRTPMap) {
        _ = try AES67ST2110L24SDP.parse(valid.replacingOccurrences(of: "L24/48000/2", with: "L16/48000/2"))
    }
}

@Test
func wave12RTPSDPRejectsUnsupportedPacketTime() {
    let invalid = wave12RTPSDPText()
        .replacingOccurrences(of: "a=ptime:1", with: "a=ptime:0.5")
        .replacingOccurrences(of: "a=maxptime:1", with: "a=maxptime:0.5")

    #expect(throws: AES67ST2110L24SDPError.unsupportedPacketTime) {
        _ = try AES67ST2110L24SDP.parse(invalid)
    }
}

@Test
func wave12RTPSDPMapsEveryMediaDirection() throws {
    let cases: [(MediaStreamDirection, String)] = [
        (.send, "a=sendonly"),
        (.receive, "a=recvonly"),
        (.bidirectional, "a=sendrecv"),
        (.disabled, "a=inactive")
    ]

    for (direction, attribute) in cases {
        let text = AES67ST2110L24SDP(address: "192.0.2.1", port: 5_004, direction: direction).text()
        let parsed = try AES67ST2110L24SDP.parse(text)
        #expect(text.contains(attribute))
        #expect(parsed.direction == direction)
    }
}

@Test
func wave12RTPRawVideoFragmentationRejectsZeroPayloadAndSmallPackets() {
    let empty = RawCapturedVideoFrame(metadata: wave12RTPVideoFrame(), payload: Data())
    #expect(throws: VideoTransportFragmentError.invalidFramePayloadByteCount(0)) {
        _ = try RawVideoFrameTransport.fragments(for: empty, maxPacketBytes: 256)
    }
    #expect(throws: VideoTransportFragmentError.self) {
        _ = try RawVideoFrameTransport.fragments(for: wave12RTPVideoFrame(), maxPacketBytes: 1)
    }
}

@Test
func wave12RTPRawVideoFragmentsPreserveRawSlicesAndCursorFinishes() throws {
    let metadata = wave12RTPVideoFrame(width: 20, height: 10)
    let raw = RawCapturedVideoFrame(metadata: metadata, payload: Data(0..<UInt8(200)))
    let fragments = try RawVideoFrameTransport.fragments(for: raw, maxPacketBytes: 128)
    var cursor = try RawVideoFrameTransport.syntheticFragmentCursor(for: metadata, maxPacketBytes: 128)
    var cursorFragments: [VideoTransportFragment] = []

    while let fragment = cursor.next() {
        cursorFragments.append(fragment)
    }

    #expect(fragments.count > 1)
    #expect(Data(fragments.flatMap { $0.payload }) == raw.payload)
    #expect(fragments.map(\.payloadOffset) == fragments.indices.map { $0 * fragments[0].payload.count })
    #expect(cursorFragments.count == cursor.fragmentCount)
    #expect(cursor.next() == nil)
}

@Test
func wave12RTPRawVideoFragmentCountRejectsZeroLimitAndCeils() {
    let frame = wave12RTPVideoFrame(width: 2, height: 2)

    #expect(RawVideoFrameTransport.fragmentCount(for: frame, maxPayloadBytes: 0) == 0)
    #expect(RawVideoFrameTransport.fragmentCount(for: frame, maxPayloadBytes: 5) == 4)
}

private func wave12RTPWire(firstByte: UInt8 = 0x80) -> Data {
    Data([firstByte, 96, 0, 1, 0, 0, 0, 2, 0, 0, 0, 0])
}

private func wave12RTPPayload() -> Data {
    Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
}

private func wave12RTPPacket(sequence: UInt16, timestamp: UInt32, payload: Data) -> RTPPacket {
    RTPPacket(
        header: RTPPacketHeader(sequenceNumber: sequence, timestamp: timestamp, ssrc: 8),
        payload: payload
    )
}

private func wave12RTPSDPText() -> String {
    AES67ST2110L24SDP(address: "192.0.2.1", port: 5_004).text()
}

private func wave12RTPVideoFrame(width: Int = 2, height: Int = 2) -> CapturedVideoFrame {
    CapturedVideoFrame(
        streamID: 1,
        sequenceNumber: 7,
        timestampNanoseconds: 8,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .testPattern,
        width: width,
        height: height,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "wave12"
    )
}
