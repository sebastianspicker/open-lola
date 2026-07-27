// Verifies that the LoLa raw-link transmitter writes frames and rejects malformed MAC addresses.
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
        "--video-bpp", "8"
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
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
    ])
    #expect(report.notes.contains("memory sink"))

    #expect(throws: ExternalConnectorSessionError.socketFailed("invalid MAC bad-mac")) {
        _ = try LoLaRawLinkTransmitRunConfiguration.parse([
            "--interface", "en0",
            "--source-ip", "192.0.2.10",
            "--peer", "192.0.2.20",
            "--source-mac", "bad-mac",
            "--destination-mac", "aa:bb:cc:dd:ee:ff",
            "--output", "/tmp/lola-raw-link.json"
        ])
    }
}

@Test
func lolaRawLinkTransmitsEachSequenceAsItIsBuilt() throws {
    let transmitter = LoLaStreamingRawLinkProbeTransmitter()
    let configuration = try LoLaRawLinkTransmitRunConfiguration.parse([
        "--interface", "en0",
        "--source-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--source-mac", "02:4c:6f:4c:61:00",
        "--destination-mac", "aa:bb:cc:dd:ee:ff",
        "--output", "/tmp/lola-raw-link-streaming.json",
        "--packets", "2",
        "--media", "audio",
    ])

    let report = try LoLaRawLinkTransmitRunner.run(
        configuration: configuration,
        transmitter: transmitter
    )

    #expect(!transmitter.batchTransmitCalled)
    #expect(transmitter.emittedSequences == [0, 1])
    #expect(report.audioFrameCount == 2)
}

@Test
func lolaRawLinkReceiveRunnerDecodesMemoryFramesAndReportsRealTimeouts() throws {
    let (configuration, report) = try lolaRawLinkMemoryReceiveReport()
    try assertLoLaRawLinkMemoryReceiveReport(report, configuration: configuration)

    let realReport = try lolaRawLinkRealMemoryReceiveReport()
    try realReport.validate()
    #expect(realReport.realLinkTransmitted)

    try assertLoLaRawLinkTimeoutReport(lolaRawLinkTimeoutReport())

    let receiver = LoLaBpfRawLinkReceiver(interfaceName: "en0", timeoutSeconds: 7)

    #expect(receiver.interfaceName == "en0")
    #expect(receiver.timeoutSeconds == 7)
}

@Test
func lolaBpfPacketExtractionSkipsMalformedRecordsAndHonorsLengthFields() throws {
    let frame = try testLoLaWireFrame(payload: Data([0x55, 0x66, 0x77, 0x88])).encoded()
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
    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: lolaUdpMediaBidirectionalTestConfiguration(),
        transmitter: sink,
        receiver: lolaUdpMediaBidirectionalTestReceiver()
    )

    try assertLoLaUdpMediaBidirectionalReport(report, sink: sink)
}

@Test
func lolaUdpTransmitZeroBytesSentProducesFailWithStructuredByteCount() throws {
    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: lolaUdpTransmitTestConfiguration(dryRun: false),
        transmitter: LoLaZeroByteUdpMediaTransmitter()
    )

    try report.validate()
    #expect(report.sentBytesTotal == 0)
    #expect(!report.realLinkTransmitted)
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
    #expect(!report.realLinkTransmitted)
    #expect(report.verdict == .partial)
    #expect(report.runtimeError == nil)
    #expect(!report.notes.contains("payload bytes"))
}

private func lolaRawLinkMemoryReceiveReport()
    throws -> (LoLaRawLinkReceiveRunConfiguration, LoLaCompatibilityMediaSessionReport) {
    let configuration = try LoLaRawLinkReceiveRunConfiguration.parse([
        "--interface", "en0",
        "--local-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-raw-link-rx.json",
        "--frames", "3",
        "--media", "audio-video",
        "--timeout-seconds", "3"
    ])
    let report = try LoLaRawLinkReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaMemoryRawLinkReceiver(frames: try lolaRawLinkEncodedFrames(
            outputPath: "/tmp/lola-raw-link-rx-source.json"
        ))
    )
    return (configuration, report)
}

private func lolaRawLinkRealMemoryReceiveReport() throws -> LoLaCompatibilityMediaSessionReport {
    try LoLaRawLinkReceiveRunner.run(
        configuration: LoLaRawLinkReceiveRunConfiguration(
            interfaceName: "en0",
            localIP: "192.0.2.10",
            peerIP: "192.0.2.20",
            outputPath: "/tmp/lola-raw-link-rx-real.json",
            dryRun: false,
            maxFrames: 3,
            mediaMode: .audioVideo,
            timeoutSeconds: 3
        ),
        receiver: LoLaMemoryRawLinkReceiver(frames: try lolaRawLinkEncodedFrames(
            outputPath: "/tmp/lola-raw-link-rx-real-source.json"
        ))
    )
}

private func lolaRawLinkTimeoutReport() throws -> LoLaCompatibilityMediaSessionReport {
    try LoLaRawLinkReceiveRunner.run(
        configuration: LoLaRawLinkReceiveRunConfiguration(
            interfaceName: "en0",
            localIP: "192.0.2.10",
            peerIP: "192.0.2.20",
            outputPath: "/tmp/lola-raw-link-rx-timeout.json",
            dryRun: false,
            maxFrames: 2,
            mediaMode: .audioVideo,
            timeoutSeconds: 3
        ),
        receiver: LoLaTimeoutRawLinkReceiver()
    )
}

private func lolaRawLinkEncodedFrames(outputPath: String) throws -> [Data] {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.10",
  outputPath: outputPath
) { input in
  input.localHost = "192.0.2.20"
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
})
    return try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: configuration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
}

private func assertLoLaRawLinkMemoryReceiveReport(
    _ report: LoLaCompatibilityMediaSessionReport,
    configuration: LoLaRawLinkReceiveRunConfiguration
) throws {
    try report.validate()
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.envelopeValidatedFrameCount == 3)
    #expect(report.notes.contains("memory source"))
    #expect(configuration.timeoutSeconds == 3)
    #expect(report.notes.contains("timeout 3s"))
}

private func assertLoLaRawLinkTimeoutReport(_ report: LoLaCompatibilityMediaSessionReport) throws {
    try report.validate()
    #expect(report.id == "lola-raw-link-rx-timeout-en0")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(!report.realLinkTransmitted)
    #expect(report.localHost == "192.0.2.10")
    #expect(report.peer == "192.0.2.20")
    #expect(report.timeoutSeconds == 3)
    #expect(report.expectedDatagramCount == 2)
}

private func lolaUdpMediaBidirectionalTestConfiguration() -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-udp-media-tx-rx.json"
) { input in
  input.localHost = "192.0.2.10"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 3
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
  input.mediaPacketCount = 1
})
}

private func lolaUdpMediaBidirectionalTestReceiver() throws -> LoLaMemoryUdpMediaReceiver {
    let videoPackets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 1,
        payload: Data(repeating: 0x32, count: 64)
    )
    return LoLaMemoryUdpMediaReceiver(datagrams: [
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
            payload: videoPackets[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: videoPackets[1].payload
        )
    ])
}

private func assertLoLaUdpMediaBidirectionalReport(
    _ report: LoLaCompatibilityMediaSessionReport,
    sink: LoLaMemoryUdpMediaTransmitter
) throws {
    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.role == LoLaCompatibilityMediaSessionRole.txRx)
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedDatagrams.count == 3)
    #expect(report.notes.contains("TX-RX"))
}

private struct LoLaZeroByteUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String) throws -> [Int] {
        datagrams.map { _ in 0 }
    }
}

private final class LoLaStreamingRawLinkProbeTransmitter: LoLaRawLinkTransmitter {
    private(set) var batchTransmitCalled = false
    private(set) var emittedSequences: [Int] = []

    func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        batchTransmitCalled = true
        return frames.map(\.wireByteCount)
    }

    func transmitGenerated(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> [Int] {
        var byteCounts: [Int] = []
        try generate { frame in
            emittedSequences.append(frame.sequenceNumber)
            byteCounts.append(frame.wireByteCount)
        }
        return byteCounts
    }
}

private func lolaUdpTransmitTestConfiguration(dryRun: Bool) -> LoLaUdpMediaTransmitRunConfiguration {
    LoLaUdpMediaTransmitRunConfiguration(
        endpoint: .init(
            localHost: "192.0.2.10",
            peer: "192.0.2.20",
            outputPath: "/tmp/lola-udp-media-tx.json"
        ),
        execution: .init(dryRun: dryRun, packetCount: 1),
        media: .init(video: .init(width: 16, height: 16, bitsPerPixel: 8))
    )
}
