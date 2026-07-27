// Implements VideoTransportReassembly media transport boundary, separating packet I/O from session policy.
import Dispatch
import Foundation

/// Owns incomplete-frame state and emits a video frame only after fragment consistency checks pass.
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
 // swiftlint:disable:next identifier_name
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
            try receiveLocked(fragment, receivedAt: DispatchTime.now().uptimeNanoseconds)
        }
    }

    public func receiveRaw(_ fragment: VideoTransportFragment) throws -> RawCapturedVideoFrame? {
        try withLockedState {
            try receiveRawLocked(fragment, receivedAt: DispatchTime.now().uptimeNanoseconds)
        }
    }

    #if DEBUG
    func receive(
        _ fragment: VideoTransportFragment,
        receivedAtNanosecondsForTesting receivedAt: UInt64
    ) throws -> VideoTransportPacket? {
        try withLockedState {
            try receiveLocked(fragment, receivedAt: receivedAt)
        }
    }
    #endif

    public func flushIncomplete() {
        withLockedState {
            for frame in activeFrames.values {
                dropActiveFrame(frame)
            }
            activeFrames.removeAll()
            resetActiveFrameOrder()
        }
    }
}

private extension VideoFrameReassembler {
    private func receiveLocked(
        _ fragment: VideoTransportFragment,
        receivedAt: UInt64
    ) throws -> VideoTransportPacket? {
        guard let key = try receiveBucketLocked(fragment, receivedAt: receivedAt) else {
            return nil
        }
        return try completedPacket(for: key)
    }

    private func receiveRawLocked(
        _ fragment: VideoTransportFragment,
        receivedAt: UInt64
    ) throws -> RawCapturedVideoFrame? {
        guard let key = try receiveBucketLocked(fragment, receivedAt: receivedAt) else {
            return nil
        }
        return try completedRawFrame(for: key)
    }

    private func receiveBucketLocked(
        _ fragment: VideoTransportFragment,
        receivedAt: UInt64
    ) throws -> VideoFrameReassemblyKey? {
        try fragment.validate()
        try validateFragmentBudget(fragment)
        dropExpiredActiveFrames(receivedAt: receivedAt)

        if rejectLateFragmentLocked(fragment) {
            return nil
        }

        let key = VideoFrameReassemblyKey(
            streamID: fragment.streamID,
            frameSequenceNumber: fragment.frameSequenceNumber
        )
        if try insertExistingBucketLocked(fragment, key: key) {
            return key
        }

        startBucketLocked(fragment, key: key, receivedAt: receivedAt)
        return key
    }

    private func rejectLateFragmentLocked(_ fragment: VideoTransportFragment) -> Bool {
        if let latestCompleted = latestCompletedFrameSequenceNumbersByStreamID[fragment.streamID],
           videoFrameSequenceIsLate(fragment.frameSequenceNumber, after: latestCompleted) {
            metricsStorage.lateFragments += 1
            return true
        }
        if hasNewerActiveFrameLocked(fragment) {
            metricsStorage.lateFragments += 1
            return true
        }
        return false
    }

    private func hasNewerActiveFrameLocked(_ fragment: VideoTransportFragment) -> Bool {
        activeFrames.keys.contains { key in
            key.streamID == fragment.streamID
                && videoFrameSequenceIsNewer(key.frameSequenceNumber, than: fragment.frameSequenceNumber)
        }
    }

    private func insertExistingBucketLocked(
        _ fragment: VideoTransportFragment,
        key: VideoFrameReassemblyKey
    ) throws -> Bool {
        guard var bucket = activeFrames[key] else {
            return false
        }
        let inserted = try bucket.insert(fragment)
        if !inserted {
            metricsStorage.duplicateFragments += 1
        }
        activeFrames[key] = bucket
        return true
    }

    private func startBucketLocked(
        _ fragment: VideoTransportFragment,
        key: VideoFrameReassemblyKey,
        receivedAt: UInt64
    ) {
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
