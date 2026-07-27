// Verifies that receiver selection keeps selected enabled streams only.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func receiverSelectionKeepsSelectedEnabledStreamsOnly() throws {
    let streams = [
        m10TransportStream(id: 100, label: "Program", captureEnabled: true),
        m10TransportStream(id: 101, label: "Preview", captureEnabled: false),
        VideoStreamDescription.disabled(id: 102, sourceLabel: "Close disabled")
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
        m10TransportStream(id: 102, label: "Monitor", priority: 10)
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
            m10StreamMetrics(streamID: 100)
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

@Test
func videoStreamDescriptionCodableRemainsFlatAndRoundTrips() throws {
    let stream = m10TransportStream(id: 100, label: "Program")
    let data = try JSONEncoder().encode(stream)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(try JSONDecoder().decode(VideoStreamDescription.self, from: data) == stream)
    #expect(object["id"] as? Int == 100)
    #expect(object["sourceLabel"] as? String == "Program")
    #expect(object["identity"] == nil)
    #expect(object["format"] == nil)
    #expect(object["capture"] == nil)
}

@Test
func videoStreamMetricsCodableRemainsFlatAndRoundTrips() throws {
    let metrics = m10StreamMetrics(streamID: 100)
    let data = try JSONEncoder().encode(metrics)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(try JSONDecoder().decode(VideoStreamTransportMetrics.self, from: data) == metrics)
    #expect(object["streamID"] as? Int == 100)
    #expect(object["framesSent"] as? Int == 1)
    #expect(object["identity"] == nil)
    #expect(object["frames"] == nil)
    #expect(object["drops"] == nil)
}

private func m10TransportStream(
    id: Int,
    label: String,
    priority: Int = 100,
    captureEnabled: Bool = true
) -> VideoStreamDescription {
    let transportFormat = VideoStreamDescription.Format(
        resolution: .init(width: 1_280, height: 720),
        frameRate: .init(numerator: 30, denominator: 1),
        pixelFormat: .bgra8,
        transportFormat: .rawFrameFragment
    )
    return VideoStreamDescription(
        identity: .init(
            id: id,
            direction: .send,
            role: .atemProgram,
            sourceLabel: label,
            payloadType: .videoRawFrameFragment
        ),
        format: transportFormat,
        capture: .init(priority: priority, captureEnabled: captureEnabled)
    )
}

private func m10StreamMetrics(streamID: Int) -> VideoStreamTransportMetrics {
    VideoStreamTransportMetrics(
        identity: .init(
            streamID: streamID,
            sourceLabel: "stream-\(streamID)",
            priority: 100,
            captureEnabled: true
        ),
        queue: .init(configuredDepth: 1, observedDepth: 1),
        bandwidth: .init(estimatedMegabitsPerSecond: 100, budgetMegabitsPerSecond: 10_000),
        frames: .init(captured: 1, sent: 1, received: 1, rendered: 1),
        drops: .init(beforeSend: 0, late: 0, backpressure: 0, packetsSent: 1)
    )
}

private func m10Packet(streamID: UInt32, sequenceNumber: UInt64) -> VideoTransportPacket {
    var fields = VideoTransportPacketFields()
    fields.streamID = streamID
    fields.sequenceNumber = sequenceNumber
    fields.timestampNanoseconds = sequenceNumber
    fields.timestampBasis = .syntheticMonotonicNanoseconds
    fields.sourceRole = .testPattern
    fields.width = 1_280
    fields.height = 720
    fields.pixelFormat = "synthetic-rgb"
    fields.frameRate = VideoFrameRate(numerator: 30, denominator: 1)
    fields.payloadByteCount = 1_280 * 720 * 3
    fields.frameFingerprint = "m10-\(streamID)-\(sequenceNumber)"
    return VideoTransportPacket(fields)
}
