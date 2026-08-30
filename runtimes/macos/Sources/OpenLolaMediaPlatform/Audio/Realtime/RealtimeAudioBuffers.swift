// Implements RealtimeAudioBuffers bounded buffering, isolating real-time ownership rules from audio and network loops.
import Foundation

/// Pairs `startFrame`, `frameCount`, `payloadByteCount`, and `hostTimeNanoseconds` with one playout block in the real-time audio path.
public struct RealtimeAudioFrameBlock: Codable, Equatable, Sendable {
    public let startFrame: UInt64
    public let frameCount: Int
    public let payloadByteCount: Int
    public let hostTimeNanoseconds: UInt64

    public init(
        startFrame: UInt64,
        frameCount: Int,
        payloadByteCount: Int,
        hostTimeNanoseconds: UInt64 = 0
    ) {
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.payloadByteCount = payloadByteCount
        self.hostTimeNanoseconds = hostTimeNanoseconds
    }
}

/// Groups `frameCount`, `channelCount`, `sampleFormat`, and `byteCount` into the public RealtimeAudioPayloadShape contract used by the real-time audio path.
public struct RealtimeAudioPayloadShape: Codable, Equatable, Sendable {
    public let frameCount: Int
    public let channelCount: Int
    public let sampleFormat: UdpPcmSampleFormat
    public let byteCount: Int

    public init(
        frameCount: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat
    ) throws {
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.byteCount = try validatedRealtimeAudioPayloadByteCount(
            frameCount: frameCount,
            channelCount: channelCount,
            bytesPerSample: sampleFormat.bytesPerSample
        )
    }

    public init(mode: UdpPcmPacketMode) throws {
        try self.init(
            frameCount: mode.framesPerPacket,
            channelCount: mode.channelCount,
            sampleFormat: mode.sampleFormat
        )
    }
}

func validatedRealtimeAudioPayloadByteCount(
    frameCount: Int,
    channelCount: Int,
    bytesPerSample: Int
) throws -> Int {
    try validatePositive(frameCount, "frameCount")
    try validatePositive(channelCount, "channelCount")
    try validatePositive(bytesPerSample, "bytesPerSample")
    let frameSamples = frameCount.multipliedReportingOverflow(by: channelCount)
    guard !frameSamples.overflow, frameSamples.partialValue > 0 else {
        throw RealtimeAudioBufferConfigurationError.payloadByteCountOverflow
    }
    let byteCount = frameSamples.partialValue.multipliedReportingOverflow(by: bytesPerSample)
    guard !byteCount.overflow, byteCount.partialValue > 0 else {
        throw RealtimeAudioBufferConfigurationError.payloadByteCountOverflow
    }
    return byteCount.partialValue
}

/// Names the outcome of inserting a block into the bounded real-time audio ring.
public enum RealtimeAudioRingPushResult: Equatable, Sendable {
    case stored
    case droppedLate
    case droppedFull
    case droppedAhead
    case droppedInvalid
}

/// Holds a fixed number of audio blocks so queue growth cannot inflate callback latency.
public struct RealtimeAudioBlockRing: Sendable {
    private var storage: [RealtimeAudioFrameBlock?]
    private var readIndex = 0
    private var writeIndex = 0

    public private(set) var count = 0
    public private(set) var droppedBlocks = 0

    public var capacity: Int {
        storage.count
    }

    public init(capacity: Int) {
        precondition(capacity > 0, "RealtimeAudioBlockRing capacity must be positive")
        self.storage = Array(repeating: nil, count: capacity)
    }

    public mutating func push(_ block: RealtimeAudioFrameBlock) -> RealtimeAudioRingPushResult {
        guard count < storage.count else {
            droppedBlocks += 1
            return .droppedFull
        }

        storage[writeIndex] = block
        writeIndex = (writeIndex + 1) % storage.count
        count += 1
        return .stored
    }

    public func peek() -> RealtimeAudioFrameBlock? {
        guard count > 0 else {
            return nil
        }
        return storage[readIndex]
    }

    public mutating func pop() -> RealtimeAudioFrameBlock? {
        guard count > 0 else {
            return nil
        }
        let block = storage[readIndex]
        storage[readIndex] = nil
        readIndex = (readIndex + 1) % storage.count
        count -= 1
        return block
    }
}

/// Distinguishes rendered audio from an intentional silence fallback in the callback path.
public enum RealtimeAudioPlayoutResult: Equatable, Sendable {
    case played(RealtimeAudioFrameBlock)
    case silence(startFrame: UInt64, frameCount: Int)
}

/// Groups `nextDueFrame`, `bufferedBlockCount`, and `droppedBlocks` into the public RealtimeAudioDueBlockPlayout contract used by the real-time audio path.
public struct RealtimeAudioDueBlockPlayout: Sendable {
    private var storage: [RealtimeAudioFrameBlock?]
    private var nextFrame: UInt64
    private let framesPerBlock: Int
    private var count = 0
    private var dropped = 0

    public var nextDueFrame: UInt64 {
        nextFrame
    }

    public var bufferedBlockCount: Int {
        count
    }

    public var droppedBlocks: Int {
        dropped
    }

    public init(startFrame: UInt64, framesPerBlock: Int, capacity: Int) {
        precondition(framesPerBlock > 0, "framesPerBlock must be positive")
        precondition(capacity > 0, "capacity must be positive")
        self.nextFrame = startFrame
        self.framesPerBlock = framesPerBlock
        self.storage = Array(repeating: nil, count: capacity)
    }

    public mutating func enqueue(_ block: RealtimeAudioFrameBlock) -> RealtimeAudioRingPushResult {
        guard block.startFrame >= nextFrame else {
            dropped += 1
            return .droppedLate
        }
        let windowFrames = storage.count.multipliedReportingOverflow(by: framesPerBlock)
        guard !windowFrames.overflow,
              let windowFrameCount = UInt64(exactly: windowFrames.partialValue) else {
            dropped += 1
            return .droppedAhead
        }
        let windowEnd = nextFrame.addingReportingOverflow(windowFrameCount)
        guard !windowEnd.overflow,
              block.startFrame < windowEnd.partialValue else {
            dropped += 1
            return .droppedAhead
        }
        let slot = slot(for: block.startFrame)
        guard storage[slot] == nil else {
            dropped += 1
            return .droppedFull
        }
        storage[slot] = block
        count += 1
        return .stored
    }

    public mutating func renderNextBlock() -> RealtimeAudioPlayoutResult {
        let dueFrame = nextFrame
        nextFrame += UInt64(framesPerBlock)
        let slot = slot(for: dueFrame)
        guard let block = storage[slot], block.startFrame == dueFrame else {
            return .silence(startFrame: dueFrame, frameCount: framesPerBlock)
        }
        storage[slot] = nil
        count -= 1
        return .played(block)
    }

    private func slot(for startFrame: UInt64) -> Int {
        Int((startFrame / UInt64(framesPerBlock)) % UInt64(storage.count))
    }
}
