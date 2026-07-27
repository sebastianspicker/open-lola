// Implements VideoTransportReassemblyMetrics media transport boundary, separating packet I/O from session policy.
import Foundation

/// Tracks `framesFragmented`, `fragmentsSent`, `maxFragmentsPerFrame`, and `maxPayloadBytesPerFragment` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
public struct VideoFragmentationMetrics: Codable, Equatable, Sendable {
    public var framesFragmented: Int
    public var fragmentsSent: Int
    public var maxFragmentsPerFrame: Int
    public var maxPayloadBytesPerFragment: Int

    public init(
        framesFragmented: Int,
        fragmentsSent: Int,
        maxFragmentsPerFrame: Int,
        maxPayloadBytesPerFragment: Int
    ) {
        self.framesFragmented = framesFragmented
        self.fragmentsSent = fragmentsSent
        self.maxFragmentsPerFrame = maxFragmentsPerFrame
        self.maxPayloadBytesPerFragment = maxPayloadBytesPerFragment
    }
}

/// Tracks `framesReassembled`, `framesDroppedIncomplete`, `missingFragments`, and `lateFragments` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
public struct VideoReassemblyMetrics: Codable, Equatable, Sendable {
    public var framesReassembled: Int
    public var framesDroppedIncomplete: Int
    public var missingFragments: Int
    public var lateFragments: Int
    public var duplicateFragments: Int
    public var activeFramesPeak: Int

    public init(
        framesReassembled: Int,
        framesDroppedIncomplete: Int,
        missingFragments: Int,
        lateFragments: Int,
        duplicateFragments: Int = 0,
        activeFramesPeak: Int = 0
    ) {
        self.framesReassembled = framesReassembled
        self.framesDroppedIncomplete = framesDroppedIncomplete
        self.missingFragments = missingFragments
        self.lateFragments = lateFragments
        self.duplicateFragments = duplicateFragments
        self.activeFramesPeak = activeFramesPeak
    }

    enum CodingKeys: String, CodingKey {
        case framesReassembled
        case framesDroppedIncomplete
        case missingFragments
        case lateFragments
        case duplicateFragments
        case activeFramesPeak
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        framesReassembled = try container.decode(Int.self, forKey: .framesReassembled)
        framesDroppedIncomplete = try container.decode(Int.self, forKey: .framesDroppedIncomplete)
        missingFragments = try container.decode(Int.self, forKey: .missingFragments)
        lateFragments = try container.decode(Int.self, forKey: .lateFragments)
        duplicateFragments = try container.decodeIfPresent(Int.self, forKey: .duplicateFragments) ?? 0
        activeFramesPeak = try container.decodeIfPresent(Int.self, forKey: .activeFramesPeak) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(framesReassembled, forKey: .framesReassembled)
        try container.encode(framesDroppedIncomplete, forKey: .framesDroppedIncomplete)
        try container.encode(missingFragments, forKey: .missingFragments)
        try container.encode(lateFragments, forKey: .lateFragments)
        try container.encode(duplicateFragments, forKey: .duplicateFragments)
        try container.encode(activeFramesPeak, forKey: .activeFramesPeak)
    }
}

/// Groups `maxDepth` into the public LatestVideoFrameReceiver contract used by video transport.
public struct LatestVideoFrameReceiver: Equatable, Sendable {
    public var maxDepth: Int
    public private(set) var packets: [VideoTransportPacket]
    public private(set) var droppedFrames: Int
    public private(set) var observedQueueDepth: Int
    public private(set) var observedQueueDepthByStreamID: [UInt32: Int]

    public init(maxDepth: Int) {
        self.maxDepth = maxDepth
        packets = []
        droppedFrames = 0
        observedQueueDepth = 0
        observedQueueDepthByStreamID = [:]
    }

    public mutating func receive(_ packet: VideoTransportPacket) {
        guard maxDepth > 0 else {
            droppedFrames += 1
            packets.removeAll()
            observedQueueDepth = 0
            return
        }

        packets.append(packet)
        if packets.count > maxDepth {
            let dropCount = packets.count - maxDepth
            packets.removeFirst(dropCount)
            droppedFrames += dropCount
        }
        observedQueueDepth = max(observedQueueDepth, packets.count)
        let streamDepth = packets.reduce(0) { depth, queued in
            queued.streamID == packet.streamID ? depth + 1 : depth
        }
        observedQueueDepthByStreamID[packet.streamID] = max(
            observedQueueDepthByStreamID[packet.streamID] ?? 0,
            streamDepth
        )
    }
}
