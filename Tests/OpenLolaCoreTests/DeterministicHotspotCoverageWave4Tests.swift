// Covers pure media-routing and parsing branches with in-memory inputs only.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaMemoryUdpReceiverFiltersPeerPortsAndAppliesDatagramLimit() throws {
    let receiver = LoLaMemoryUdpMediaReceiver(datagrams: [
        .init(stream: .audio, port: 50_000, sourceHost: "192.0.2.20", sequenceNumber: 1, videoFrameRate: nil, payload: Data([1])),
        .init(stream: .video, port: 50_001, sourceHost: "192.0.2.20", sequenceNumber: 2, videoFrameRate: 30, payload: Data([2])),
        .init(stream: .audio, port: 50_000, sourceHost: "192.0.2.21", sequenceNumber: 3, videoFrameRate: nil, payload: Data([3])),
        .init(stream: .audio, port: 50_002, sourceHost: "192.0.2.20", sequenceNumber: 4, videoFrameRate: nil, payload: Data([4]))
    ])

    let received = try receiver.receive(
        maxDatagrams: 1,
        localHost: "192.0.2.10",
        peer: "192.0.2.20",
        audioPort: 50_000,
        videoPort: 50_001
    )

    #expect(received.map(\.sequenceNumber) == [1])
}

@Test
func directPeerVideoReassemblyDeltaClampsRegressionAndAccumulatesBothReportTargets() {
    let before = VideoReassemblyMetrics(
        framesReassembled: 10,
        framesDroppedIncomplete: 5,
        missingFragments: 6,
        lateFragments: 7,
        duplicateFragments: 8
    )
    let after = VideoReassemblyMetrics(
        framesReassembled: 11,
        framesDroppedIncomplete: 7,
        missingFragments: 9,
        lateFragments: 6,
        duplicateFragments: 12
    )
    let delta = directPeerVideoReassemblyMetricDelta(before: before, after: after)
    var drain = DirectPeerVideoRXDrainResult()
    var runtime = DirectPeerSessionAVRuntimeMetrics()

    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &drain)
    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &runtime)

    #expect(delta.framesDroppedIncomplete == 2)
    #expect(delta.missingFragments == 3)
    #expect(delta.lateFragments == 0)
    #expect(delta.duplicateFragments == 4)
    #expect(drain.framesDroppedDuringReassembly == 2)
    #expect(drain.reassemblyMissingFragments == 3)
    #expect(drain.reassemblyLateFragments == 0)
    #expect(drain.reassemblyDuplicateFragments == 4)
    #expect(runtime.videoFramesDroppedDuringReassembly == 2)
    #expect(runtime.videoReassemblyMissingFragments == 3)
    #expect(runtime.videoReassemblyLateFragments == 0)
    #expect(runtime.videoReassemblyDuplicateFragments == 4)
}

@Test
func externalConnectorParsingAcceptsAliasesAndRejectsInvalidBoundedPayloadType() throws {
    #expect(try parseExternalConnectorKind("mvtpUltraGrid") == .mvtpUltraGrid)
    #expect(try parseExternalConnectorMediaMode("av") == .audioVideo)
    #expect(try parseExternalConnectorSessionRole("full-duplex") == .txRx)
    #expect(try parseExternalConnectorControlTransport("tcp") == .tcp)
    #expect(try parseUltraGridTopologyMode("nat") == .serverClient)
    #expect(try parseUltraGridFECMode("xor") == .singleParity)
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("payload", "128")) {
        _ = try parseUltraGridRTPPayloadType("payload", ["payload": "128"])
    }
}

@Test
func lolaUdpTransmitRunnersUseMemoryTransmittersForDryRunAndSessionDefaults() throws {
    let datagram = LoLaUdpMediaDatagram(
        stream: .audio,
        port: 19_788,
        sourceHost: "192.0.2.10",
        sequenceNumber: 1,
        payload: Data([1, 2, 3])
    )
    let transmitter = LoLaMemoryUdpMediaTransmitter()

    #expect(try transmitter.transmit([datagram], localHost: "192.0.2.10", peer: "192.0.2.20") == [3])
    #expect(transmitter.transmittedDatagrams == [datagram])

    let runConfiguration = LoLaUdpMediaTransmitRunConfiguration(
        endpoint: .init(localHost: "192.0.2.10", peer: "192.0.2.20", outputPath: "/tmp/lola-dry-run.json"),
        execution: .init(dryRun: true, packetCount: 1),
        media: .init(mode: .audio, audio: .init(framesPerPacket: 1))
    )
    let configurationReport = try LoLaUdpMediaTransmitRunner.run(configuration: runConfiguration)
    try configurationReport.validate()
    #expect(!configurationReport.realLinkTransmitted)
    #expect(configurationReport.sentBytesTotal ?? 0 > 0)

    let sessionConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-session-default.json"
    ) { input in
        input.localHost = "0.0.0.0"
        input.dryRun = true
        input.mediaMode = .audio
        input.framesPerPacket = 1
        input.mediaPacketCount = 1
    })
    let sessionReport = try LoLaUdpMediaTransmitRunner.run(sessionConfiguration: sessionConfiguration)
    try sessionReport.validate()
    #expect(!sessionReport.realLinkTransmitted)
    #expect(sessionReport.sentBytesTotal ?? 0 > 0)
}

@Test
func lolaUdpReceiveFailureAndDryRunBidirectionalRunnerProduceBoundedReports() throws {
    let receiveConfiguration = LoLaUdpMediaReceiveRunConfiguration(
        endpoint: .init(localHost: "invalid-host", peer: "192.0.2.20", outputPath: "/tmp/lola-rx-failure.json"),
        execution: .init(dryRun: true, maxDatagrams: 1, timeoutSeconds: 1),
        mediaMode: .audio
    )
    let failure = try LoLaUdpMediaReceiveRunner.run(
        configuration: receiveConfiguration,
        receiver: LoLaMemoryUdpMediaReceiver(datagrams: [
            .init(stream: .audio, port: 19_788, sourceHost: "192.0.2.20", sequenceNumber: 1, payload: Data())
        ])
    )
    try failure.validate()
    #expect(failure.id == "lola-udp-media-rx-failure")
    #expect(failure.verdict == .fail)

    let bidirectionalConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-bidirectional-dry-run.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.dryRun = true
        input.mediaMode = .audio
        input.framesPerPacket = 1
        input.mediaPacketCount = 1
    })
    let report = try LoLaUdpMediaBidirectionalRunner.run(configuration: bidirectionalConfiguration)
    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
}
