// Covers deterministic LoLa UDP media runner reports through injected in-memory seams.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave19UdpMemoryReceiverKeepsAudioVideoAndRejectsMismatchedPeerAndPort() throws {
    let receiver = LoLaMemoryUdpMediaReceiver(datagrams: [
        .init(stream: .audio, port: 19_788, sourceHost: "192.0.2.19", sequenceNumber: 1, payload: Data([1])),
        .init(stream: .video, port: 19_798, sourceHost: "192.0.2.19", sequenceNumber: 2, videoFrameRate: 30, payload: Data([2])),
        .init(stream: .audio, port: 19_788, sourceHost: "192.0.2.99", sequenceNumber: 3, payload: Data([3])),
        .init(stream: .video, port: 19_799, sourceHost: "192.0.2.19", sequenceNumber: 4, videoFrameRate: 30, payload: Data([4]))
    ])

    let datagrams = try receiver.receive(
        maxDatagrams: 4,
        localHost: "192.0.2.10",
        peer: "192.0.2.19",
        audioPort: 19_788,
        videoPort: 19_798
    )

    #expect(datagrams.map(\.stream) == [.audio, .video])
    #expect(datagrams.map(\.sequenceNumber) == [1, 2])
    #expect(datagrams.map(\.videoFrameRate) == [nil, 30])
}

@Test
func wave19UdpTransmitReportUsesInjectedOutcomeTotalsAndDropDescription() throws {
    let transmitter = Wave19UdpOutcomeTransmitter()
    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: wave19UdpTransmitConfiguration(),
        transmitter: transmitter
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx")
    #expect(report.role == .tx)
    #expect(report.realLinkTransmitted)
    #expect(report.sentBytesTotal == 41)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.notes.contains("sent 3 datagram(s)"))
    #expect(report.notes.contains("dropped 2 audio packet(s) and 1 video frame(s)"))
    #expect(report.notes.contains("deadline abandoned 3 audio packet(s) and 4 video frame(s)"))
    #expect(transmitter.datagrams.map(\.stream) == [.audio, .video, .video])
}

@Test
func wave19UdpReceiveReportDecodesInjectedAudioAndVideoWithTotalsAndDescription() throws {
    let configuration = wave19UdpReceiveConfiguration()
    let report = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaMemoryUdpMediaReceiver(datagrams: try wave19UdpValidDatagrams())
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-rx")
    #expect(report.role == .rx)
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.envelopeValidatedFrameCount == 3)
    #expect(report.expectedDatagramCount == nil)
    #expect(report.notes.contains("decoded 3 payload datagrams from UDP sockets"))
    #expect(report.notes.contains("timeout 7s"))
}

@Test
func wave19UdpReceiveRunnerReportsInjectedTimeoutAndFailure() throws {
    let configuration = wave19UdpReceiveConfiguration()
    let timeout = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: Wave19UdpTimeoutReceiver()
    )
    let failure = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: Wave19UdpThrowingReceiver()
    )

    try timeout.validate()
    #expect(timeout.id == "lola-udp-media-rx-timeout")
    #expect(timeout.verdict == .fail)
    #expect(timeout.runtimeError == "receiveTimedOut")
    #expect(timeout.expectedDatagramCount == 3)
    #expect(timeout.notes.contains("received no media datagrams before timeout 7s"))

    try failure.validate()
    #expect(failure.id == "lola-udp-media-rx-failure")
    #expect(failure.verdict == .fail)
    #expect(failure.runtimeError == "socketFailed(\"wave19 injected receive failure\")")
    #expect(!failure.realLinkTransmitted)
    #expect(failure.notes.contains("after unknown datagram(s)"))
}

@Test
func wave19UdpBidirectionalReportCombinesInjectedTransmitAndReceiveEvidence() throws {
    let transmitter = Wave19UdpOutcomeTransmitter()
    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: wave19UdpBidirectionalConfiguration(),
        transmitter: transmitter,
        receiver: LoLaMemoryUdpMediaReceiver(datagrams: try wave19UdpValidDatagrams())
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.role == .txRx)
    #expect(report.verdict == .partial)
    #expect(report.realLinkTransmitted)
    #expect(report.sentBytesTotal == 41)
    #expect(report.expectedDatagramCount == 3)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(report.notes.contains("sent 3 media frame(s) and decoded 3 received media frame(s)"))
}

private final class Wave19UdpOutcomeTransmitter: LoLaUdpMediaTransmitter {
    private(set) var datagrams: [LoLaUdpMediaDatagram] = []

    var usesRealLink: Bool { true }

    func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String) throws -> [Int] {
        self.datagrams.append(contentsOf: datagrams)
        return [11, 13, 17]
    }

    func transmitResult(
        _ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String
    ) throws -> LoLaUdpMediaTransmitOutcome {
        self.datagrams.append(contentsOf: datagrams)
        return .init(
            sentByteCounts: [11, 13, 17],
            droppedAudioPackets: 2,
            droppedVideoFrames: 1,
            deadlineAbandonedAudioPackets: 3,
            deadlineAbandonedVideoFrames: 4
        )
    }
}

private struct Wave19UdpTimeoutReceiver: LoLaUdpMediaReceiver {
    func receive(
        maxDatagrams _: Int,
        localHost _: String,
        peer _: String,
        audioPort _: UInt16,
        videoPort _: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        throw ExternalConnectorSessionError.receiveTimedOut
    }
}

private struct Wave19UdpThrowingReceiver: LoLaUdpMediaReceiver {
    func receive(
        maxDatagrams _: Int,
        localHost _: String,
        peer _: String,
        audioPort _: UInt16,
        videoPort _: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        throw ExternalConnectorSessionError.socketFailed("wave19 injected receive failure")
    }
}

private func wave19UdpTransmitConfiguration() -> LoLaUdpMediaTransmitRunConfiguration {
    .init(
        endpoint: .init(localHost: "192.0.2.10", peer: "192.0.2.19", outputPath: "/tmp/wave19-udp-tx.json"),
        execution: .init(dryRun: false, packetCount: 1),
        media: .init(mode: .audioVideo, video: .init(width: 16, height: 16, bitsPerPixel: 8))
    )
}

private func wave19UdpReceiveConfiguration() -> LoLaUdpMediaReceiveRunConfiguration {
    .init(
        endpoint: .init(localHost: "192.0.2.10", peer: "192.0.2.19", outputPath: "/tmp/wave19-udp-rx.json"),
        execution: .init(dryRun: false, maxDatagrams: 3, timeoutSeconds: 7),
        mediaMode: .audioVideo,
        video: .init(width: 16, height: 16, bitsPerPixel: 8)
    )
}

private func wave19UdpBidirectionalConfiguration() -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.19",
        outputPath: "/tmp/wave19-udp-tx-rx.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.dryRun = false
        input.mediaMode = .audioVideo
        input.mediaPacketCount = 1
        input.durationSeconds = 7
        input.videoWidth = 16
        input.videoHeight = 16
        input.videoBitsPerPixel = 8
    })
}

private func wave19UdpValidDatagrams() throws -> [LoLaUdpMediaDatagram] {
    let audio = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
    let video = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 1,
        payload: Data(repeating: 0x19, count: 64)
    ).map(\.payload)
    return [
        .init(stream: .audio, port: 19_788, sourceHost: "192.0.2.19", sequenceNumber: 1, payload: audio)
    ] + video.map {
        .init(stream: .video, port: 19_798, sourceHost: "192.0.2.19", sequenceNumber: 1, videoFrameRate: 30, payload: $0)
    }
}
