import Foundation

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

public enum RealtimeAudioRingPushResult: Equatable, Sendable {
    case stored
    case droppedLate
    case droppedFull
    case droppedAhead
    case droppedInvalid
}

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

public enum RealtimeAudioPlayoutResult: Equatable, Sendable {
    case played(RealtimeAudioFrameBlock)
    case silence(startFrame: UInt64, frameCount: Int)
}

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

public enum RealtimeAudioFixedTargetQueueResult: Equatable, Sendable {
    case queued
    case droppedLate
    case droppedFull
    case droppedDuplicate
    case droppedInvalid
}

public enum RealtimeAudioFixedTargetPlayoutResult: Equatable, Sendable {
    case played(block: RealtimeAudioFrameBlock, telemetry: DriftTelemetrySample)
    case sameDeadlinePlc(event: SameDeadlinePlcEvent, block: RealtimeAudioFrameBlock)
    case silence(startFrame: UInt64, frameCount: Int)
}

private struct RealtimeAudioJitterBufferPacket: Sendable {
    var packet: UdpPcmPacket
    var playoutFrame: UInt64
    var packetAgeMicroseconds: Double
}

public struct RealtimeAudioFixedTargetJitterBuffer: Sendable {
    private var packetSlots: [RealtimeAudioJitterBufferPacket?]
    private var nextFrame: UInt64
    private let mode: UdpPcmPacketMode
    private let framesPerBlock: Int
    private let playoutTargetFrames: Int
    private let capacityBlocks: Int
    private let plcPolicy: SameDeadlinePlcPolicy
    private var lastGoodBlock: RealtimeAudioFrameBlock?
    private var bufferedPackets = 0

    public private(set) var maximumBufferedBlocks = 0
    public private(set) var droppedLatePackets = 0
    public private(set) var droppedFullPackets = 0
    public private(set) var droppedDuplicatePackets = 0
    public private(set) var droppedInvalidPackets = 0
    public private(set) var packetAccountingUnderflows = 0
    public private(set) var hiddenPlayoutGrowthDetected = false

    public var nextDueFrame: UInt64 {
        nextFrame
    }

    public var bufferedBlockCount: Int {
        bufferedPackets
    }

    public init(
        mode: UdpPcmPacketMode,
        playoutTargetFrames: Int,
        capacityBlocks: Int,
        plcPolicy: SameDeadlinePlcPolicy,
        startFrame: UInt64 = 0
    ) {
        precondition(mode.framesPerPacket > 0, "framesPerPacket must be positive")
        precondition(playoutTargetFrames >= 0, "playoutTargetFrames must be non-negative")
        precondition(capacityBlocks > 0, "capacityBlocks must be positive")
        self.mode = mode
        self.framesPerBlock = mode.framesPerPacket
        self.playoutTargetFrames = playoutTargetFrames
        self.capacityBlocks = capacityBlocks
        self.plcPolicy = plcPolicy
        self.nextFrame = startFrame
        self.packetSlots = Array(repeating: nil, count: capacityBlocks)
    }

    public init(
        mode: UdpPcmPacketMode,
        rxBufferPolicy: RxBufferPolicy,
        plcPolicy: SameDeadlinePlcPolicy,
        startFrame: UInt64 = 0
    ) {
        precondition(rxBufferPolicy.framesPerPacket == mode.framesPerPacket)
        precondition(rxBufferPolicy.sampleRateHertz == mode.sampleRateHertz)
        self.init(
            mode: mode,
            playoutTargetFrames: rxBufferPolicy.targetFrames,
            capacityBlocks: max(1, rxBufferPolicy.maximumTargetPackets),
            plcPolicy: plcPolicy,
            startFrame: startFrame
        )
    }

    public mutating func enqueue(
        _ packet: UdpPcmPacket,
        receivedAtHostTimeNanoseconds: UInt64
    ) -> RealtimeAudioFixedTargetQueueResult {
        guard packet.matches(mode) else {
            droppedInvalidPackets += 1
            return .droppedInvalid
        }

        let targetFrameResult = packet.header.senderFrameIndex.addingReportingOverflow(UInt64(playoutTargetFrames))
        guard !targetFrameResult.overflow else {
            droppedInvalidPackets += 1
            return .droppedInvalid
        }
        let playoutFrame = targetFrameResult.partialValue
        guard playoutFrame >= nextFrame else {
            droppedLatePackets += 1
            return .droppedLate
        }
        dropStalePackets(before: nextFrame)
        let bufferedPacketsAfterStaleDrop = bufferedPackets
        let slot = slot(for: playoutFrame)
        if let existing = packetSlots[slot] {
            if existing.playoutFrame == playoutFrame {
                droppedDuplicatePackets += 1
                return .droppedDuplicate
            }
            droppedFullPackets += 1
            return .droppedFull
        }
        guard bufferedPacketsAfterStaleDrop < capacityBlocks else {
            droppedFullPackets += 1
            return .droppedFull
        }

        packetSlots[slot] = RealtimeAudioJitterBufferPacket(
            packet: packet,
            playoutFrame: playoutFrame,
            packetAgeMicroseconds: packetAgeMicroseconds(
                senderHostTimeNanoseconds: packet.header.senderHostTimeNanoseconds,
                receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
            )
        )
        bufferedPackets += 1
        updateMaximumBufferedBlocks()
        return .queued
    }

    public mutating func renderNextBlock() -> RealtimeAudioFixedTargetPlayoutResult {
        let dueFrame = nextFrame
        nextFrame &+= UInt64(framesPerBlock)

        dropStalePackets(before: dueFrame)
        guard dueFrame >= UInt64(playoutTargetFrames) else {
            return .silence(startFrame: dueFrame, frameCount: framesPerBlock)
        }
        let slot = slot(for: dueFrame)
        guard let queued = packetSlots[slot], queued.playoutFrame == dueFrame else {
            return .sameDeadlinePlc(
                event: plcEvent(dueFrame: dueFrame),
                block: plcBlock(dueFrame: dueFrame)
            )
        }
        packetSlots[slot] = nil
        if bufferedPackets > 0 {
            bufferedPackets -= 1
        } else {
            recordPacketAccountingUnderflow()
        }

        let receiverMediaFrame = dueFrame - UInt64(playoutTargetFrames)
        let block = RealtimeAudioFrameBlock(
            startFrame: dueFrame,
            frameCount: framesPerBlock,
            payloadByteCount: queued.packet.payload.count,
            hostTimeNanoseconds: queued.packet.header.senderHostTimeNanoseconds
        )
        let sample = DriftTelemetrySample(
            sequenceNumber: queued.packet.header.sequenceNumber,
            senderFrameIndex: Int(queued.packet.header.senderFrameIndex),
            receiverPlayoutFrameIndex: Int(receiverMediaFrame),
            driftFrames: Int(queued.packet.header.senderFrameIndex) - Int(receiverMediaFrame),
            packetAgeMicroseconds: queued.packetAgeMicroseconds
        )
        lastGoodBlock = block
        return .played(block: block, telemetry: sample)
    }

    private mutating func dropStalePackets(before dueFrame: UInt64) {
        var dropped = 0
        for index in packetSlots.indices {
            guard let packet = packetSlots[index], packet.playoutFrame < dueFrame else {
                continue
            }
            packetSlots[index] = nil
            dropped += 1
        }
        if dropped > 0 {
            if bufferedPackets >= dropped {
                bufferedPackets -= dropped
            } else {
                recordPacketAccountingUnderflow()
            }
            droppedLatePackets += dropped
            if bufferedPackets > capacityBlocks {
                hiddenPlayoutGrowthDetected = true
            }
        }
    }

    private func plcEvent(dueFrame: UInt64) -> SameDeadlinePlcEvent {
        SameDeadlinePlcEvent(
            dueFrameIndex: Int(dueFrame),
            missingSequenceNumber: missingSequenceNumber(dueFrame: dueFrame),
            policy: plcPolicy,
            waitedForRetransmission: false,
            playoutTargetFramesBefore: playoutTargetFrames,
            playoutTargetFramesAfter: playoutTargetFrames,
            branchBounded: true,
            notes: sameDeadlinePolicyNotes(plcPolicy)
        )
    }

    private func missingSequenceNumber(dueFrame: UInt64) -> UInt64 {
        let target = UInt64(playoutTargetFrames)
        guard dueFrame >= target else {
            return 0
        }
        return (dueFrame - target) / UInt64(framesPerBlock)
    }

    private func plcBlock(dueFrame: UInt64) -> RealtimeAudioFrameBlock {
        let payloadByteCount: Int
        let hostTimeNanoseconds: UInt64
        switch plcPolicy {
        case .repeatLastGoodBlock:
            payloadByteCount = lastGoodBlock?.payloadByteCount ?? mode.payloadByteCount
            hostTimeNanoseconds = lastGoodBlock?.hostTimeNanoseconds ?? 0
        case .silence, .boundedSubstitute:
            payloadByteCount = mode.payloadByteCount
            hostTimeNanoseconds = 0
        }

        return RealtimeAudioFrameBlock(
            startFrame: dueFrame,
            frameCount: framesPerBlock,
            payloadByteCount: payloadByteCount,
            hostTimeNanoseconds: hostTimeNanoseconds
        )
    }

    private mutating func updateMaximumBufferedBlocks() {
        maximumBufferedBlocks = max(maximumBufferedBlocks, bufferedPackets)
        if maximumBufferedBlocks > capacityBlocks {
            hiddenPlayoutGrowthDetected = true
        }
    }

    private mutating func recordPacketAccountingUnderflow() {
        packetAccountingUnderflows += 1
        bufferedPackets = 0
        hiddenPlayoutGrowthDetected = true
    }

    #if DEBUG
    mutating func setBufferedPacketCountForTesting(_ count: Int) {
        bufferedPackets = max(0, count)
    }

    mutating func setNextDueFrameForTesting(_ frame: UInt64) {
        nextFrame = frame
    }
    #endif

    private func slot(for playoutFrame: UInt64) -> Int {
        Int((playoutFrame / UInt64(framesPerBlock)) % UInt64(capacityBlocks))
    }

    private func packetAgeMicroseconds(
        senderHostTimeNanoseconds: UInt64,
        receivedAtHostTimeNanoseconds: UInt64
    ) -> Double {
        if receivedAtHostTimeNanoseconds < senderHostTimeNanoseconds {
            return -Double(senderHostTimeNanoseconds - receivedAtHostTimeNanoseconds) / 1_000
        }
        return Double(receivedAtHostTimeNanoseconds - senderHostTimeNanoseconds) / 1_000
    }
}
