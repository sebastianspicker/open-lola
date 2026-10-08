// Owns bounded decoded PCM conversion and scheduling before it reaches a realtime output graph.
import Foundation

/// Identifies the sample representation used by a decoded interleaved PCM block.
public enum DecodedInterleavedPCMSampleRepresentation: Equatable, Sendable {
    case float32LittleEndian
    case int16LittleEndian

    var bytesPerSample: Int { self == .float32LittleEndian ? 4 : 2 }
}

/// Carries one decoded interleaved PCM block before realtime playout conversion.
public struct DecodedInterleavedPCM: Equatable, Sendable {
    public var payload: Data
    public var sampleRateHertz: Int
    public var channels: Int
    public var representation: DecodedInterleavedPCMSampleRepresentation

    public init(payload: Data, sampleRateHertz: Int, channels: Int, representation: DecodedInterleavedPCMSampleRepresentation) {
        self.payload = payload
        self.sampleRateHertz = sampleRateHertz
        self.channels = channels
        self.representation = representation
    }
}

/// Describes malformed decoded audio that cannot be queued for playout.
public enum DecodedAudioPlayoutSinkError: Error, Equatable, Sendable {
    case invalidSampleRate(Int)
    case invalidChannelCount(Int)
    case malformedPayload
    case incompatibleChannels(expected: Int, actual: Int)
}

/// Records bounded decoded-audio playout counters for diagnostics.
public struct DecodedAudioPlayoutSinkSnapshot: Equatable, Sendable {
    public var receivedBlocks: Int
    public var queuedBlocks: Int
    public var droppedBlocks: Int
    public var underrunBlocks: Int
}

struct DecodedAudioPlayoutFrameAnchor {
    private(set) var nextFrame: UInt64?

    mutating func takeNextFrame(localOutputFrame: UInt64, frameCount: Int) -> UInt64 {
        let blockFrames = UInt64(max(1, frameCount))
        let earliestStart = saturatedDecodedAudioFrameSum(localOutputFrame, blockFrames)
        let startFrame = max(nextFrame ?? earliestStart, earliestStart)
        nextFrame = saturatedDecodedAudioFrameSum(startFrame, blockFrames)
        return startFrame
    }

    mutating func reset() { nextFrame = nil }
}

private func saturatedDecodedAudioFrameSum(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    lhs > UInt64.max - rhs ? UInt64.max : lhs + rhs
}

package protocol DecodedAudioPlayoutTarget: AnyObject {
    var nextOutputFrameForPlayout: UInt64 { get }
    var outputUnderrunBlocksForPlayout: Int { get }
    func queuePlayoutForDecodedAudio(_ payload: Data, startFrame: UInt64, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult
}

/// Reports whether a decoded PCM enqueue produced queued or dropped output blocks.
public struct DecodedAudioPlayoutEnqueueOutcome: Equatable, Sendable {
    public var queuedBlocks = 0
    public var droppedBlocks = 0

    public init(queuedBlocks: Int = 0, droppedBlocks: Int = 0) {
        self.queuedBlocks = queuedBlocks
        self.droppedBlocks = droppedBlocks
    }

    public var wasEntirelyDropped: Bool {
        queuedBlocks == 0 && droppedBlocks > 0
    }
}

extension DirectPeerRealtimeAudioGraph: DecodedAudioPlayoutTarget {
    package var nextOutputFrameForPlayout: UInt64 { nextOutputFrameSnapshot() }
    package var outputUnderrunBlocksForPlayout: Int { runtimeCounters().outputUnderrunBlocks }
    package func queuePlayoutForDecodedAudio(_ payload: Data, startFrame: UInt64, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        queuePlayoutPayload(payload, startFrame: startFrame, hostTimeNanoseconds: hostTimeNanoseconds)
    }
}

package final class DecodedAudioPlayoutSink: @unchecked Sendable {
    private let target: DecodedAudioPlayoutTarget
    private let outputRate: Int
    private let channels: Int
    private let framesPerBlock: Int
    private let lock = NSLock()
    private var accumulator: [Float] = []
    private var accumulatorHead = 0
    private var resamplers: [Int: LoLaLinearPCMResampler] = [:]
    private var frameAnchor = DecodedAudioPlayoutFrameAnchor()
    private var started = false
    private var receivedBlocks = 0
    private var queuedBlocks = 0
    private var droppedBlocks = 0

    package init(target: DecodedAudioPlayoutTarget, outputRate: Int, channels: Int, framesPerBlock: Int) {
        self.target = target
        self.outputRate = outputRate
        self.channels = channels
        self.framesPerBlock = framesPerBlock
    }

    package func start() {
        lock.lock()
        started = true
        lock.unlock()
    }

    package func stop() {
        lock.lock()
        started = false
        accumulator.removeAll(keepingCapacity: true)
        accumulatorHead = 0
        resamplers.removeAll(keepingCapacity: true)
        frameAnchor.reset()
        lock.unlock()
    }

    @discardableResult
    package func enqueue(
        _ block: DecodedInterleavedPCM,
        hostTimeNanoseconds: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome {
        let samples = try validatedFloats(block)
        lock.lock()
        defer { lock.unlock() }
        guard started else { return .init() }
        receivedBlocks += 1
        let resampler = resamplers[block.sampleRateHertz] ?? LoLaLinearPCMResampler(
            inputRate: block.sampleRateHertz, outputRate: outputRate, channels: channels
        )
        resamplers[block.sampleRateHertz] = resampler
        accumulator.append(contentsOf: resampler.appendAndProduce(samples))
        let required = framesPerBlock * channels
        var outcome = DecodedAudioPlayoutEnqueueOutcome()
        while accumulator.count - accumulatorHead >= required {
            let output = Array(accumulator[accumulatorHead..<(accumulatorHead + required)])
            accumulatorHead += required
            var candidateAnchor = frameAnchor
            let start = candidateAnchor.takeNextFrame(
                localOutputFrame: target.nextOutputFrameForPlayout,
                frameCount: framesPerBlock
            )
            if target.queuePlayoutForDecodedAudio(floatData(output), startFrame: start, hostTimeNanoseconds: hostTimeNanoseconds) == .stored {
                // Dropped blocks must not reserve future output time: advancing
                // the anchor on backpressure would turn each drop into silence.
                frameAnchor = candidateAnchor
                queuedBlocks += 1
                outcome.queuedBlocks += 1
            } else {
                droppedBlocks += 1
                outcome.droppedBlocks += 1
            }
        }
        if accumulatorHead == accumulator.count {
            accumulator.removeAll(keepingCapacity: true)
            accumulatorHead = 0
        } else if accumulatorHead >= 4_096 && accumulatorHead >= accumulator.count / 2 {
            accumulator.removeFirst(accumulatorHead)
            accumulatorHead = 0
        }
        return outcome
    }

    package var snapshot: DecodedAudioPlayoutSinkSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return .init(receivedBlocks: receivedBlocks, queuedBlocks: queuedBlocks, droppedBlocks: droppedBlocks, underrunBlocks: target.outputUnderrunBlocksForPlayout)
    }

    private func validatedFloats(_ block: DecodedInterleavedPCM) throws -> [Float] {
        guard block.sampleRateHertz > 0 else { throw DecodedAudioPlayoutSinkError.invalidSampleRate(block.sampleRateHertz) }
        guard block.channels > 0 else { throw DecodedAudioPlayoutSinkError.invalidChannelCount(block.channels) }
        guard block.channels == channels else { throw DecodedAudioPlayoutSinkError.incompatibleChannels(expected: channels, actual: block.channels) }
        guard block.payload.count.isMultiple(of: block.representation.bytesPerSample * block.channels) else { throw DecodedAudioPlayoutSinkError.malformedPayload }
        switch block.representation {
        case .float32LittleEndian:
            return block.payload.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        case .int16LittleEndian:
            return interleavedFloatData(fromInt16LittleEndian: block.payload)
        }
    }

    private func floatData(_ samples: [Float]) -> Data {
        var samples = samples
        return samples.withUnsafeMutableBytes { Data($0) }
    }
}
