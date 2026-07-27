// Tracks per-stream generation, fragmentation, send, drop, reassembly, and render counters without crowding the frame-loop scheduler.
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
    var framesScheduled = 0
    var framesGenerated = 0
    var framesFragmented = 0
    var framesCompletedSend = 0
    var framesReassembled = 0
    var framesRendered = 0
    var framesDroppedBeforeSend = 0
    var fragmentsSent = 0
    var packetsDropped = 0
}

struct VideoTransportMultiVideoMetricsInput {
    var configuration: VideoTransportRunConfiguration
    var states: [VideoTransportStreamRunState]
    var streamBandwidthMegabitsPerSecond: Double
    var audioPriority: VideoTransportAudioPriorityMetrics
    var receiverObservedQueueDepthByStreamID: [UInt32: Int]
}

struct VideoTransportAudioPriorityMetrics {
    var protected: Bool?
    var evidence: VideoAudioPriorityEvidence
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

func videoTransportTotalFramesScheduled(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.framesScheduled }
}

func videoTransportTotalFramesFragmented(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.framesFragmented }
}

func videoTransportTotalFramesCompletedSend(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.framesCompletedSend }
}

func videoTransportTotalFramesDroppedBeforeSend(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.framesDroppedBeforeSend }
}

func videoTransportTotalFragmentsSent(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.fragmentsSent }
}

func videoTransportTotalPacketsDropped(
    _ states: [VideoTransportStreamRunState]
) -> Int {
    states.reduce(0) { $0 + $1.packetsDropped }
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
    _ input: VideoTransportMultiVideoMetricsInput
) -> MultiVideoTransportMetrics {
    let selectedStreamIDs = input.states.map { Int($0.streamID) }
    let visibleStreamCount = min(input.configuration.visibleStreamCount, selectedStreamIDs.count)
    return MultiVideoTransportMetrics(
        streams: input.states.map { state in
            VideoStreamTransportMetrics(
                identity: .init(
                    streamID: Int(state.streamID),
                    sourceLabel: state.sourceLabel,
                    priority: state.priority,
                    captureEnabled: true
                ),
                queue: .init(
                    configuredDepth: input.configuration.queueDepth,
                    observedDepth: input.receiverObservedQueueDepthByStreamID[state.streamID] ?? 0
                ),
                bandwidth: .init(
                    estimatedMegabitsPerSecond: input.streamBandwidthMegabitsPerSecond,
                    budgetMegabitsPerSecond: max(input.streamBandwidthMegabitsPerSecond + 1, 1)
                ),
                frames: .init(
                    captured: state.framesGenerated,
                    sent: state.framesCompletedSend,
                    received: state.framesReassembled,
                    rendered: state.framesRendered
                ),
                drops: .init(
                    beforeSend: state.framesDroppedBeforeSend,
                    late: 0,
                    backpressure: max(0, state.framesReassembled - state.framesRendered),
                    packetsSent: state.fragmentsSent
                )
            )
        },
        receiverSelection: VideoReceiverSelection(
            mode: input.states.count == 1 ? .selectedStream : .multiView,
            selectedStreamIDs: selectedStreamIDs,
            layout: VideoMultiViewLayout(
                kind: input.states.count == 1 ? .single : .grid,
                maxVisibleStreams: max(1, visibleStreamCount)
            )
        ),
        aggregateBandwidthMegabitsPerSecond: input.streamBandwidthMegabitsPerSecond * Double(input.states.count),
        audioPriorityProtected: input.audioPriority.protected,
        audioPriorityEvidence: input.audioPriority.evidence
    )
}
