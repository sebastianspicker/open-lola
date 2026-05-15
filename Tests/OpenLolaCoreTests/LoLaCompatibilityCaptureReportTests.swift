import Foundation
import Testing
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@testable import OpenLolaCore

@Test
func lolaCaptureDecoderReadsClassicPcapMediaEnvelopeWithoutPromotingPass() throws {
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 3, channels: 2)[0].payload
    let frame = try makeLoLaFrame(port: 19788, payload: payload)
    let capture = classicPcap(packet: frame)

    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: capture,
        inputPath: "/tmp/lola-audio.pcap",
        capturedAt: "2026-05-05T00:00:00Z"
    )

    try report.validate()
    #expect(report.inputFormat == .classicPcap)
    #expect(report.verdict == .partial)
    #expect(report.summary.packetCount == 1)
    #expect(report.summary.audioPacketCount == 1)
    #expect(report.summary.lolaMediaEnvelopePacketCount == 1)
    #expect(report.packets[0].stream == .audio)
    #expect(report.packets[0].sourcePort == 19788)
    #expect(report.packets[0].destinationPort == 19788)
    #expect(report.packets[0].mediaEnvelopeValid)
    #expect(report.packets[0].mediaPayloadCandidate == .audioFragment)
    #expect(report.packets[0].packetKind == .audioFragment)
    #expect(report.packets[0].frameID == 4)
    #expect(report.packets[0].fragmentIndex == 0)
    #expect(report.packets[0].fragmentCount == 1)
    #expect(report.packets[0].finalFragment == true)
    #expect(report.evidenceBoundary.contains("Source-level clean-room LoLa media grammar"))
}

@Test
func lolaCaptureDecoderClassifiesMediaPayloadCandidatesWithoutPromotingPass() throws {
    let videoFragment = try makeLoLaFrame(
        port: 19798,
        payload: LoLaCompatibilityMediaCodec.videoPackets(
            sequenceNumber: 5,
            payload: Data(repeating: 0x33, count: 64)
        )[1].payload
    )
    let mjpeg = try makeLoLaFrame(
        port: 19798,
        payload: LoLaCompatibilityMediaCodec.videoPackets(
            sequenceNumber: 6,
            payload: Data([0xff, 0xd8, 0x11, 0x22, 0xff, 0xd9])
        )[1].payload
    )
    let unknown = try makeLoLaFrame(port: 19798, payload: Data([0x10, 0x20, 0x30]))
    let prelude = try makeLoLaFrame(
        port: 19798,
        payload: LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 7, payload: Data(repeating: 0x44, count: 8))[0].payload
    )
    let capture = classicPcap(packets: [videoFragment, mjpeg, prelude, unknown])

    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: capture,
        inputPath: "/tmp/lola-video-codecs.pcap",
        capturedAt: "2026-05-05T00:00:00Z"
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.packets.map(\.mediaPayloadCandidate) == [.videoFragment, .videoFragment, .videoPrelude, .malformedFragment])
    #expect(report.packets[1].packetKind == .videoFragment)
    #expect(report.packets[1].frameID == 6)
    #expect(report.packets[1].fragmentIndex == 0)
    #expect(report.packets[1].fragmentCount == 1)
    #expect(report.packets[1].finalFragment == true)
    #expect(report.packets.allSatisfy { $0.mediaEnvelopeValid })
    #expect(report.notes.contains("cannot promote"))
}

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@Test
func lolaCaptureDecoderClassifiesInjectedJpegFragmentAsMjpeg() throws {
    let context = try #require(CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let jpeg = try LoLaMjpegJPEGEncoder.jpegData(from: try #require(context.makeImage()))
    let payload = try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 8, payload: jpeg)[1].payload
    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: classicPcap(packet: try makeLoLaFrame(port: 19798, payload: payload)),
        inputPath: "/tmp/lola-injected-jpeg.pcap",
        capturedAt: "2026-05-07T00:00:00Z"
    )

    try report.validate()
    #expect(report.packets[0].mediaPayloadCandidate == .mjpeg)
    #expect(report.packets[0].packetKind == .videoFragment)
    #expect(report.packets[0].frameID == 8)
}
#endif

@Test
func lolaCaptureDecoderReadsPcapngControlMessageName() throws {
    let message = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 1
    )
    let frame = try makeLoLaFrame(port: 7000, payload: Data(message.utf8))
    let capture = pcapng(packet: frame)

    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: capture,
        inputPath: "/tmp/lola-control.pcapng",
        capturedAt: "2026-05-05T00:00:00Z"
    )

    try report.validate()
    #expect(report.inputFormat == .pcapng)
    #expect(report.verdict == .partial)
    #expect(report.summary.controlPacketCount == 1)
    #expect(report.summary.lolaMediaEnvelopePacketCount == 0)
    #expect(report.packets[0].stream == .control)
    #expect(report.packets[0].controlMessageName == "/MESG_CHECKLOLASTATUS")
}

@Test
func lolaCaptureDecoderReadsPaddedLiveControlMessageName() throws {
    let message = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: "192.168.178.47",
        destinationIP: "192.168.178.46",
        sessionID: 0,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        videoWidth: 640,
        videoHeight: 480,
        videoBayer: 1
    )
    var paddedPayload = Data(message.utf8)
    paddedPayload.append(0)
    paddedPayload.append(Data(repeating: 0xa3, count: 1_024 - paddedPayload.count))
    let frame = try makeLoLaFrame(port: 7000, payload: paddedPayload)
    let capture = classicPcap(packet: frame)

    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: capture,
        inputPath: "/tmp/lola-live-padded-control.pcap",
        capturedAt: "2026-05-06T15:14:15Z"
    )

    try report.validate()
    #expect(report.summary.controlPacketCount == 1)
    #expect(report.packets[0].payloadLength == 1_024)
    #expect(report.packets[0].controlMessageName == "/MESG_QUICKCONN")
    #expect(report.packets[0].notes.isEmpty)
}

@Test
func lolaCaptureDecoderReportsEmptyCaptureAsFailCleanly() throws {
    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: classicPcap(packet: nil),
        inputPath: "/tmp/empty-lola.pcap",
        capturedAt: "2026-05-05T00:00:00Z"
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.summary.packetCount == 0)
    #expect(report.summary.malformedPacketCount == 0)
}

@Test
func lolaCaptureDecoderRejectsOversizedInputsAndPacketCounts() throws {
    let oversized = Data(repeating: 0, count: LoLaCompatibilityCaptureDecoder.maxInputByteCount + 1)
    #expect(throws: LoLaCompatibilityCaptureDecodeError.inputTooLarge(
        LoLaCompatibilityCaptureDecoder.maxInputByteCount + 1
    )) {
        _ = try LoLaCompatibilityCaptureDecoder.decode(
            data: oversized,
            inputPath: "/tmp/oversized.pcap",
            capturedAt: "2026-05-08T00:00:00Z"
        )
    }

    var tooManyPackets: [Data] = []
    for _ in 0...LoLaCompatibilityCaptureDecoder.maxPacketCount {
        tooManyPackets.append(Data([0]))
    }
    #expect(throws: LoLaCompatibilityCaptureDecodeError.packetCountTooLarge(
        LoLaCompatibilityCaptureDecoder.maxPacketCount + 1
    )) {
        _ = try LoLaCompatibilityCaptureDecoder.decode(
            data: classicPcap(packets: tooManyPackets),
            inputPath: "/tmp/too-many-packets.pcap",
            capturedAt: "2026-05-08T00:00:00Z"
        )
    }
}

@Test
func lolaCaptureDecoderRejectsMarkerDensePayloadsWithoutQuadraticScan() throws {
    let payload = Data(repeating: 0xff, count: LoLaCompatibilityCaptureDecoder.maxJpegScanByteCount + 1)

    #expect(throws: LoLaCompatibilityCaptureDecodeError.payloadTooLarge(payload.count)) {
        _ = try LoLaCompatibilityCaptureDecoder.decode(
            data: classicPcap(packet: try makeLoLaFrame(port: 19798, payload: payload)),
            inputPath: "/tmp/marker-dense.pcap",
            capturedAt: "2026-05-08T00:00:00Z"
        )
    }
}

@Test
func lolaCaptureReportRejectsPassVerdict() throws {
    let report = LoLaCompatibilityCaptureReport(
        id: "invalid-pass",
        title: "Invalid pass",
        capturedAt: "2026-05-05T00:00:00Z",
        inputPath: "/tmp/pass.pcap",
        inputFormat: .classicPcap,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .pass,
        evidenceBoundary: "Boundary",
        notes: "Notes"
    )

    #expect(throws: LoLaCompatibilityCaptureValidationError.passNotAllowed) {
        try report.validate()
    }
}

private func makeLoLaFrame(port: UInt16, payload: Data) throws -> Data {
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: port,
        destinationPort: port,
        payload: payload
    )
    return try frame.encoded()
}

private func classicPcap(packet: Data?) -> Data {
    classicPcap(packets: packet.map { [$0] } ?? [])
}

private func classicPcap(packets: [Data]) -> Data {
    var data = Data([0xd4, 0xc3, 0xb2, 0xa1])
    appendLE16(2, to: &data)
    appendLE16(4, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(65_535, to: &data)
    appendLE32(1, to: &data)
    for packet in packets {
        appendLE32(0, to: &data)
        appendLE32(0, to: &data)
        appendLE32(UInt32(packet.count), to: &data)
        appendLE32(UInt32(packet.count), to: &data)
        data.append(packet)
    }
    return data
}

private func pcapng(packet: Data) -> Data {
    var data = Data()
    data.append(pcapngBlock(type: 0x0a0d0d0a, payload: sectionHeaderPayload()))
    data.append(pcapngBlock(type: 0x0000_0001, payload: interfaceDescriptionPayload()))
    data.append(pcapngBlock(type: 0x0000_0006, payload: enhancedPacketPayload(packet)))
    return data
}

private func sectionHeaderPayload() -> Data {
    var data = Data()
    appendLE32(0x1a2b_3c4d, to: &data)
    appendLE16(1, to: &data)
    appendLE16(0, to: &data)
    appendLE64(UInt64.max, to: &data)
    return data
}

private func interfaceDescriptionPayload() -> Data {
    var data = Data()
    appendLE16(1, to: &data)
    appendLE16(0, to: &data)
    appendLE32(65_535, to: &data)
    return data
}

private func enhancedPacketPayload(_ packet: Data) -> Data {
    var data = Data()
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(UInt32(packet.count), to: &data)
    appendLE32(UInt32(packet.count), to: &data)
    data.append(packet)
    while data.count % 4 != 0 {
        data.append(0)
    }
    return data
}

private func pcapngBlock(type: UInt32, payload: Data) -> Data {
    var data = Data()
    let length = UInt32(12 + payload.count)
    appendLE32(type, to: &data)
    appendLE32(length, to: &data)
    data.append(payload)
    appendLE32(length, to: &data)
    return data
}

private func appendLE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8(value >> 8))
}

private func appendLE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}

private func appendLE64(_ value: UInt64, to data: inout Data) {
    appendLE32(UInt32(value & 0xffff_ffff), to: &data)
    appendLE32(UInt32(value >> 32), to: &data)
}
