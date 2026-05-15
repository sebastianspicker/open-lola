import Dispatch
import Foundation

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
        self.init(
            framesReassembled: try container.decode(Int.self, forKey: .framesReassembled),
            framesDroppedIncomplete: try container.decode(Int.self, forKey: .framesDroppedIncomplete),
            missingFragments: try container.decode(Int.self, forKey: .missingFragments),
            lateFragments: try container.decode(Int.self, forKey: .lateFragments),
            duplicateFragments: try container.decodeIfPresent(Int.self, forKey: .duplicateFragments) ?? 0,
            activeFramesPeak: try container.decodeIfPresent(Int.self, forKey: .activeFramesPeak) ?? 0
        )
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

public final class VideoFrameReassembler: Equatable, @unchecked Sendable {
    public var maxActiveFrames: Int {
        get { withLockedState { maxActiveFramesStorage } }
        set { withLockedState { maxActiveFramesStorage = max(1, newValue) } }
    }
    public var maxFrameAgeNanoseconds: UInt64 {
        get { withLockedState { maxFrameAgeNanosecondsStorage } }
        set { withLockedState { maxFrameAgeNanosecondsStorage = newValue } }
    }
    public var maxFragmentsPerFrame: Int {
        get { withLockedState { maxFragmentsPerFrameStorage } }
        set { withLockedState { maxFragmentsPerFrameStorage = max(1, newValue) } }
    }
    public var metrics: VideoReassemblyMetrics {
        withLockedState { metricsStorage }
    }
    private let lock = NSLock()
    private var maxActiveFramesStorage: Int
    private var maxFrameAgeNanosecondsStorage: UInt64
    private var maxFragmentsPerFrameStorage: Int
    private var metricsStorage: VideoReassemblyMetrics
    private var activeFrames: [VideoFrameReassemblyKey: VideoFrameReassemblyBucket]
    private var activeFrameOrder: [VideoFrameReassemblyKey]
    private var activeFrameOrderCursor: Int
    private var latestCompletedFrameSequenceNumbersByStreamID: [UInt32: UInt64]

    public init(
        maxActiveFrames: Int = 4,
        maxFrameAgeNanoseconds: UInt64 = 250_000_000,
        maxFragmentsPerFrame: Int = 8_192
    ) {
        maxActiveFramesStorage = max(1, maxActiveFrames)
        maxFrameAgeNanosecondsStorage = maxFrameAgeNanoseconds
        maxFragmentsPerFrameStorage = max(1, maxFragmentsPerFrame)
        metricsStorage = VideoReassemblyMetrics(
            framesReassembled: 0,
            framesDroppedIncomplete: 0,
            missingFragments: 0,
            lateFragments: 0,
            duplicateFragments: 0,
            activeFramesPeak: 0
        )
        activeFrames = [:]
        activeFrameOrder = []
        activeFrameOrderCursor = 0
        latestCompletedFrameSequenceNumbersByStreamID = [:]
    }

    public static func == (lhs: VideoFrameReassembler, rhs: VideoFrameReassembler) -> Bool {
        lhs === rhs
    }

    public func receive(_ fragment: VideoTransportFragment) throws -> VideoTransportPacket? {
        try withLockedState {
            try receiveLocked(fragment)
        }
    }

    public func receiveRaw(_ fragment: VideoTransportFragment) throws -> RawCapturedVideoFrame? {
        try withLockedState {
            try receiveRawLocked(fragment)
        }
    }

    public func flushIncomplete() {
        withLockedState {
            for frame in activeFrames.values {
                dropActiveFrame(frame)
            }
            activeFrames.removeAll()
            resetActiveFrameOrder()
        }
    }

    private func receiveLocked(_ fragment: VideoTransportFragment) throws -> VideoTransportPacket? {
        guard let key = try receiveBucketLocked(fragment) else {
            return nil
        }
        return try completedPacket(for: key)
    }

    private func receiveRawLocked(_ fragment: VideoTransportFragment) throws -> RawCapturedVideoFrame? {
        guard let key = try receiveBucketLocked(fragment) else {
            return nil
        }
        return try completedRawFrame(for: key)
    }

    private func receiveBucketLocked(
        _ fragment: VideoTransportFragment
    ) throws -> VideoFrameReassemblyKey? {
        let receivedAt = DispatchTime.now().uptimeNanoseconds
        try fragment.validate()
        try validateFragmentBudget(fragment)
        dropExpiredActiveFrames(receivedAt: receivedAt)

        if let latestCompletedFrameSequenceNumber = latestCompletedFrameSequenceNumbersByStreamID[fragment.streamID],
           videoFrameSequenceIsLate(
               fragment.frameSequenceNumber,
               after: latestCompletedFrameSequenceNumber
           ) {
            metricsStorage.lateFragments += 1
            return nil
        }
        if activeFrames.keys.contains(where: { key in
            key.streamID == fragment.streamID
                && videoFrameSequenceIsNewer(key.frameSequenceNumber, than: fragment.frameSequenceNumber)
        }) {
            metricsStorage.lateFragments += 1
            return nil
        }

        let key = VideoFrameReassemblyKey(
            streamID: fragment.streamID,
            frameSequenceNumber: fragment.frameSequenceNumber
        )
        if var bucket = activeFrames[key] {
            let inserted = try bucket.insert(fragment)
            if !inserted {
                metricsStorage.duplicateFragments += 1
            }
            activeFrames[key] = bucket
            return key
        }

        dropOlderIncompleteFrames(
            streamID: fragment.streamID,
            before: fragment.frameSequenceNumber
        )
        while activeFrames.count >= maxActiveFramesStorage {
            dropOldestActiveFrame()
        }

        let bucket = VideoFrameReassemblyBucket(firstFragment: fragment, firstFragmentReceivedAt: receivedAt)
        activeFrames[key] = bucket
        activeFrameOrder.append(key)
        metricsStorage.activeFramesPeak = max(metricsStorage.activeFramesPeak, activeFrames.count)
        return key
    }

    private func completedPacket(
        for key: VideoFrameReassemblyKey
    ) throws -> VideoTransportPacket? {
        guard let bucket = activeFrames[key],
              let completed = try bucket.completedPacket() else {
            return nil
        }
        metricsStorage.framesReassembled += 1
        recordCompletedFrameSequenceNumber(completed.sequenceNumber, streamID: completed.streamID)
        activeFrames.removeValue(forKey: key)
        removeActiveFrameOrderKey(key)
        resetActiveFrameOrderIfEmpty()
        return completed
    }

    private func completedRawFrame(
        for key: VideoFrameReassemblyKey
    ) throws -> RawCapturedVideoFrame? {
        guard let bucket = activeFrames[key],
              let completed = try bucket.completedRawFrame() else {
            return nil
        }
        metricsStorage.framesReassembled += 1
        recordCompletedFrameSequenceNumber(
            completed.metadata.sequenceNumber,
            streamID: completed.metadata.streamID
        )
        activeFrames.removeValue(forKey: key)
        removeActiveFrameOrderKey(key)
        resetActiveFrameOrderIfEmpty()
        return completed
    }

    private func recordCompletedFrameSequenceNumber(_ sequenceNumber: UInt64, streamID: UInt32) {
        if let latestCompletedFrameSequenceNumber = latestCompletedFrameSequenceNumbersByStreamID[streamID],
           !videoFrameSequenceIsNewer(sequenceNumber, than: latestCompletedFrameSequenceNumber) {
            return
        }
        latestCompletedFrameSequenceNumbersByStreamID[streamID] = sequenceNumber
    }

    private func dropActiveFrame(_ frame: VideoFrameReassemblyBucket) {
        metricsStorage.framesDroppedIncomplete += 1
        metricsStorage.missingFragments += frame.missingFragmentCount
    }

    private func validateFragmentBudget(_ fragment: VideoTransportFragment) throws {
        guard fragment.fragmentCount <= maxFragmentsPerFrameStorage else {
            throw VideoTransportFragmentError.invalidFragmentCount(fragment.fragmentCount)
        }
    }

    private func dropExpiredActiveFrames(receivedAt: UInt64) {
        guard maxFrameAgeNanosecondsStorage > 0 else {
            for frame in activeFrames.values {
                dropActiveFrame(frame)
            }
            activeFrames.removeAll()
            resetActiveFrameOrder()
            return
        }

        let expiredKeys = activeFrames.compactMap { key, frame -> VideoFrameReassemblyKey? in
            guard receivedAt >= frame.firstFragmentReceivedAt else {
                return nil
            }
            return receivedAt - frame.firstFragmentReceivedAt > maxFrameAgeNanosecondsStorage ? key : nil
        }
        for key in expiredKeys {
            if let frame = activeFrames.removeValue(forKey: key) {
                dropActiveFrame(frame)
            }
        }
        removeInactiveFrameOrderKeys()
        resetActiveFrameOrderIfEmpty()
    }

    private func dropOlderIncompleteFrames(
        streamID: UInt32,
        before frameSequenceNumber: UInt64
    ) {
        let staleKeys = activeFrames.keys.filter { key in
            key.streamID == streamID
                && videoFrameSequenceIsLate(key.frameSequenceNumber, after: frameSequenceNumber)
        }
        for key in staleKeys {
            if let frame = activeFrames.removeValue(forKey: key) {
                dropActiveFrame(frame)
            }
        }
        removeInactiveFrameOrderKeys()
        resetActiveFrameOrderIfEmpty()
    }

    private func dropOldestActiveFrame() {
        while activeFrameOrderCursor < activeFrameOrder.count {
            let key = activeFrameOrder[activeFrameOrderCursor]
            activeFrameOrderCursor += 1
            guard let frame = activeFrames.removeValue(forKey: key) else {
                continue
            }
            dropActiveFrame(frame)
            compactActiveFrameOrderIfNeeded()
            resetActiveFrameOrderIfEmpty()
            return
        }
        resetActiveFrameOrderIfEmpty()
    }

    private func resetActiveFrameOrderIfEmpty() {
        if activeFrames.isEmpty {
            resetActiveFrameOrder()
        }
    }

    private func resetActiveFrameOrder() {
        activeFrameOrder.removeAll(keepingCapacity: true)
        activeFrameOrderCursor = 0
    }

    private func removeInactiveFrameOrderKeys() {
        activeFrameOrder.removeAll { activeFrames[$0] == nil }
        activeFrameOrderCursor = min(activeFrameOrderCursor, activeFrameOrder.count)
    }

    private func removeActiveFrameOrderKey(_ key: VideoFrameReassemblyKey) {
        activeFrameOrder.removeAll { $0 == key }
        activeFrameOrderCursor = min(activeFrameOrderCursor, activeFrameOrder.count)
    }

    private func compactActiveFrameOrderIfNeeded() {
        guard activeFrameOrderCursor > 32,
              activeFrameOrderCursor > activeFrameOrder.count / 2 else {
            return
        }
        activeFrameOrder.removeFirst(activeFrameOrderCursor)
        activeFrameOrderCursor = 0
    }

    private func withLockedState<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

private struct VideoFrameReassemblyKey: Hashable, Sendable {
    var streamID: UInt32
    var frameSequenceNumber: UInt64
}

private let videoFrameSequenceHalfWindowThreshold = UInt64.max / 2

private func videoFrameSequenceIsLate(_ sequenceNumber: UInt64, after latestCompleted: UInt64) -> Bool {
    sequenceNumber == latestCompleted
        || (sequenceNumber &- latestCompleted) > videoFrameSequenceHalfWindowThreshold
}

private func videoFrameSequenceIsNewer(_ sequenceNumber: UInt64, than latestCompleted: UInt64) -> Bool {
    let forwardDistance = sequenceNumber &- latestCompleted
    return forwardDistance > 0 && forwardDistance <= videoFrameSequenceHalfWindowThreshold
}

private struct VideoFrameReassemblyBucket: Equatable, Sendable {
    var streamID: UInt32
    var frameSequenceNumber: UInt64
    var timestampNanoseconds: UInt64
    var timestampBasis: VideoTimestampBasis
    var sourceRole: VideoStreamRole
    var width: Int
    var height: Int
    var pixelFormat: String
    var frameRate: VideoFrameRate
    var framePayloadByteCount: Int
    var fragmentCount: Int
    var frameFingerprint: String
    var fragmentsByIndex: [Int: VideoTransportFragment]
    var firstFragmentReceivedAt: UInt64

    var missingFragmentCount: Int {
        max(0, fragmentCount - fragmentsByIndex.count)
    }

    init(firstFragment: VideoTransportFragment, firstFragmentReceivedAt: UInt64) {
        streamID = firstFragment.streamID
        frameSequenceNumber = firstFragment.frameSequenceNumber
        timestampNanoseconds = firstFragment.timestampNanoseconds
        timestampBasis = firstFragment.timestampBasis
        sourceRole = firstFragment.sourceRole
        width = firstFragment.width
        height = firstFragment.height
        pixelFormat = firstFragment.pixelFormat
        frameRate = firstFragment.frameRate
        framePayloadByteCount = firstFragment.framePayloadByteCount
        fragmentCount = firstFragment.fragmentCount
        frameFingerprint = firstFragment.frameFingerprint
        fragmentsByIndex = [firstFragment.fragmentIndex: firstFragment]
        self.firstFragmentReceivedAt = firstFragmentReceivedAt
    }

    mutating func insert(_ fragment: VideoTransportFragment) throws -> Bool {
        guard fragment.streamID == streamID,
              fragment.frameSequenceNumber == frameSequenceNumber,
              fragment.timestampNanoseconds == timestampNanoseconds,
              fragment.timestampBasis == timestampBasis,
              fragment.sourceRole == sourceRole,
              fragment.width == width,
              fragment.height == height,
              fragment.pixelFormat == pixelFormat,
              fragment.frameRate == frameRate,
              fragment.framePayloadByteCount == framePayloadByteCount,
              fragment.fragmentCount == fragmentCount,
              fragment.frameFingerprint == frameFingerprint else {
            throw VideoTransportFragmentError.inconsistentFrameMetadata
        }
        guard fragmentsByIndex[fragment.fragmentIndex] == nil else {
            return false
        }
        fragmentsByIndex[fragment.fragmentIndex] = fragment
        return true
    }

    func completedPacket() throws -> VideoTransportPacket? {
        guard fragmentsByIndex.count == fragmentCount else {
            return nil
        }

        var expectedPayloadOffset = 0
        for fragmentIndex in 0..<fragmentCount {
            guard let fragment = fragmentsByIndex[fragmentIndex] else {
                return nil
            }
            guard fragment.payloadOffset == expectedPayloadOffset else {
                throw VideoTransportFragmentError.fragmentOffsetMismatch(
                    expected: expectedPayloadOffset,
                    actual: fragment.payloadOffset
                )
            }
            expectedPayloadOffset += fragment.payloadByteCount
        }
        guard expectedPayloadOffset == framePayloadByteCount else {
            throw VideoTransportFragmentError.payloadLengthMismatch(
                expected: framePayloadByteCount,
                actual: expectedPayloadOffset
            )
        }

        return VideoTransportPacket(
            streamID: streamID,
            sequenceNumber: frameSequenceNumber,
            timestampNanoseconds: timestampNanoseconds,
            timestampBasis: timestampBasis,
            sourceRole: sourceRole,
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            frameRate: frameRate,
            payloadByteCount: framePayloadByteCount,
            frameFingerprint: frameFingerprint
        )
    }

    func completedRawFrame() throws -> RawCapturedVideoFrame? {
        guard let packet = try completedPacket() else {
            return nil
        }
        var payload = Data()
        payload.reserveCapacity(framePayloadByteCount)
        for fragmentIndex in 0..<fragmentCount {
            guard let fragment = fragmentsByIndex[fragmentIndex] else {
                return nil
            }
            payload.append(fragment.payload)
        }
        return RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: packet.streamID,
                sequenceNumber: packet.sequenceNumber,
                timestampNanoseconds: packet.timestampNanoseconds,
                timestampBasis: packet.timestampBasis,
                sourceRole: packet.sourceRole,
                width: packet.width,
                height: packet.height,
                pixelFormat: packet.pixelFormat,
                frameRate: packet.frameRate,
                fingerprint: packet.frameFingerprint
            ),
            payload: payload
        )
    }
}
