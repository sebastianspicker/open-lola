// Implements RealtimeAudioPayloadCaptureRing bounded buffering, isolating real-time ownership rules from audio and network loops.
import CoreAudio
import Darwin
import Foundation

enum RealtimeAudioCaptureCopyKind: Sendable {
    case silent
    case direct
    case remapped
    case invalid
}

struct RealtimeAudioCapturePushResult: Sendable {
    var result: RealtimeAudioRingPushResult
    var copyKind: RealtimeAudioCaptureCopyKind
}

struct RealtimeAudioCapturedPayload: Sendable {
    var block: RealtimeAudioFrameBlock
    var payload: Data
}

struct RealtimeAudioBufferListReader {
    private let pointer: UnsafePointer<AudioBufferList>

    var count: Int {
        Int(pointer.pointee.mNumberBuffers)
    }

    init(_ pointer: UnsafePointer<AudioBufferList>) {
        self.pointer = pointer
    }

    subscript(index: Int) -> AudioBuffer? {
        guard index >= 0 && index < count,
              let bufferOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers) else {
            return nil
        }
        return UnsafeRawPointer(pointer)
            .advanced(by: bufferOffset)
            .advanced(by: index * MemoryLayout<AudioBuffer>.stride)
            .assumingMemoryBound(to: AudioBuffer.self)
            .pointee
    }
}

struct RealtimeAudioPayloadCaptureRing: Sendable {
    private var blocks: [RealtimeAudioFrameBlock?]
    private var payloadStorage: [UInt8]
    private var readIndex = 0
    private var writeIndex = 0
    private let shape: RealtimeAudioPayloadShape
    private let inputChannelMap: [Int]
    private let inputChannelMapIsUnique: Bool
    private let directInterleavedInput: Bool

    public private(set) var count = 0
    public private(set) var droppedBlocks = 0

    private var capacity: Int {
        blocks.count
    }

    init(
        capacity: Int,
        shape: RealtimeAudioPayloadShape,
        inputChannelMap: [Int]
    ) {
        precondition(capacity > 0, "RealtimeAudioPayloadCaptureRing capacity must be positive")
        precondition(shape.byteCount > 0, "RealtimeAudioPayloadCaptureRing payload must be positive")
        precondition(
            capacity <= Int.max / shape.byteCount,
            "RealtimeAudioPayloadCaptureRing storage size must not overflow"
        )
        precondition(
            Set(inputChannelMap).count == inputChannelMap.count,
            "RealtimeAudioPayloadCaptureRing inputChannelMap must be unique"
        )
        self.blocks = Array(repeating: nil, count: capacity)
        self.payloadStorage = Array(repeating: 0, count: capacity * shape.byteCount)
        self.shape = shape
        self.inputChannelMap = inputChannelMap
        self.inputChannelMapIsUnique = Set(inputChannelMap).count == inputChannelMap.count
        self.directInterleavedInput = inputChannelMap == Array(0..<shape.channelCount)
    }

    mutating func pushSilence(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> RealtimeAudioCapturePushResult {
        guard beginWrite() else {
            return droppedFull()
        }
        guard zeroPayloadSlot(at: writeIndex) else {
            return invalidDrop()
        }
        commitWrite(startFrame: startFrame, hostTimeNanoseconds: hostTimeNanoseconds)
        return RealtimeAudioCapturePushResult(result: .stored, copyKind: .silent)
    }

    mutating func pushInterleaved(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        sourceChannelCount: Int,
        sourceBytes: UnsafeRawBufferPointer
    ) -> RealtimeAudioCapturePushResult {
        guard beginWrite() else {
            return droppedFull()
        }
        guard validInterleavedSource(
            sourceChannelCount: sourceChannelCount,
            sourceByteCount: sourceBytes.count
        ), let sourceBaseAddress = sourceBytes.baseAddress else {
            return invalidDrop()
        }

        let targetStart = writeIndex * shape.byteCount
        let copyKind: RealtimeAudioCaptureCopyKind = directInterleavedCopy(sourceChannelCount: sourceChannelCount)
            ? .direct
            : .remapped
        var copied = false
        payloadStorage.withUnsafeMutableBufferPointer { destination in
            guard let destinationBaseAddress = destination.baseAddress else {
                return
            }
            let destinationBase = destinationBaseAddress.advanced(by: targetStart)
            if copyKind == .direct {
                memcpy(destinationBase, sourceBaseAddress, shape.byteCount)
                copied = true
            } else {
                copied = Self.copySelectedInterleavedChannels(
                    sourceBase: sourceBaseAddress,
                    destinationBase: destinationBase,
                    sourceChannelCount: sourceChannelCount,
                    shape: shape,
                    inputChannelMap: inputChannelMap
                )
            }
        }
        guard copied else {
            return invalidDrop()
        }
        commitWrite(startFrame: startFrame, hostTimeNanoseconds: hostTimeNanoseconds)
        return RealtimeAudioCapturePushResult(result: .stored, copyKind: copyKind)
    }

    mutating func pushAudioBuffers(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        inputBuffers: RealtimeAudioBufferListReader
    ) -> RealtimeAudioCapturePushResult {
        guard inputBuffers.count > 0 else {
            return invalidDrop()
        }
        if inputBuffers.count == 1,
           let inputBuffer = inputBuffers[0],
           let data = inputBuffer.mData {
            return pushInterleaved(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceChannelCount: Int(inputBuffer.mNumberChannels),
                sourceBytes: UnsafeRawBufferPointer(
                    start: data,
                    count: Int(inputBuffer.mDataByteSize)
                )
            )
        }
        guard beginWrite() else {
            return droppedFull()
        }

        let targetStart = writeIndex * shape.byteCount
        var copied = false
        payloadStorage.withUnsafeMutableBufferPointer { destination in
            guard let destinationBaseAddress = destination.baseAddress else {
                return
            }
            copied = Self.copySelectedAudioBuffers(
                inputBuffers,
                destinationBase: destinationBaseAddress.advanced(by: targetStart),
                shape: shape,
                inputChannelMap: inputChannelMap
            )
        }
        guard copied else {
            return invalidDrop()
        }
        commitWrite(startFrame: startFrame, hostTimeNanoseconds: hostTimeNanoseconds)
        return RealtimeAudioCapturePushResult(result: .stored, copyKind: .remapped)
    }

    mutating func pop() -> RealtimeAudioCapturedPayload? {
        withPoppedPayload { block, payloadBytes in
            guard let baseAddress = payloadBytes.baseAddress else {
                return RealtimeAudioCapturedPayload(block: block, payload: Data())
            }
            return RealtimeAudioCapturedPayload(
                block: block,
                payload: Data(bytes: baseAddress, count: payloadBytes.count)
            )
        }
    }

    mutating func popPayload(into destination: inout Data) -> RealtimeAudioFrameBlock? {
        withPoppedPayload { block, payloadBytes in
            destination.removeAll(keepingCapacity: true)
            if let baseAddress = payloadBytes.baseAddress {
                destination.append(
                    contentsOf: UnsafeBufferPointer(
                        start: baseAddress.assumingMemoryBound(to: UInt8.self),
                        count: payloadBytes.count
                    )
                )
            }
            return block
        }
    }

    mutating func withPoppedPayload<Result>(
        _ body: (RealtimeAudioFrameBlock, UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result? {
        guard count > 0, let block = blocks[readIndex] else {
            return nil
        }
        let payloadStart = readIndex * shape.byteCount
        defer {
            blocks[readIndex] = nil
            readIndex = (readIndex + 1) % capacity
            count -= 1
        }
        return try payloadStorage.withUnsafeBufferPointer { storage in
            guard let baseAddress = storage.baseAddress else {
                return try body(block, UnsafeRawBufferPointer(start: nil, count: 0))
            }
            return try body(
                block,
                UnsafeRawBufferPointer(
                    start: baseAddress.advanced(by: payloadStart),
                    count: shape.byteCount
                )
            )
        }
    }

    private mutating func beginWrite() -> Bool {
        guard count < capacity else {
            droppedBlocks += 1
            return false
        }
        return true
    }

    private mutating func commitWrite(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) {
        blocks[writeIndex] = RealtimeAudioFrameBlock(
            startFrame: startFrame,
            frameCount: shape.frameCount,
            payloadByteCount: shape.byteCount,
            hostTimeNanoseconds: hostTimeNanoseconds
        )
        writeIndex = (writeIndex + 1) % capacity
        count += 1
    }

    private mutating func droppedFull() -> RealtimeAudioCapturePushResult {
        RealtimeAudioCapturePushResult(result: .droppedFull, copyKind: .invalid)
    }

    private func invalidDrop() -> RealtimeAudioCapturePushResult {
        RealtimeAudioCapturePushResult(result: .droppedInvalid, copyKind: .invalid)
    }

    private mutating func zeroPayloadSlot(at index: Int) -> Bool {
        let targetStart = index * shape.byteCount
        var cleared = false
        payloadStorage.withUnsafeMutableBufferPointer { destination in
            guard let baseAddress = destination.baseAddress else {
                return
            }
            memset(baseAddress.advanced(by: targetStart), 0, shape.byteCount)
            cleared = true
        }
        return cleared
    }

    private func validInterleavedSource(
        sourceChannelCount: Int,
        sourceByteCount: Int
    ) -> Bool {
        guard sourceChannelCount > 0 else {
            return false
        }
        let requiredBytes = shape.frameCount
            * sourceChannelCount
            * shape.sampleFormat.bytesPerSample
        return sourceByteCount == requiredBytes
            && inputChannelMap.allSatisfy { $0 >= 0 && $0 < sourceChannelCount }
            && inputChannelMapIsUnique
    }

    private func directInterleavedCopy(sourceChannelCount: Int) -> Bool {
        // Caller has already validated sourceChannelCount > 0; this helper only decides
        // whether the validated source layout can be copied as one contiguous payload.
        sourceChannelCount == shape.channelCount
            && directInterleavedInput
    }

}
