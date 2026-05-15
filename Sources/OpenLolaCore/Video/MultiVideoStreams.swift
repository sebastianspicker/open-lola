import Foundation

public enum VideoReceiverSelectionMode: String, Codable, Equatable, Sendable {
    case selectedStream
    case multiView
}

public enum VideoMultiViewLayoutKind: String, Codable, Equatable, Sendable {
    case single
    case grid
    case pictureInPicture
}

public struct VideoMultiViewLayout: Codable, Equatable, Sendable {
    public var kind: VideoMultiViewLayoutKind
    public var maxVisibleStreams: Int

    public init(kind: VideoMultiViewLayoutKind, maxVisibleStreams: Int) {
        self.kind = kind
        self.maxVisibleStreams = maxVisibleStreams
    }

    public func validate() throws {
        try requireTransportPositive(maxVisibleStreams, "multiVideo.receiverSelection.layout.maxVisibleStreams")
    }
}

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

public struct VideoStreamTransportMetrics: Codable, Equatable, Sendable {
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
        streamID: Int,
        sourceLabel: String,
        priority: Int,
        captureEnabled: Bool,
        queueDepth: Int,
        observedQueueDepth: Int,
        estimatedBandwidthMegabitsPerSecond: Double,
        bandwidthBudgetMegabitsPerSecond: Double,
        framesCaptured: Int,
        framesSent: Int,
        framesReceived: Int,
        framesRendered: Int,
        framesDroppedBeforeSend: Int,
        framesDroppedLate: Int,
        framesDroppedBackpressure: Int,
        packetsSent: Int
    ) {
        self.streamID = streamID
        self.sourceLabel = sourceLabel
        self.priority = priority
        self.captureEnabled = captureEnabled
        self.queueDepth = queueDepth
        self.observedQueueDepth = observedQueueDepth
        self.estimatedBandwidthMegabitsPerSecond = estimatedBandwidthMegabitsPerSecond
        self.bandwidthBudgetMegabitsPerSecond = bandwidthBudgetMegabitsPerSecond
        self.framesCaptured = framesCaptured
        self.framesSent = framesSent
        self.framesReceived = framesReceived
        self.framesRendered = framesRendered
        self.framesDroppedBeforeSend = framesDroppedBeforeSend
        self.framesDroppedLate = framesDroppedLate
        self.framesDroppedBackpressure = framesDroppedBackpressure
        self.packetsSent = packetsSent
    }

    public func validate() throws {
        try requireTransportPositive(streamID, "multiVideo.streams.streamID")
        try requireTransportNonEmpty(sourceLabel, "multiVideo.streams.sourceLabel")
        try requireTransportNonNegative(priority, "multiVideo.streams.priority")
        try requireTransportNonNegative(queueDepth, "multiVideo.streams.queueDepth")
        try requireTransportNonNegative(observedQueueDepth, "multiVideo.streams.observedQueueDepth")
        try requireTransportNonNegative(
            estimatedBandwidthMegabitsPerSecond,
            "multiVideo.streams.estimatedBandwidthMegabitsPerSecond"
        )
        try requireTransportNonNegative(
            bandwidthBudgetMegabitsPerSecond,
            "multiVideo.streams.bandwidthBudgetMegabitsPerSecond"
        )
        try requireTransportNonNegative(framesCaptured, "multiVideo.streams.framesCaptured")
        try requireTransportNonNegative(framesSent, "multiVideo.streams.framesSent")
        try requireTransportNonNegative(framesReceived, "multiVideo.streams.framesReceived")
        try requireTransportNonNegative(framesRendered, "multiVideo.streams.framesRendered")
        try requireTransportNonNegative(
            framesDroppedBeforeSend,
            "multiVideo.streams.framesDroppedBeforeSend"
        )
        try requireTransportNonNegative(framesDroppedLate, "multiVideo.streams.framesDroppedLate")
        try requireTransportNonNegative(
            framesDroppedBackpressure,
            "multiVideo.streams.framesDroppedBackpressure"
        )
        try requireTransportNonNegative(packetsSent, "multiVideo.streams.packetsSent")
    }
}

public struct MultiVideoTransportMetrics: Codable, Equatable, Sendable {
    public var streams: [VideoStreamTransportMetrics]
    public var receiverSelection: VideoReceiverSelection
    public var aggregateBandwidthMegabitsPerSecond: Double
    public var audioPriorityProtected: Bool

    public init(
        streams: [VideoStreamTransportMetrics],
        receiverSelection: VideoReceiverSelection,
        aggregateBandwidthMegabitsPerSecond: Double,
        audioPriorityProtected: Bool
    ) {
        self.streams = streams
        self.receiverSelection = receiverSelection
        self.aggregateBandwidthMegabitsPerSecond = aggregateBandwidthMegabitsPerSecond
        self.audioPriorityProtected = audioPriorityProtected
    }

    public func validate() throws {
        guard !streams.isEmpty else {
            throw VideoTransportValidationError.emptyList("multiVideo.streams")
        }
        var seenIDs = Set<Int>()
        for stream in streams {
            try stream.validate()
            if !seenIDs.insert(stream.streamID).inserted {
                throw VideoTransportValidationError.duplicateMultiVideoStreamID(stream.streamID)
            }
        }
        try requireTransportNonNegative(
            aggregateBandwidthMegabitsPerSecond,
            "multiVideo.aggregateBandwidthMegabitsPerSecond"
        )
        let pseudoStreams = streams.map { stream in
            VideoStreamDescription(
                id: stream.streamID,
                direction: stream.captureEnabled ? .send : .disabled,
                role: stream.captureEnabled ? .testPattern : .disabled,
                resolution: VideoResolution(width: 1, height: 1),
                frameRate: VideoFrameRate(numerator: 1, denominator: 1),
                pixelFormat: stream.captureEnabled ? .rgb24 : .disabled,
                transportFormat: stream.captureEnabled ? .rawFrameFragment : .disabled,
                sourceLabel: stream.sourceLabel,
                payloadType: .videoRawFrameFragment,
                priority: max(0, stream.priority),
                captureEnabled: stream.captureEnabled,
                queueDepth: max(0, stream.queueDepth),
                bandwidthBudgetMegabitsPerSecond: max(0, stream.bandwidthBudgetMegabitsPerSecond)
            )
        }
        try receiverSelection.validate(against: pseudoStreams)
    }
}

public struct MultiVideoDropDecision: Equatable, Sendable {
    public var acceptedStreamIDs: [Int]
    public var droppedStreamIDs: [Int]

    public init(acceptedStreamIDs: [Int], droppedStreamIDs: [Int]) {
        self.acceptedStreamIDs = acceptedStreamIDs
        self.droppedStreamIDs = droppedStreamIDs
    }
}

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
