import Foundation
import Testing

@testable import OpenLolaCore


@Test
func lolaRawLinkTransmitRunnerWritesFramesAndRejectsMalformedMacs() throws {
    let sink = LoLaMemoryRawLinkTransmitter()
    let configuration = try LoLaRawLinkTransmitRunConfiguration.parse([
        "--interface", "en0",
        "--source-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--source-mac", "02:4c:6f:4c:61:00",
        "--destination-mac", "aa:bb:cc:dd:ee:ff",
        "--output", "/tmp/lola-raw-link.json",
        "--packets", "2",
        "--media", "audio-video",
        "--video-width", "16",
        "--video-height", "16",
        "--video-bpp", "8",
    ])

    let report = try LoLaRawLinkTransmitRunner.run(
        configuration: configuration,
        transmitter: sink
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedFrames.count == 6)
    #expect(try LoLaCompatibilityWireFrame.decode(sink.transmittedFrames[0]).destinationMAC.octets == [
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    ])
    #expect(report.notes.contains("memory sink"))

    #expect(throws: ExternalConnectorSessionError.socketFailed("invalid MAC bad-mac")) {
        _ = try LoLaRawLinkTransmitRunConfiguration.parse([
            "--interface", "en0",
            "--source-ip", "192.0.2.10",
            "--peer", "192.0.2.20",
            "--source-mac", "bad-mac",
            "--destination-mac", "aa:bb:cc:dd:ee:ff",
            "--output", "/tmp/lola-raw-link.json",
        ])
    }
}

@Test
func lolaRawLinkReceiveRunnerDecodesMemoryFramesAndReportsRealTimeouts() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-source.json",
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let encodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let configuration = try LoLaRawLinkReceiveRunConfiguration.parse([
        "--interface", "en0",
        "--local-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-raw-link-rx.json",
        "--frames", "3",
        "--media", "audio-video",
        "--timeout-seconds", "3",
    ])

    let report = try LoLaRawLinkReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaMemoryRawLinkReceiver(frames: encodedFrames)
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.envelopeValidatedFrameCount == 3)
    #expect(report.notes.contains("memory source"))
    #expect(configuration.timeoutSeconds == 3)
    #expect(report.notes.contains("timeout 3s"))

    let realTXConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-real-source.json",
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let realEncodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: realTXConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let realConfiguration = LoLaRawLinkReceiveRunConfiguration(
        interfaceName: "en0",
        localIP: "192.0.2.10",
        peerIP: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-real.json",
        dryRun: false,
        maxFrames: 3,
        mediaMode: .audioVideo,
        timeoutSeconds: 3
    )

    let realReport = try LoLaRawLinkReceiveRunner.run(
        configuration: realConfiguration,
        receiver: LoLaMemoryRawLinkReceiver(frames: realEncodedFrames)
    )

    try realReport.validate()
    #expect(realReport.realLinkTransmitted)

    let timeoutConfiguration = LoLaRawLinkReceiveRunConfiguration(
        interfaceName: "en0",
        localIP: "192.0.2.10",
        peerIP: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-timeout.json",
        dryRun: false,
        maxFrames: 2,
        mediaMode: .audioVideo,
        timeoutSeconds: 3
    )

    let timeoutReport = try LoLaRawLinkReceiveRunner.run(
        configuration: timeoutConfiguration,
        receiver: LoLaTimeoutRawLinkReceiver()
    )

    try timeoutReport.validate()
    #expect(timeoutReport.id == "lola-raw-link-rx-timeout-en0")
    #expect(timeoutReport.verdict == .fail)
    #expect(timeoutReport.runtimeError == "receiveTimedOut")
    #expect(timeoutReport.realLinkTransmitted)
    #expect(timeoutReport.localHost == "192.0.2.10")
    #expect(timeoutReport.peer == "192.0.2.20")
    #expect(timeoutReport.timeoutSeconds == 3)
    #expect(timeoutReport.expectedDatagramCount == 2)

    let receiver = LoLaBpfRawLinkReceiver(interfaceName: "en0", timeoutSeconds: 7)

    #expect(receiver.interfaceName == "en0")
    #expect(receiver.timeoutSeconds == 7)
}

@Test
func lolaBpfPacketExtractionSkipsMalformedRecordsAndHonorsLengthFields() throws {
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: 19788,
        destinationPort: 19788,
        payload: Data([0x55, 0x66, 0x77, 0x88])
    ).encoded()
    let batch = bpfTestRecord(capturedLength: 1, payload: Data([0xff]))
        + bpfTestRecord(capturedLength: frame.count, payload: frame)

    let packets = try extractBpfPackets(batch)

    #expect(packets == [frame])

    let record = bpfTestRecord(headerLength: 30, capturedLength: frame.count, payload: frame)

    #expect(try extractBpfPackets(record) == [frame])
}

@Test
func lolaUdpMediaBidirectionalRunnerSendsAndReceivesThroughUdpSockets() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-udp-media-tx-rx.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 3,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19788,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 1, payload: Data(repeating: 0x32, count: 64))[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 1, payload: Data(repeating: 0x32, count: 64))[1].payload
        ),
    ])

    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: sink,
        receiver: source
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.role == LoLaCompatibilityMediaSessionRole.txRx)
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedDatagrams.count == 3)
    #expect(report.notes.contains("TX-RX"))
}

@Test
func lolaUdpTransmitZeroBytesSentProducesFailWithStructuredByteCount() throws {
    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: lolaUdpTransmitTestConfiguration(dryRun: false),
        transmitter: LoLaZeroByteUdpMediaTransmitter()
    )

    try report.validate()
    #expect(report.sentBytesTotal == 0)
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "LoLa UDP media TX sent zero payload bytes")
    #expect(!report.notes.contains("0 payload bytes"))
}

@Test
func lolaUdpTransmitSuccessfulPartialRetainsPartialVerdictAndStructuredByteCount() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()

    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: lolaUdpTransmitTestConfiguration(dryRun: false),
        transmitter: sink
    )

    try report.validate()
    #expect(report.sentBytesTotal == sink.transmittedDatagrams.map(\.payload.count).reduce(0, +))
    #expect(report.sentBytesTotal ?? 0 > 0)
    #expect(report.verdict == .partial)
    #expect(report.runtimeError == nil)
    #expect(!report.notes.contains("payload bytes"))
}

private struct LoLaZeroByteUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String) throws -> [Int] {
        datagrams.map { _ in 0 }
    }
}

private func lolaUdpTransmitTestConfiguration(dryRun: Bool) -> LoLaUdpMediaTransmitRunConfiguration {
    LoLaUdpMediaTransmitRunConfiguration(
        localHost: "192.0.2.10",
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-udp-media-tx.json",
        dryRun: dryRun,
        packetCount: 1,
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
}
