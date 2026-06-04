import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridFecPayloadType22RoundTripsSingleParityEnvelope() throws {
    let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        framePayload: Data((0..<128).map { UInt8($0) }),
        frameID: 7,
        sequenceStart: 10,
        timestamp: 3_000,
        ssrc: 0x4F4C_5556,
        width: 16,
        height: 8,
        frameRate: 30,
        bitsPerPixel: 8,
        maxPayloadBytes: 64
    ))
    let fec = try UltraGridCompatibility.fecParityPacket(
        protecting: packets,
        sequenceNumber: 10 + UInt16(packets.count),
        timestamp: 3_000,
        ssrc: 0x4F4C_5556
    )
    let payload = try UltraGridFECPayload.decode(fec.payload)

    #expect(fec.header.payloadType == UltraGridCompatibility.fecPayloadType)
    #expect(payload.header.bufferNumber == 7)
    #expect(payload.header.payloadOffset == 10)
    #expect(payload.header.payloadByteCount == UInt32(packets.count))
    #expect(payload.header.k == UInt16(packets.count))
    #expect(payload.header.m == 1)
    #expect(payload.header.c == 2)
    #expect(payload.header.seed == 1)
    #expect(try UltraGridCompatibility.decode(fec).stream == .video)
}

@Test
func ultraGridSingleParityFecRecoversOneMissingVideoFragment() throws {
    let frame = Data((0..<256).map { UInt8($0 & 0xff) })
    let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        framePayload: frame,
        frameID: 8,
        sequenceStart: 20,
        timestamp: 6_000,
        ssrc: 0x4F4C_5556,
        width: 16,
        height: 16,
        frameRate: 30,
        bitsPerPixel: 8,
        maxPayloadBytes: 88
    ))
    let fec = try UltraGridCompatibility.fecParityPacket(
        protecting: packets,
        sequenceNumber: 20 + UInt16(packets.count),
        timestamp: 6_000,
        ssrc: 0x4F4C_5556
    )
    let received = packets.enumerated().compactMap { index, packet in
        index == 1 ? nil : packet
    } + [fec]
    let recovered = try UltraGridCompatibility.recoverVideoFragments(from: received)

    #expect(try UltraGridCompatibility.reassembleVideoFrame(recovered) == frame)
}

@Test
func ultraGridRunnerAddsFecAndSinkUsesItForLossRecovery() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/ug-fec.json",
        dryRun: false,
        mediaMode: .video,
        videoWidth: 16,
        videoHeight: 16,
        videoFrameRate: 30,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1,
        ultraGridFECMode: .singleParity
    )
    let generated = try UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration)
    let received = generated.enumerated().compactMap { index, datagram in
        datagram.rtp.header.payloadType == UltraGridCompatibility.videoPayloadType && index == 1 ? nil : datagram
    }.map {
        UltraGridCompatibilityDatagram(
            stream: $0.stream,
            sourceHost: "127.0.0.1",
            sourcePort: 40_000,
            destinationPort: $0.destinationPort,
            rtp: $0.rtp
        )
    }
    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: received)
    )

    try report.validate()
    #expect(generated.contains { $0.rtp.header.payloadType == UltraGridCompatibility.fecPayloadType })
    #expect(report.sink.videoFrameCount == 1)
    #expect(report.sink.videoPayloadByteCount == 256)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(!report.unsupportedModes.contains("fec"))
}
