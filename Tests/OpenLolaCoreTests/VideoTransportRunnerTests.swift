import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoTransportRunnerRejectsUserInteractiveQoS() {
    #expect(!videoTransportRunnerAllowsQoS(QOS_CLASS_USER_INTERACTIVE))
    #expect(videoTransportRunnerAllowsQoS(QOS_CLASS_USER_INITIATED))
    #expect(videoTransportRunnerAllowsQoS(QOS_CLASS_DEFAULT))
}

@Test
func videoTransportDrainUsesReassemblySignalAndGeneratedFrameNaming() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportRunner.swift")

    #expect(source.contains("DispatchSemaphore"))
    #expect(source.contains("reassemblySignal.signal()"))
    #expect(source.contains("totalGeneratedFrames"))
    #expect(!source.contains("expectedFrames"))
    #expect(!source.contains("usleep(1_000)"))
}

@Test
func videoTransportRunnerWarnsWhenDatagramFillsReceiveBufferBeforeDecode() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportRunner.swift")

    #expect(source.contains("receiveVideoDatagramIfAvailable"))
    #expect(source.contains("MSG_PEEK | MSG_TRUNC"))
    #expect(source.contains("peekedByteCount > configuration.maxPacketBytes"))
    #expect(source.contains("warning: video transport UDP datagram reached configured maxPacketBytes"))
    #expect(source.range(of: "receiveVideoDatagramIfAvailable")?.lowerBound ?? source.endIndex
        < source.range(of: "VideoTransportFragment.decode")?.lowerBound ?? source.startIndex)
}

@Test
func videoTransportSyntheticSmokeEmitsPartialReport() throws {
    let report = try VideoTransportSyntheticSmoke.run()

    try report.validate()

    #expect(report.transport.mode == .raw)
    #expect(report.receiver.queuePolicy == .latestFrame)
    #expect(report.verdict == .partial)
}

@Test
func videoTransportRunConfigurationParsesRawRouteArguments() throws {
    let configuration = try VideoTransportRunConfiguration.parse([
        "--mode", "raw",
        "--stream-id", "200",
        "--stream-count", "2",
        "--visible-streams", "2",
        "--source-role", "blackmagicInput",
        "--peer", "127.0.0.1",
        "--port", "5004",
        "--duration-seconds", "1",
        "--width", "320",
        "--height", "240",
        "--pixel-format", "bgra8",
        "--frame-rate", "10",
        "--queue-depth", "1",
        "--max-packet-bytes", "1200",
        "--route-kind", "localhost",
        "--packet-capture-point", "local-loopback",
        "--output", "reports/m09-video-transport-run.json",
    ])

    #expect(configuration.mode == .raw)
    #expect(configuration.streamID == 200)
    #expect(configuration.streamCount == 2)
    #expect(configuration.visibleStreamCount == 2)
    #expect(configuration.sourceRole == .blackmagicInput)
    #expect(configuration.peer == "127.0.0.1")
    #expect(configuration.port == 5_004)
    #expect(configuration.durationSeconds == 1)
    #expect(configuration.width == 320)
    #expect(configuration.height == 240)
    #expect(configuration.pixelFormat == "bgra8")
    #expect(configuration.frameRate == 10)
    #expect(configuration.queueDepth == 1)
    #expect(configuration.maxPacketBytes == 1_200)
    #expect(configuration.routeKind == .localhost)
    #expect(configuration.packetCapturePoint == "local-loopback")
    #expect(configuration.outputPath == "reports/m09-video-transport-run.json")
}

@Test
func videoTransportRunConfigurationRejectsTooManyStagedStreams() {
    #expect(throws: VideoTransportRunConfigurationError.tooManyStreams(
        requested: 5,
        maximum: VideoTransportRunConfiguration.maximumStreamCount
    )) {
        _ = try VideoTransportRunConfiguration.parse([
            "--mode", "raw",
            "--stream-count", "5",
            "--peer", "127.0.0.1",
            "--port", "5004",
            "--duration-seconds", "1",
            "--output", "reports/m09-video-transport-run.json",
        ])
    }
}

@Test
func videoTransportRunConfigurationRejectsVisibleStreamsBeyondStagedStreams() {
    #expect(throws: VideoTransportRunConfigurationError.visibleStreamsExceedStreamCount(
        visible: 3,
        streamCount: 2
    )) {
        _ = try VideoTransportRunConfiguration.parse([
            "--mode", "raw",
            "--stream-count", "2",
            "--visible-streams", "3",
            "--peer", "127.0.0.1",
            "--port", "5004",
            "--duration-seconds", "1",
            "--output", "reports/m09-video-transport-run.json",
        ])
    }
}

@Test
func videoTransportRunConfigurationRejectsVideoToolboxMode() {
    #expect(throws: VideoTransportRunConfigurationError.unsupportedMode("videoToolboxH264")) {
        _ = try VideoTransportRunConfiguration.parse([
            "--mode", "videoToolboxH264",
            "--peer", "127.0.0.1",
            "--port", "5004",
            "--duration-seconds", "1",
            "--output", "reports/m09-video-transport-run.json",
        ])
    }
}

@Test
func videoTransportRunBuildsPartialRawLatestFrameReport() throws {
    let configuration = VideoTransportRunConfiguration(
        mode: .raw,
        peer: "127.0.0.1",
        port: 5_004,
        durationSeconds: 1,
        outputPath: "reports/m09-video-transport-run.json",
        width: 320,
        height: 240,
        frameRate: 10,
        queueDepth: 1,
        maxPacketBytes: 1_200,
        routeKind: .localhost,
        packetCapturePoint: "local-loopback"
    )

    let report = try VideoTransportRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.id == "m09-video-transport-run")
    #expect(report.transport.mode == .raw)
    #expect(report.routeEvidence?.routeKind == .localhost)
    #expect(report.routeEvidence?.packetCapturePoint == "local-loopback")
    #expect(report.transmitted.framesSent == 10)
    #expect(report.receiver.receivedFrames == 10)
    #expect(report.receiver.displayedFrames == 1)
    #expect(report.receiver.droppedFrames == 9)
    #expect(report.fragmentation?.framesFragmented == 10)
    #expect(report.fragmentation?.fragmentsSent == 2_130)
    #expect(report.fragmentation?.maxPayloadBytesPerFragment == 1_082)
    #expect(report.reassembly?.framesReassembled == 10)
    #expect(report.transmitted.packetsSent == 2_130)
    #expect(report.receiver.queuePolicy == .latestFrame)
    #expect(report.verdict == .partial)
}

@Test
func videoTransportRunBuildsPartialStagedMultiVideoReport() throws {
    let configuration = VideoTransportRunConfiguration(
        mode: .raw,
        streamID: 300,
        streamCount: 2,
        visibleStreamCount: 2,
        peer: "127.0.0.1",
        port: 5_014,
        durationSeconds: 1,
        outputPath: "reports/m09-multi-video-transport-run.json",
        width: 64,
        height: 36,
        frameRate: 2,
        queueDepth: 1,
        maxPacketBytes: 1_200,
        routeKind: .localhost,
        packetCapturePoint: "local-loopback"
    )

    let report = try VideoTransportRunner.run(configuration: configuration)

    try report.validate()

    let multiVideo = try #require(report.multiVideo)
    #expect(report.id == "m09-multi-video-transport-run")
    #expect(report.transmitted.framesSent == 4)
    #expect(report.receiver.receivedFrames == 4)
    #expect(report.receiver.displayedFrames == 2)
    #expect(report.receiver.droppedFrames == 2)
    #expect(multiVideo.streams.map(\.streamID) == [300, 301])
    #expect(multiVideo.streams.map(\.framesSent) == [2, 2])
    #expect(multiVideo.receiverSelection.mode == .multiView)
    #expect(multiVideo.receiverSelection.layout.maxVisibleStreams == 2)
    #expect(multiVideo.audioPriorityProtected)
    #expect(report.avSync?.policy.profile == .multiVideoPerformance)
    #expect(report.degradation.triggeredBeforeAudioTargetChange)
    #expect(report.degradation.triggeredBeforeAudioOrRouteImpact == true)
    #expect(report.verdict == .partial)
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
