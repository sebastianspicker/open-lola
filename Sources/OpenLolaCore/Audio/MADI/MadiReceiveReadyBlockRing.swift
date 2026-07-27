// Implements MadiReceiveReadyBlockRing bounded buffering, isolating real-time ownership rules from audio and network loops.
import Foundation

struct MadiReceiveReadyBlockRing: Sendable {
    private var storage: [MadiReceivePlayoutBlock?]
    private let framesPerBlock: Int
    private var storedCount = 0

    var count: Int {
        storedCount
    }

    init(capacity: Int, framesPerBlock: Int) throws {
        guard capacity > 0 else {
            throw MadiReceiveError.nonPositiveField("preallocatedBlockCount")
        }
        guard framesPerBlock > 0 else {
            throw MadiReceiveError.nonPositiveField("framesPerBlock")
        }
        self.storage = Array(repeating: nil, count: capacity)
        self.framesPerBlock = framesPerBlock
    }

    func contains(playoutFrame: UInt64) -> Bool {
        storage[storageIndex(for: playoutFrame)]?.startFrame == playoutFrame
    }

    func accepts(playoutFrame: UInt64, nextDueFrame: UInt64) -> Bool {
        let horizonFrames = (storage.count + 1).multipliedReportingOverflow(by: framesPerBlock)
        guard !horizonFrames.overflow,
              let horizonFrameCount = UInt64(exactly: horizonFrames.partialValue) else {
            return false
        }
        let horizonEnd = nextDueFrame.addingReportingOverflow(horizonFrameCount)
        guard !horizonEnd.overflow else {
            return false
        }
        return playoutFrame <= horizonEnd.partialValue
    }

    mutating func store(
        _ block: MadiReceivePlayoutBlock,
        nextDueFrame: UInt64,
        overrunPolicy: MadiReceiveOverrunPolicy
    ) -> MadiReceiveReadyBlockStoreResult {
        guard accepts(playoutFrame: block.startFrame, nextDueFrame: nextDueFrame) else {
            return .droppedFuture
        }
        let index = storageIndex(for: block.startFrame)
        if storage[index] == nil {
            storage[index] = block
            storedCount += 1
            return .stored
        }

        switch overrunPolicy {
        case .dropNewest:
            return .droppedNewest
        case .dropOldest:
            guard let droppedBlock = storage[index] else {
                storage[index] = block
                storedCount += 1
                return .stored
            }
            storage[index] = block
            return .droppedOldest(droppedBlock)
        }
    }

    mutating func remove(playoutFrame: UInt64) -> MadiReceivePlayoutBlock? {
        let index = storageIndex(for: playoutFrame)
        guard storage[index]?.startFrame == playoutFrame else {
            return nil
        }
        let block = storage[index]
        storage[index] = nil
        storedCount -= 1
        return block
    }

    private func storageIndex(for playoutFrame: UInt64) -> Int {
        Int((playoutFrame / UInt64(framesPerBlock)) % UInt64(storage.count))
    }
}

func readInt16(_ bytes: UnsafeRawBufferPointer, offset: Int) throws -> Int16 {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("input.int16")
    }
    let source = baseAddress.assumingMemoryBound(to: UInt8.self)
    return Int16(bitPattern: UInt16(source[offset]) | UInt16(source[offset + 1]) << 8)
}

func readInt16(_ bytes: UnsafeMutableBufferPointer<UInt8>, offset: Int) throws -> Int16 {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("output.int16")
    }
    return Int16(bitPattern: UInt16(baseAddress[offset]) | UInt16(baseAddress[offset + 1]) << 8)
}

func writeInt16(
    _ value: Int16,
    to bytes: inout UnsafeMutableBufferPointer<UInt8>,
    offset: Int
) {
    let bitPattern = UInt16(bitPattern: value)
    bytes[offset] = UInt8(bitPattern & 0xFF)
    bytes[offset + 1] = UInt8((bitPattern >> 8) & 0xFF)
}

func readFloat32(_ bytes: UnsafeRawBufferPointer, offset: Int) throws -> Float {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("input.float32")
    }
    let source = baseAddress.assumingMemoryBound(to: UInt8.self)
    let bitPattern = UInt32(source[offset])
        | UInt32(source[offset + 1]) << 8
        | UInt32(source[offset + 2]) << 16
        | UInt32(source[offset + 3]) << 24
    return Float(bitPattern: bitPattern)
}

func readFloat32(_ bytes: UnsafeMutableBufferPointer<UInt8>, offset: Int) throws -> Float {
    guard let baseAddress = bytes.baseAddress else {
        throw MadiReceiveError.audioBufferBaseAddressUnavailable("output.float32")
    }
    let bitPattern = UInt32(baseAddress[offset])
        | UInt32(baseAddress[offset + 1]) << 8
        | UInt32(baseAddress[offset + 2]) << 16
        | UInt32(baseAddress[offset + 3]) << 24
    return Float(bitPattern: bitPattern)
}

func writeFloat32(
    _ value: Float,
    to bytes: inout UnsafeMutableBufferPointer<UInt8>,
    offset: Int
) {
    let bitPattern = value.bitPattern
    bytes[offset] = UInt8(bitPattern & 0xFF)
    bytes[offset + 1] = UInt8((bitPattern >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((bitPattern >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((bitPattern >> 24) & 0xFF)
}
