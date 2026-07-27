// Implements RealtimeAudioFixedTargetJitterBuffer bounded buffering, isolating real-time ownership rules from audio and network loops.
import Foundation

/// Names queueing outcomes that preserve a fixed playout target under callback pressure.
public enum RealtimeAudioFixedTargetQueueResult: Equatable, Sendable {
    case queued
    case droppedLate
    case droppedFull
    case droppedDuplicate
    case droppedInvalid
}

/// Classifies fixed-target playout as decoded audio, same-deadline concealment, or silence.
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

/// Holds due blocks against a fixed target while making late, PLC, and silence outcomes explicit.
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

        packetSlots[slot] = jitterBufferPacket(
            packet,
            playoutFrame: playoutFrame,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
        bufferedPackets += 1
        updateMaximumBufferedBlocks()
        return .queued
    }

    private func jitterBufferPacket(
        _ packet: UdpPcmPacket,
        playoutFrame: UInt64,
        receivedAtHostTimeNanoseconds: UInt64
    ) -> RealtimeAudioJitterBufferPacket {
        RealtimeAudioJitterBufferPacket(
            packet: packet,
            playoutFrame: playoutFrame,
            packetAgeMicroseconds: packetAgeMicroseconds(
                senderHostTimeNanoseconds: packet.header.senderHostTimeNanoseconds,
                receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
            )
        )
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
