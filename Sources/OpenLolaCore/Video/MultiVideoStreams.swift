// Selects video streams, layouts, metrics, and priority drops for constrained receiver output.
import Foundation

/// Defines `selectedStream` and `multiView` states used to make video receiver selection mode decisions in video capture and frame transport.
public enum VideoReceiverSelectionMode: String, Codable, Equatable, Sendable {
    case selectedStream
    case multiView
}

/// Defines `single`, `grid`, and `pictureInPicture` states used to make video multi view layout kind decisions in video capture and frame transport.
public enum VideoMultiViewLayoutKind: String, Codable, Equatable, Sendable {
    case single
    case grid
    case pictureInPicture
}

/// Sets `kind` and `maxVisibleStreams` for the visible arrangement of video transport streams.
public struct VideoMultiViewLayout: Codable, Equatable, Sendable {
    public var kind: VideoMultiViewLayoutKind
    public var maxVisibleStreams: Int

    public init(kind: VideoMultiViewLayoutKind, maxVisibleStreams: Int) {
        self.kind = kind
        self.maxVisibleStreams = maxVisibleStreams
    }

    public func validate() throws {
        try VideoTransportValidator.requirePositive(
            maxVisibleStreams,
            "multiVideo.receiverSelection.layout.maxVisibleStreams"
        )
    }
}

/// Commits `mode`, `selectedStreamIDs`, and `layout` as the selected latency and receive-buffer operating point.
public struct VideoReceiverSelection: Codable, Equatable, Sendable {
    public var mode: VideoReceiverSelectionMode
    public var selectedStreamIDs: [Int]
    public var layout: VideoMultiViewLayout

    public init(
        mode: VideoReceiverSelectionMode,
        selectedStreamIDs: [Int],
        layout: VideoMultiViewLayout
    ) {
        self.mode = mode
        self.selectedStreamIDs = selectedStreamIDs
        self.layout = layout
    }

    public func selectedEnabledStreamIDs(from streams: [VideoStreamDescription]) -> [Int] {
        let selected = Set(selectedStreamIDs)
        return streams
            .filter { selected.contains($0.id) && $0.canSendMedia }
            .sorted(by: videoStreamPriorityOrder)
            .map(\.id)
    }

    public func visibleStreamIDs(from streams: [VideoStreamDescription]) -> [Int] {
        Array(selectedEnabledStreamIDs(from: streams).prefix(layout.maxVisibleStreams))
    }

    public func validate(against streams: [VideoStreamDescription]) throws {
        guard !selectedStreamIDs.isEmpty else {
            throw VideoTransportValidationError.emptyList("multiVideo.receiverSelection.selectedStreamIDs")
        }
        try layout.validate()
        let knownIDs = Set(streams.map(\.id))
        for id in selectedStreamIDs where !knownIDs.contains(id) {
            throw VideoTransportValidationError.unknownMultiVideoSelectedStreamID(id)
        }
        if mode == .selectedStream && layout.maxVisibleStreams != 1 {
            throw VideoTransportValidationError.invalidMultiVideoLayout(
                "selectedStream requires maxVisibleStreams=1"
            )
        }
    }
}

/// Tracks `streamID`, `sourceLabel`, `priority`, and `captureEnabled` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
public struct VideoStreamTransportMetrics: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var streamID: Int
        public var sourceLabel: String
        public var priority: Int
        public var captureEnabled: Bool

        public init(streamID: Int, sourceLabel: String, priority: Int, captureEnabled: Bool) {
            self.streamID = streamID
            self.sourceLabel = sourceLabel
            self.priority = priority
            self.captureEnabled = captureEnabled
        }
    }

    public struct Queue: Equatable, Sendable {
        public var configuredDepth: Int
        public var observedDepth: Int

        public init(configuredDepth: Int, observedDepth: Int) {
            self.configuredDepth = configuredDepth
            self.observedDepth = observedDepth
        }
    }

    public struct Bandwidth: Equatable, Sendable {
        public var estimatedMegabitsPerSecond: Double
        public var budgetMegabitsPerSecond: Double

        public init(estimatedMegabitsPerSecond: Double, budgetMegabitsPerSecond: Double) {
            self.estimatedMegabitsPerSecond = estimatedMegabitsPerSecond
            self.budgetMegabitsPerSecond = budgetMegabitsPerSecond
        }
    }

    public struct FrameCounts: Equatable, Sendable {
        public var captured: Int
        public var sent: Int
        public var received: Int
        public var rendered: Int

        public init(captured: Int, sent: Int, received: Int, rendered: Int) {
            self.captured = captured
            self.sent = sent
            self.received = received
            self.rendered = rendered
        }
    }

    public struct DropCounts: Equatable, Sendable {
        public var beforeSend: Int
        public var late: Int
        public var backpressure: Int
        public var packetsSent: Int

        public init(beforeSend: Int, late: Int, backpressure: Int, packetsSent: Int) {
            self.beforeSend = beforeSend
            self.late = late
            self.backpressure = backpressure
            self.packetsSent = packetsSent
        }
    }

    public var streamID: Int
    public var sourceLabel: String
    public var priority: Int
    public var captureEnabled: Bool
    public var queueDepth: Int
    public var observedQueueDepth: Int
    public var estimatedBandwidthMegabitsPerSecond: Double
    public var bandwidthBudgetMegabitsPerSecond: Double
    public var framesCaptured: Int
    public var framesSent: Int
    public var framesReceived: Int
    public var framesRendered: Int
    public var framesDroppedBeforeSend: Int
    public var framesDroppedLate: Int
    public var framesDroppedBackpressure: Int
    public var packetsSent: Int

    public init(
        identity: Identity,
        queue: Queue,
        bandwidth: Bandwidth,
        frames: FrameCounts,
        drops: DropCounts
    ) {
        self.streamID = identity.streamID
        self.sourceLabel = identity.sourceLabel
        self.priority = identity.priority
        self.captureEnabled = identity.captureEnabled
        self.queueDepth = queue.configuredDepth
        self.observedQueueDepth = queue.observedDepth
        self.estimatedBandwidthMegabitsPerSecond = bandwidth.estimatedMegabitsPerSecond
        self.bandwidthBudgetMegabitsPerSecond = bandwidth.budgetMegabitsPerSecond
        self.framesCaptured = frames.captured
        self.framesSent = frames.sent
        self.framesReceived = frames.received
        self.framesRendered = frames.rendered
        self.framesDroppedBeforeSend = drops.beforeSend
        self.framesDroppedLate = drops.late
        self.framesDroppedBackpressure = drops.backpressure
        self.packetsSent = drops.packetsSent
    }

    public func validate() throws {
        try VideoTransportValidator.requirePositive(streamID, "multiVideo.streams.streamID")
        try VideoTransportValidator.requireNonEmpty(sourceLabel, "multiVideo.streams.sourceLabel")
        try VideoTransportValidator.requireNonNegative(priority, "multiVideo.streams.priority")
        try VideoTransportValidator.requireNonNegative(queueDepth, "multiVideo.streams.queueDepth")
        try VideoTransportValidator.requireNonNegative(observedQueueDepth, "multiVideo.streams.observedQueueDepth")
        try VideoTransportValidator.requireNonNegative(
            estimatedBandwidthMegabitsPerSecond,
            "multiVideo.streams.estimatedBandwidthMegabitsPerSecond"
        )
        try VideoTransportValidator.requireNonNegative(
            bandwidthBudgetMegabitsPerSecond,
            "multiVideo.streams.bandwidthBudgetMegabitsPerSecond"
        )
        try VideoTransportValidator.requireNonNegative(framesCaptured, "multiVideo.streams.framesCaptured")
        try VideoTransportValidator.requireNonNegative(framesSent, "multiVideo.streams.framesSent")
        try VideoTransportValidator.requireNonNegative(framesReceived, "multiVideo.streams.framesReceived")
        try VideoTransportValidator.requireNonNegative(framesRendered, "multiVideo.streams.framesRendered")
        try VideoTransportValidator.requireNonNegative(
            framesDroppedBeforeSend,
            "multiVideo.streams.framesDroppedBeforeSend"
        )
        try VideoTransportValidator.requireNonNegative(framesDroppedLate, "multiVideo.streams.framesDroppedLate")
        try VideoTransportValidator.requireNonNegative(
            framesDroppedBackpressure,
            "multiVideo.streams.framesDroppedBackpressure"
        )
        try VideoTransportValidator.requireNonNegative(packetsSent, "multiVideo.streams.packetsSent")
    }
}

/// Tracks `streams`, `receiverSelection`, `aggregateBandwidthMegabitsPerSecond`, and `audioPriorityProtected` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
public struct MultiVideoTransportMetrics: Codable, Equatable, Sendable {
    public var streams: [VideoStreamTransportMetrics]
    public var receiverSelection: VideoReceiverSelection
    public var aggregateBandwidthMegabitsPerSecond: Double
    public var audioPriorityProtected: Bool?
    public var audioPriorityEvidence: VideoAudioPriorityEvidence?

    public init(
        streams: [VideoStreamTransportMetrics],
        receiverSelection: VideoReceiverSelection,
        aggregateBandwidthMegabitsPerSecond: Double,
        audioPriorityProtected: Bool?,
        audioPriorityEvidence: VideoAudioPriorityEvidence? = .measured
    ) {
        self.streams = streams
        self.receiverSelection = receiverSelection
        self.aggregateBandwidthMegabitsPerSecond = aggregateBandwidthMegabitsPerSecond
        self.audioPriorityProtected = audioPriorityProtected
        self.audioPriorityEvidence = audioPriorityEvidence
    }

    public func validate() throws {
        guard !streams.isEmpty else {
            throw VideoTransportValidationError.emptyList("multiVideo.streams")
        }
        try validateStreams()
        try VideoTransportValidator.requireNonNegative(
            aggregateBandwidthMegabitsPerSecond,
            "multiVideo.aggregateBandwidthMegabitsPerSecond"
        )
        try validateAudioPriorityEvidence()
        try receiverSelection.validate(against: streams.map(Self.pseudoStream))
    }

    private func validateStreams() throws {
        var seenIDs = Set<Int>()
        for stream in streams {
            try stream.validate()
            if !seenIDs.insert(stream.streamID).inserted {
                throw VideoTransportValidationError.duplicateMultiVideoStreamID(stream.streamID)
            }
        }
    }

    private func validateAudioPriorityEvidence() throws {
        if audioPriorityEvidence == .measured, audioPriorityProtected == nil {
            throw VideoTransportValidationError.invalidMultiVideoAudioPriorityEvidence
        }
        if audioPriorityEvidence == .notMeasured, audioPriorityProtected != nil {
            throw VideoTransportValidationError.invalidMultiVideoAudioPriorityEvidence
        }
    }

    private static func pseudoStream(_ stream: VideoStreamTransportMetrics) -> VideoStreamDescription {
        VideoStreamDescription(
            identity: .init(
                id: stream.streamID,
                direction: stream.captureEnabled ? .send : .disabled,
                role: stream.captureEnabled ? .testPattern : .disabled,
                sourceLabel: stream.sourceLabel,
                payloadType: .videoRawFrameFragment
            ),
            format: .init(
                resolution: .init(width: 1, height: 1),
                frameRate: .init(numerator: 1, denominator: 1),
                pixelFormat: stream.captureEnabled ? .rgb24 : .disabled,
                transportFormat: stream.captureEnabled ? .rawFrameFragment : .disabled
            ),
            capture: .init(
                priority: max(0, stream.priority),
                captureEnabled: stream.captureEnabled,
                queueDepth: max(0, stream.queueDepth),
                bandwidthBudgetMegabitsPerSecond: max(0, stream.bandwidthBudgetMegabitsPerSecond)
            )
        )
    }
}

/// Groups `acceptedStreamIDs` and `droppedStreamIDs` into the public MultiVideoDropDecision contract used by video transport.
public struct MultiVideoDropDecision: Equatable, Sendable {
    public var acceptedStreamIDs: [Int]
    public var droppedStreamIDs: [Int]

    public init(acceptedStreamIDs: [Int], droppedStreamIDs: [Int]) {
        self.acceptedStreamIDs = acceptedStreamIDs
        self.droppedStreamIDs = droppedStreamIDs
    }
}

/// Chooses lower-priority video frames to discard when transport pressure threatens audio or selected video.
public enum MultiVideoPriorityDropper {
    public static func select(
        _ frames: [VideoOutputFrame],
        streams: [VideoStreamDescription],
        maxAcceptedFrames: Int
    ) -> MultiVideoDropDecision {
        guard maxAcceptedFrames > 0 else {
            return MultiVideoDropDecision(
                acceptedStreamIDs: [],
                droppedStreamIDs: frames.map { Int($0.packet.streamID) }
            )
        }
        let priorities = Dictionary(uniqueKeysWithValues: streams.map { ($0.id, $0.priority) })
        var accepted: [VideoOutputFrame] = []
        var dropped: [VideoOutputFrame] = []
        for frame in frames {
            insertByPriority(frame, into: &accepted, priorities: priorities)
            if accepted.count > maxAcceptedFrames {
                dropped.append(accepted.removeLast())
            }
        }
        return MultiVideoDropDecision(
            acceptedStreamIDs: accepted.map { Int($0.packet.streamID) },
            droppedStreamIDs: dropped.map { Int($0.packet.streamID) }
        )
    }

    private static func insertByPriority(
        _ frame: VideoOutputFrame,
        into accepted: inout [VideoOutputFrame],
        priorities: [Int: Int]
    ) {
        let insertionIndex = accepted.firstIndex { existing in
            hasHigherPriority(frame, than: existing, priorities: priorities)
        } ?? accepted.endIndex
        accepted.insert(frame, at: insertionIndex)
    }

    private static func hasHigherPriority(
        _ left: VideoOutputFrame,
        than right: VideoOutputFrame,
        priorities: [Int: Int]
    ) -> Bool {
        let leftID = Int(left.packet.streamID)
        let rightID = Int(right.packet.streamID)
        let leftPriority = priorities[leftID] ?? 0
        let rightPriority = priorities[rightID] ?? 0
        if leftPriority == rightPriority {
            return left.receivedAtNanoseconds < right.receivedAtNanoseconds
        }
        return leftPriority > rightPriority
    }
}

private func videoStreamPriorityOrder(
    _ left: VideoStreamDescription,
    _ right: VideoStreamDescription
) -> Bool {
    if left.priority == right.priority {
        return left.id < right.id
    }
    return left.priority > right.priority
}
