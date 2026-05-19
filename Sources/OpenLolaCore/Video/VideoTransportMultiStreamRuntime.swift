import Foundation

// Staged multi-stream helpers used by VideoTransportRunner's socket-backed
// test-pattern runs. Promotion beyond staged status requires production
// multi-camera Blackmagic/ATEM source and output evidence plus physical
// packet-captured route evidence; keep GoalCodewiseClosure and source inventory
// in sync before presenting this as field-ready.
struct VideoTransportStreamRunState {
    var streamID: UInt32
    var sourceLabel: String
    var priority: Int
    var source: TestPatternCameraSource
    var framesGenerated = 0
    var framesReassembled = 0
    var framesRendered = 0
    var fragmentsSent = 0
}

func videoTransportStreamStates(
    configuration: VideoTransportRunConfiguration
) -> [VideoTransportStreamRunState] {
    (0..<configuration.streamCount).map { index in
        let streamID = configuration.streamID + UInt32(index)
        return VideoTransportStreamRunState(
            streamID: streamID,
            sourceLabel: configuration.streamCount == 1
                ? "synthetic-test-pattern"
                : "synthetic-test-pattern-\(streamID)",
            priority: max(1, 100 - (index * 20)),
            source: TestPatternCameraSource(
                width: configuration.width,
                height: configuration.height,
                frameIntervalNanoseconds: configuration.frameIntervalNanoseconds,
                streamID: streamID,
                sourceRole: configuration.sourceRole,
                frameRate: videoFrameRate(from: configuration.frameRate),
                pixelFormat: configuration.pixelFormat
            )
        )
    }
}

func videoTransportTotalFramesGenerated(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.framesGenerated }
}

func videoTransportTotalFragmentsSent(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.fragmentsSent }
}

func recordVideoTransportReassembledFrame(
    streamID: UInt32,
    states: inout [VideoTransportStreamRunState]
) {
    guard let index = states.firstIndex(where: { $0.streamID == streamID }) else {
        return
    }
    states[index].framesReassembled += 1
}

func recordVideoTransportRenderedFrame(
    streamID: UInt32,
    states: inout [VideoTransportStreamRunState]
) {
    guard let index = states.firstIndex(where: { $0.streamID == streamID }) else {
        return
    }
    states[index].framesRendered += 1
}

func videoTransportMultiVideoMetrics(
    configuration: VideoTransportRunConfiguration,
    states: [VideoTransportStreamRunState],
    streamBandwidthMegabitsPerSecond: Double,
    audioPriorityProtected: Bool,
    receiverObservedQueueDepthByStreamID: [UInt32: Int]
) -> MultiVideoTransportMetrics {
    let selectedStreamIDs = states.map { Int($0.streamID) }
    let visibleStreamCount = min(configuration.visibleStreamCount, selectedStreamIDs.count)
    return MultiVideoTransportMetrics(
        streams: states.map { state in
            VideoStreamTransportMetrics(
                streamID: Int(state.streamID),
                sourceLabel: state.sourceLabel,
                priority: state.priority,
                captureEnabled: true,
                queueDepth: configuration.queueDepth,
                observedQueueDepth: receiverObservedQueueDepthByStreamID[state.streamID] ?? 0,
                estimatedBandwidthMegabitsPerSecond: streamBandwidthMegabitsPerSecond,
                bandwidthBudgetMegabitsPerSecond: max(streamBandwidthMegabitsPerSecond + 1, 1),
                framesCaptured: state.framesGenerated,
                framesSent: state.framesGenerated,
                framesReceived: state.framesReassembled,
                framesRendered: state.framesRendered,
                framesDroppedBeforeSend: 0,
                framesDroppedLate: 0,
                framesDroppedBackpressure: max(0, state.framesReassembled - state.framesRendered),
                packetsSent: state.fragmentsSent
            )
        },
        receiverSelection: VideoReceiverSelection(
            mode: states.count == 1 ? .selectedStream : .multiView,
            selectedStreamIDs: selectedStreamIDs,
            layout: VideoMultiViewLayout(
                kind: states.count == 1 ? .single : .grid,
                maxVisibleStreams: max(1, visibleStreamCount)
            )
        ),
        aggregateBandwidthMegabitsPerSecond: streamBandwidthMegabitsPerSecond * Double(states.count),
        audioPriorityProtected: audioPriorityProtected
    )
}
