import Foundation
import Testing

@testable import OpenLolaCore

@Test
func rtpL24PacketRoundTripsHeaderAndPayload() throws {
    let payload = Data(repeating: 0x7f, count: AES67ST2110L24Profile.payloadByteCount)
    let packet = RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 65_535, timestamp: 4_294_967_200, ssrc: 0x1234_5678),
        payload: payload
    )

    let decoded = try RTPPacket.decode(try packet.encoded())

    #expect(decoded.header.payloadType == 96)
    #expect(decoded.header.sequenceNumber == 65_535)
    #expect(decoded.header.timestamp == 4_294_967_200)
    #expect(decoded.header.ssrc == 0x1234_5678)
    #expect(decoded.payload == payload)
}

@Test
func rtpL24ValidatorAcceptsSequenceWrapAndTimestampStep() throws {
    var validator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 42)
    let first = RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 65_535, timestamp: 960, ssrc: 42),
        payload: Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    )
    let second = RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 0, timestamp: 1_008, ssrc: 42),
        payload: Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    )

    try validator.validate(first)
    try validator.validate(second)

    #expect(validator.expectedSSRC == 42)
}

@Test
func rtpL24ValidatorRejectsPayloadTypeSSRCSequenceTimestampAndLength() throws {
    let validPayload = Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    var validator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 10)

    #expect(throws: RTPPacketError.unsupportedPayloadType(97)) {
        try validator.validate(RTPPacket(
            header: RTPPacketHeader(payloadType: 97, sequenceNumber: 1, timestamp: 48, ssrc: 10),
            payload: validPayload
        ))
    }
    #expect(throws: RTPPacketError.ssrcMismatch(expected: 10, actual: 11)) {
        try validator.validate(RTPPacket(
            header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 11),
            payload: validPayload
        ))
    }

    try validator.validate(RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 10),
        payload: validPayload
    ))
    #expect(throws: RTPPacketError.sequenceDiscontinuity(expected: 2, actual: 0)) {
        try validator.validate(RTPPacket(
            header: RTPPacketHeader(sequenceNumber: 0, timestamp: 0, ssrc: 10),
            payload: validPayload
        ))
    }

    var timestampValidator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 10)
    try timestampValidator.validate(RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 10),
        payload: validPayload
    ))
    #expect(throws: RTPPacketError.timestampStepMismatch(expected: 96, actual: 97)) {
        try timestampValidator.validate(RTPPacket(
            header: RTPPacketHeader(sequenceNumber: 2, timestamp: 97, ssrc: 10),
            payload: validPayload
        ))
    }

    var lengthValidator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 10)
    #expect(throws: RTPPacketError.payloadLengthMismatch(expected: AES67ST2110L24Profile.payloadByteCount, actual: 3)) {
        try lengthValidator.validate(RTPPacket(
            header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 10),
            payload: Data([1, 2, 3])
        ))
    }
}

@Test
func rtpL24ValidatorCountsForwardGapAndResynchronizes() throws {
    let payload = Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    var validator = AES67ST2110L24RTPReceiveValidator(expectedSSRC: 10)

    try validator.validate(RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 10),
        payload: payload
    ))
    try validator.validate(RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 3, timestamp: 144, ssrc: 10),
        payload: payload
    ))
    try validator.validate(RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 4, timestamp: 192, ssrc: 10),
        payload: payload
    ))

    #expect(validator.lostPackets == 1)
}

@Test
func l24CodecRoundTripsFloat32StereoWithClampBoundaries() throws {
    var samples: [Float] = [-1.25, -1.0, -0.5, 0, 0.5, 1.0, 1.25, 0.125]
    while samples.count < AES67ST2110L24Profile.framesPerPacket * AES67ST2110L24Profile.channelCount {
        samples.append(0)
    }
    let source = samples.withUnsafeBufferPointer { Data(buffer: $0) }

    let l24 = try L24PCMCodec.encodeFloat32InterleavedStereo(source)
    let decoded = try L24PCMCodec.decodeFloat32InterleavedStereo(l24)
    let decodedSamples = decoded.withUnsafeBytes { pointer in
        Array(pointer.bindMemory(to: Float.self))
    }

    #expect(l24.count == AES67ST2110L24Profile.payloadByteCount)
    #expect(decodedSamples[0] == -1.0)
    #expect(decodedSamples[1] == -1.0)
    #expect(abs(decodedSamples[2] - -0.5) < 0.000_001)
    #expect(decodedSamples[3] == 0)
    #expect(abs(decodedSamples[4] - 0.5) < 0.000_001)
    #expect(decodedSamples[5] == 1.0)
    #expect(decodedSamples[6] == 1.0)
}

@Test
func l24CodecUsesSymmetricScaleAndExplicit24BitSignExtension() throws {
    var samples: [Float] = [-0.5, 0.5]
    while samples.count < AES67ST2110L24Profile.framesPerPacket * AES67ST2110L24Profile.channelCount {
        samples.append(0)
    }
    let source = samples.withUnsafeBufferPointer { Data(buffer: $0) }

    let l24 = try L24PCMCodec.encodeFloat32InterleavedStereo(source)
    let decoded = try L24PCMCodec.decodeFloat32InterleavedStereo(l24)
    let decodedSamples = decoded.withUnsafeBytes { pointer in
        Array(pointer.bindMemory(to: Float.self))
    }

    #expect(abs(decodedSamples[0] - -0.5) < 0.000_001)
    #expect(abs(decodedSamples[1] - 0.5) < 0.000_001)
}

@Test
func aes67SdpGenerationParsesRoundTrip() throws {
    let sdp = AES67ST2110L24SDP(
        address: "192.0.2.10",
        port: 50_004,
        direction: .bidirectional,
        ptpEvidenceSummary: "ptp profile aes67 domain 0 grandmaster 00-11 lock true offset 2us"
    )

    let text = sdp.text()
    let parsed = try AES67ST2110L24SDP.parse(text)

    #expect(text.contains("m=audio 50004 RTP/AVP 96"))
    #expect(text.contains("a=rtpmap:96 L24/48000/2"))
    #expect(text.contains("a=ptime:1"))
    #expect(text.contains("a=maxptime:1"))
    #expect(text.contains("a=sendrecv"))
    #expect(text.contains("a=ts-refclk:ptp=IEEE1588-2019"))
    #expect(parsed.address == "192.0.2.10")
    #expect(parsed.port == 50_004)
    #expect(parsed.direction == .bidirectional)
}
