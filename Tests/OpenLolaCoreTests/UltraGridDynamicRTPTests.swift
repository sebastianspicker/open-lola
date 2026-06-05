import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridDynamicRtpPayloadRegistryNegotiatesImplementedCodecsAndRejectsUnsupportedCodecs() throws {
    let dynamicAudio = try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
        sequenceNumber: 1,
        timestamp: 128,
        ssrc: 2,
        channels: 2,
        sampleRateHertz: 48_000,
        framesPerPacket: 2,
        pcmPayload: Data([0, 1, 2, 3]),
        payloadType: 96
    ))
    let dynamicVideo = try #require(try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data(repeating: 0x44, count: 16),
            id: 1,
            width: 4,
            height: 4,
            frameRate: 30,
            bitsPerPixel: 8
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 2,
            timestamp: 3_000,
            ssrc: 3,
            payloadType: 97
        )
    )).first)
    let registry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [
        96: .pcmAudio,
        97: .rawVideo,
    ])

    #expect(try UltraGridCompatibility.decode(dynamicAudio, registry: registry).stream == .audio)
    #expect(try UltraGridCompatibility.decode(dynamicVideo, registry: registry).stream == .video)

    let h264CodecRegistry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [98: .h264])
    let h264IDRPacket = RTPPacket(
        header: RTPPacketHeader(payloadType: 98, marker: true, sequenceNumber: 3, timestamp: 3_000, ssrc: 3),
        payload: Data([0x65, 0x88, 0x84])
    )
    #expect(try UltraGridCompatibility.decode(h264IDRPacket, registry: h264CodecRegistry).stream == .video)
}

@Test
func ultraGridStaticAndDynamicJPEGPayloadsDecodeAsVideo() throws {
    let payload = try UltraGridRTPJPEGPayload(
        header: UltraGridRTPJPEGHeader(
            fragmentOffset: 0,
            type: 1,
            quantization: 80,
            widthBlocks: 2,
            heightBlocks: 2
        ),
        scanPayload: Data([0x11, 0x22, 0x33, 0x44])
    ).encoded()
    let staticJPEG = RTPPacket(
        header: RTPPacketHeader(payloadType: 26, marker: true, sequenceNumber: 1, timestamp: 90_000, ssrc: 2),
        payload: payload
    )
    let dynamicJPEG = RTPPacket(
        header: RTPPacketHeader(payloadType: 98, marker: true, sequenceNumber: 2, timestamp: 90_000, ssrc: 2),
        payload: payload
    )
    let registry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [98: .jpeg])

    #expect(try UltraGridCompatibility.decode(staticJPEG).stream == .video)
    #expect(try UltraGridCompatibility.decode(dynamicJPEG, registry: registry).stream == .video)
}

@Test
func ultraGridJPEGPayloadValidationRejectsMalformedRTPJPEGPayloads() throws {
    let missingHeader = RTPPacket(
        header: RTPPacketHeader(payloadType: 26, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 0, 0, 0])
    )
    #expect(throws: UltraGridCompatibilityError.truncatedPayload(byteCount: 4)) {
        _ = try UltraGridCompatibility.decode(missingHeader)
    }

    let zeroWidth = Data([0, 0, 0, 0, 1, 80, 0, 2, 0x55])
    let invalidGeometry = RTPPacket(
        header: RTPPacketHeader(payloadType: 26, sequenceNumber: 2, timestamp: 1, ssrc: 1),
        payload: zeroWidth
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("jpeg.widthBlocks", 0)) {
        _ = try UltraGridCompatibility.decode(invalidGeometry)
    }

    let emptyScan = try UltraGridRTPJPEGHeader(
        fragmentOffset: 0,
        type: 1,
        quantization: 80,
        widthBlocks: 2,
        heightBlocks: 2
    ).encoded()
    let invalidScan = RTPPacket(
        header: RTPPacketHeader(payloadType: 26, sequenceNumber: 3, timestamp: 1, ssrc: 1),
        payload: emptyScan
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("jpeg.scanPayload", 0)) {
        _ = try UltraGridCompatibility.decode(invalidScan)
    }
}

@Test
func ultraGridDynamicH264PayloadsDecodeAsVideoForSupportedRFC6184PacketTypes() throws {
    let registry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [96: .h264])
    let singleNAL = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, marker: true, sequenceNumber: 1, timestamp: 90_000, ssrc: 2),
        payload: Data([0x65, 0x88, 0x84])
    )
    let stapA = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, marker: true, sequenceNumber: 2, timestamp: 90_000, ssrc: 2),
        payload: Data([0x78, 0x00, 0x02, 0x67, 0x42, 0x00, 0x02, 0x68, 0xce])
    )
    let fuAStart = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, marker: false, sequenceNumber: 3, timestamp: 90_000, ssrc: 2),
        payload: Data([0x7c, 0x85, 0x88, 0x84])
    )

    #expect(try UltraGridCompatibility.decode(singleNAL, registry: registry).stream == .video)
    #expect(try UltraGridCompatibility.decode(stapA, registry: registry).stream == .video)
    #expect(try UltraGridCompatibility.decode(fuAStart, registry: registry).stream == .video)
}

@Test
func ultraGridH264PayloadValidationRejectsMalformedRFC6184Payloads() throws {
    let registry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [96: .h264])
    let forbiddenBit = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0xe5, 0x00])
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("h264.forbiddenZeroBit", 1)) {
        _ = try UltraGridCompatibility.decode(forbiddenBit, registry: registry)
    }

    let unsupportedMTAP = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, sequenceNumber: 2, timestamp: 1, ssrc: 1),
        payload: Data([0x79, 0x00])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("h264-nal-unit-type-25")) {
        _ = try UltraGridCompatibility.decode(unsupportedMTAP, registry: registry)
    }

    let invalidFUA = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, sequenceNumber: 3, timestamp: 1, ssrc: 1),
        payload: Data([0x7c, 0xc5, 0x88])
    )
    #expect(throws: UltraGridCompatibilityError.invalidField("h264.fuA.startAndEnd", 1)) {
        _ = try UltraGridCompatibility.decode(invalidFUA, registry: registry)
    }
}

@Test
func ultraGridRunnerUsesConfiguredDynamicPayloadTypes() throws {
    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/ug-dynamic-pt.json",
            dryRun: true,
            mediaMode: .audioVideo,
            videoWidth: 2,
            videoHeight: 2,
            videoFrameRate: 30,
            videoBitsPerPixel: 8,
            mediaPacketCount: 1,
            ultraGridAudioPayloadType: 96,
            ultraGridVideoPayloadType: 97
        )
    )
    let registry = try UltraGridRTPPayloadRegistry(dynamicPayloads: [
        96: .pcmAudio,
        97: .rawVideo,
    ])

    try report.validate()
    #expect(report.datagrams.contains { $0.rtp.header.payloadType == 96 })
    #expect(report.datagrams.contains { $0.rtp.header.payloadType == 97 })
    for datagram in report.datagrams {
        _ = try UltraGridCompatibility.decode(datagram.rtp, registry: registry)
    }
}
