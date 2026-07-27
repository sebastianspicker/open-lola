// Verifies that the video transport runner rejects unsupported user-interactive QoS.
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
func videoTransportRunnerWaitsOnlyForLoopbackReassembly() {
    #expect(videoTransportWaitsForLoopbackReassembly(true))
    #expect(!videoTransportWaitsForLoopbackReassembly(false))
}

@Test
func videoTransportFrameScheduleAdvancesFromOriginalSlotWithoutReanchoring() {
    #expect(videoTransportFrameDeadline(start: 100, interval: 25) == 125)
    #expect(nextVideoTransportFrameDeadline(previous: 125, interval: 25) == 150)
    #expect(videoTransportFrameDeadline(start: UInt64.max - 5, interval: 10) == UInt64.max)
}

@Test
func videoTransportDeadlineAbandonsPreparedSuffixBeforeSend() {
    var readings: [UInt64] = [0, 0, 0, 100]
    var prepared: [Int] = []
    var sent: [Int] = []

    let outcome = sendVideoTransportUnitsUntilDeadline(
        unitCount: 3,
        deadline: 100,
        now: { readings.removeFirst() },
        prepare: { index in
            prepared.append(index)
            return index
        },
        send: { index in
            sent.append(index)
            return .sent
        }
    )

    #expect(outcome == VideoTransportDeadlineSendOutcome(unitsSent: 1, unitsDropped: 2))
    #expect(prepared == [0, 1])
    #expect(sent == [0])
}

@Test
func videoTransportBackpressureAbandonsCurrentFrameSuffix() {
    var prepared: [Int] = []
    var sent: [Int] = []

    let outcome = sendVideoTransportUnitsUntilDeadline(
        unitCount: 4,
        deadline: 100,
        now: { 0 },
        prepare: { index in
            prepared.append(index)
            return index
        },
        send: { index in
            sent.append(index)
            return index == 1 ? .wouldBlock : .sent
        }
    )

    #expect(outcome == VideoTransportDeadlineSendOutcome(unitsSent: 1, unitsDropped: 3))
    #expect(prepared == [0, 1])
    #expect(sent == [0, 1])
}

@Test
func videoTransportBackpressureReportsNoCompletedFrameAsSent() {
    let configuration = VideoTransportRunConfiguration(VideoTransportRunConfiguration.Input(
        mode: .raw,
        connection: .init(peer: "127.0.0.1", port: 5_004, durationSeconds: 1, outputPath: "reports/m09-video-transport-run.json"),
        frame: .init(width: 64, height: 36, frameRate: 1, maxPacketBytes: 1_200),
        route: .init(kind: .localhost, packetCapturePoint: "local-loopback")
    ))
    let outcome = sendVideoTransportUnitsUntilDeadline(
        unitCount: 1,
        deadline: 100,
        now: { 0 },
        prepare: { $0 },
        send: { _ in .wouldBlock }
    )
    var context = VideoTransportRunContext(configuration: configuration)
    context.streamStates[0].framesScheduled = 1
    context.streamStates[0].framesGenerated = 1
    context.streamStates[0].framesFragmented = 1
    context.streamStates[0].framesCompletedSend = outcome.unitsDropped == 0 ? 1 : 0
    context.streamStates[0].framesDroppedBeforeSend = outcome.unitsDropped == 0 ? 0 : 1
    context.streamStates[0].packetsDropped = outcome.unitsDropped

    let metrics = videoTransportReportMetrics(configuration: configuration, context: context)
    let transmitted = videoTransportTransmittedMetrics(metrics)
    let multiVideo = videoTransportMultiVideoMetrics(.init(
        configuration: configuration,
        states: context.streamStates,
        streamBandwidthMegabitsPerSecond: metrics.streamBandwidth,
        audioPriority: .init(protected: nil, evidence: .notMeasured),
        receiverObservedQueueDepthByStreamID: [:]
    ))

    #expect(transmitted.framesSent == 0)
    #expect(transmitted.framesDroppedBeforeSend == 1)
    #expect(multiVideo.streams.map(\.framesSent) == [0])
}

@Test
func videoTransportLatencyReservoirKeepsPerFragmentTelemetryBounded() {
    var reservoir = VideoTransportLatencyReservoir()
    for value in 0..<5_000 {
        reservoir.record(Double(value))
    }

    #expect(reservoir.samples.count == 4_096)
    #expect(reservoir.metrics.maxMicroseconds == 4_999)
}

@Test
func videoTransportRunnerRejectsPacketSizesThatCannotFitFragmentHeaders() throws {
    let configuration = videoTransportRunnerConfiguration(
        frameRate: 1,
        maxPacketBytes: 16
    )

    do {
        _ = try VideoTransportRunner.run(configuration: configuration)
        Issue.record("expected maxPacketTooSmall when maxPacketBytes cannot fit video fragment headers")
    } catch let error as VideoTransportFragmentError {
        guard case .maxPacketTooSmall(let maxPacketBytes, _) = error else {
            Issue.record("expected maxPacketTooSmall, got \(error)")
            return
        }
        #expect(maxPacketBytes == 16)
    }
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
        "--output", "reports/m09-video-transport-run.json"
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
func videoTransportRunConfigurationRejectsInvalidArguments() {
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
            "--output", "reports/m09-video-transport-run.json"
        ])
    }
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
            "--output", "reports/m09-video-transport-run.json"
        ])
    }
    #expect(throws: VideoTransportRunConfigurationError.unsupportedMode("videoToolboxH264")) {
        _ = try VideoTransportRunConfiguration.parse([
            "--mode", "videoToolboxH264",
            "--peer", "127.0.0.1",
            "--port", "5004",
            "--duration-seconds", "1",
            "--output", "reports/m09-video-transport-run.json"
        ])
    }
}

@Test
func videoTransportRunBuildsPartialRawLatestFrameReport() throws {
    let configuration = videoTransportRunnerConfiguration(
        frameRate: 10,
        maxPacketBytes: 1_200
    )

    let report = try VideoTransportRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.id == "m09-video-transport-run")
    #expect(report.transport.mode == .raw)
    #expect(report.routeEvidence?.routeKind == .localhost)
    #expect(report.routeEvidence?.packetCapturePoint == "local-loopback")
    #expect(report.transmitted.framesSent == 10)
    #expect(report.receiver.receivedFrames == 10)
    #expect(report.receiver.displayedFrames == 0)
    #expect(report.receiver.droppedFrames == 9)
    #expect(report.fragmentation?.framesFragmented == 10)
    #expect(report.fragmentation?.fragmentsSent == 20)
    #expect(report.fragmentation?.maxPayloadBytesPerFragment == 1_084)
    #expect(report.reassembly?.framesReassembled == 10)
    #expect(report.transmitted.packetsSent == 20)
    #expect(report.receiver.queuePolicy == .latestFrame)
    #expect(report.verdict == .partial)
}

private func videoTransportRunnerConfiguration(
    frameRate: Int,
    maxPacketBytes: Int
) -> VideoTransportRunConfiguration {
    VideoTransportRunConfiguration(VideoTransportRunConfiguration.Input(
        mode: .raw,
        connection: .init(peer: "127.0.0.1", port: 5_004, durationSeconds: 1, outputPath: "reports/m09-video-transport-run.json"),
        frame: .init(
            width: 32,
            height: 16,
            frameRate: Double(frameRate),
            maxPacketBytes: maxPacketBytes
        ),
        route: .init(kind: .localhost, packetCapturePoint: "local-loopback")
    ))
}

@Test
func videoTransportRunBuildsPartialStagedMultiVideoReport() throws {
    let configuration = VideoTransportRunConfiguration(VideoTransportRunConfiguration.Input(
        mode: .raw,
        connection: .init(peer: "127.0.0.1", port: 5_014, durationSeconds: 1, outputPath: "reports/m09-multi-video-transport-run.json"),
        stream: .init(id: 300, count: 2, visibleCount: 2),
        frame: .init(width: 64, height: 36, frameRate: 2, maxPacketBytes: 1_200),
        route: .init(kind: .localhost, packetCapturePoint: "local-loopback")
    ))

    let report = try VideoTransportRunner.run(configuration: configuration)

    try report.validate()

    let multiVideo = try #require(report.multiVideo)
    #expect(report.id == "m09-multi-video-transport-run")
    #expect(report.transmitted.framesSent == 4)
    #expect(report.receiver.receivedFrames == 4)
    #expect(report.receiver.displayedFrames == 0)
    #expect(report.receiver.droppedFrames == 2)
    #expect(multiVideo.streams.map(\.streamID) == [300, 301])
    #expect(multiVideo.streams.map(\.framesSent) == [2, 2])
    #expect(multiVideo.streams.map(\.observedQueueDepth) == [1, 1])
    #expect(multiVideo.receiverSelection.mode == .multiView)
    #expect(multiVideo.receiverSelection.layout.maxVisibleStreams == 2)
    #expect(multiVideo.audioPriorityProtected == nil)
    #expect(multiVideo.audioPriorityEvidence == .notMeasured)
    #expect(report.avSync?.policy.profile == .multiVideoPerformance)
    #expect(report.degradation.triggeredBeforeAudioTargetChange)
    #expect(report.degradation.triggeredBeforeAudioOrRouteImpact == true)
    #expect(report.verdict == .partial)
}
