import Foundation
import Testing

@testable import OpenLolaCore


@Test
func receiverSelectionKeepsSelectedEnabledStreamsOnly() throws {
    let streams = [
        m10TransportStream(id: 100, label: "Program", captureEnabled: true),
        m10TransportStream(id: 101, label: "Preview", captureEnabled: false),
        VideoStreamDescription.disabled(id: 102, sourceLabel: "Close disabled"),
    ]
    let selection = VideoReceiverSelection(
        mode: .selectedStream,
        selectedStreamIDs: [100, 101, 102],
        layout: VideoMultiViewLayout(kind: .single, maxVisibleStreams: 1)
    )

    try selection.validate(against: streams)

    #expect(selection.selectedEnabledStreamIDs(from: streams) == [100])
}

@Test
func priorityDropperDropsLowerPriorityVideoFirst() {
    let streams = [
        m10TransportStream(id: 100, label: "Primary", priority: 100),
        m10TransportStream(id: 101, label: "Secondary", priority: 60),
        m10TransportStream(id: 102, label: "Monitor", priority: 10),
    ]
    let frames = streams.map { stream in
        VideoOutputFrame(
            packet: m10Packet(streamID: UInt32(stream.id), sequenceNumber: 1),
            receivedAtNanoseconds: UInt64(stream.id),
            reassembledAtNanoseconds: UInt64(stream.id + 100)
        )
    }

    let decision = MultiVideoPriorityDropper.select(
        frames,
        streams: streams,
        maxAcceptedFrames: 2
    )

    #expect(decision.acceptedStreamIDs == [100, 101])
    #expect(decision.droppedStreamIDs == [102])
}

@Test
func latestVideoFrameReceiverTracksObservedQueueDepthByStreamID() {
    var receiver = LatestVideoFrameReceiver(maxDepth: 3)

    receiver.receive(m10Packet(streamID: 100, sequenceNumber: 1))
    receiver.receive(m10Packet(streamID: 101, sequenceNumber: 1))
    receiver.receive(m10Packet(streamID: 100, sequenceNumber: 2))

    #expect(receiver.observedQueueDepth == 3)
    #expect(receiver.observedQueueDepthByStreamID[100] == 2)
    #expect(receiver.observedQueueDepthByStreamID[101] == 1)
}

@Test
func multiVideoMetricsRejectDuplicateStreamCounters() {
    let metrics = MultiVideoTransportMetrics(
        streams: [
            m10StreamMetrics(streamID: 100),
            m10StreamMetrics(streamID: 100),
        ],
        receiverSelection: VideoReceiverSelection(
            mode: .multiView,
            selectedStreamIDs: [100],
            layout: VideoMultiViewLayout(kind: .grid, maxVisibleStreams: 2)
        ),
        aggregateBandwidthMegabitsPerSecond: 100,
        audioPriorityProtected: true
    )

    #expect(throws: VideoTransportValidationError.duplicateMultiVideoStreamID(100)) {
        try metrics.validate()
    }
}

private func m10TransportStream(
    id: Int,
    label: String,
    priority: Int = 100,
    captureEnabled: Bool = true
) -> VideoStreamDescription {
    VideoStreamDescription(
        id: id,
        direction: .send,
        role: .atemProgram,
        resolution: VideoResolution(width: 1_280, height: 720),
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        pixelFormat: .bgra8,
        transportFormat: .rawFrameFragment,
        sourceLabel: label,
        payloadType: .videoRawFrameFragment,
        priority: priority,
        captureEnabled: captureEnabled,
        queueDepth: 1,
        bandwidthBudgetMegabitsPerSecond: 10_000
    )
}

private func m10StreamMetrics(streamID: Int) -> VideoStreamTransportMetrics {
    VideoStreamTransportMetrics(
        streamID: streamID,
        sourceLabel: "stream-\(streamID)",
        priority: 100,
        captureEnabled: true,
        queueDepth: 1,
        observedQueueDepth: 1,
        estimatedBandwidthMegabitsPerSecond: 100,
        bandwidthBudgetMegabitsPerSecond: 10_000,
        framesCaptured: 1,
        framesSent: 1,
        framesReceived: 1,
        framesRendered: 1,
        framesDroppedBeforeSend: 0,
        framesDroppedLate: 0,
        framesDroppedBackpressure: 0,
        packetsSent: 1
    )
}

private func m10Packet(streamID: UInt32, sequenceNumber: UInt64) -> VideoTransportPacket {
    VideoTransportPacket(
        streamID: streamID,
        sequenceNumber: sequenceNumber,
        timestampNanoseconds: sequenceNumber,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 1_280,
        height: 720,
        pixelFormat: "synthetic-rgb",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        payloadByteCount: 1_280 * 720 * 3,
        frameFingerprint: "m10-\(streamID)-\(sequenceNumber)"
    )
}
