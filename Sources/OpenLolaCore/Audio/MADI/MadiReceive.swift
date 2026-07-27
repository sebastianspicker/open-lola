// Handles MadiReceive receive-side processing, isolating input handling from compatibility and report policy.
import Foundation

struct MadiReceiveInitializationState {
    var rxBufferPolicy: RxBufferPolicy
    var mixStore: ReceiverMixSnapshotStore
    var outputChannelCount: Int
}

struct MadiReceivePacketTiming {
    var playoutFrame: UInt64
    var packetAgeMicroseconds: Double?
}

enum MadiReceivePacketReception {
    case proceed(MadiReceivePacketTiming)
    case finished(MadiReceivePacketResult)

    var timing: MadiReceivePacketTiming? {
        if case .proceed(let timing) = self {
            return timing
        }
        return nil
    }

    var result: MadiReceivePacketResult? {
        if case .finished(let result) = self {
            return result
        }
        return nil
    }
}

enum MadiReceivePendingPacketState {
    case waiting(MadiReceivePacketResult)
    case complete(MadiReceiveCompletedPendingPacket)
}

struct MadiReceiveCompletedPendingPacket {
    var reassembled: UdpPcmV2ReassemblyResult
    var receivedFragmentCount: Int
    var expectedFragmentCount: Int
}

struct MadiReceiveSampleMixContext {
    var frame: Int
    var mode: AudioTransportMode
    var outputChannelCount: Int
}

struct MadiReceiveSampleMixRequest {
    var sourceChannelIndex: Int
    var destinationChannelIndex: Int
    var gain: Double
    var context: MadiReceiveSampleMixContext
}

/// Owns MADI reassembly, playout deadlines, mixing, and receive-buffer state for a running receiver.
public struct MadiReceiveEngine: Sendable {
    public static let maxPendingDeadlines = 8

    let mode: AudioTransportMode
    let rxBufferPolicy: RxBufferPolicy
    var currentTargetFrames: Int
    var adaptiveRxBufferController: RxBufferAdaptiveController?
    let mixStore: ReceiverMixSnapshotStore
    let outputChannelCount: Int
    let allMissingFragmentIndices: [UInt16]
    let overrunPolicy: MadiReceiveOverrunPolicy
    var pendingDeadlines: MadiReceivePendingDeadlineSlots
    var readyBlocks: MadiReceiveReadyBlockRing
    var receiverMixScratch: [UInt8]
    var missingFragmentScratch: [UInt16]
    var nextDueFrame: UInt64 = 0
    var highestReceivedSequenceNumber: UInt64?
    var warmupComplete = false

    public internal(set) var metrics: MadiReceiveMetrics

    public init(configuration: MadiReceiveConfiguration) throws {
        let state = try Self.initializationState(configuration: configuration)

        self.mode = configuration.mode
        self.rxBufferPolicy = state.rxBufferPolicy
        self.currentTargetFrames = state.rxBufferPolicy.targetFrames
        self.adaptiveRxBufferController = state.rxBufferPolicy.profile == .adaptive
            ? try RxBufferAdaptiveController.runtimeController(policy: state.rxBufferPolicy)
            : nil
        self.mixStore = state.mixStore
        self.outputChannelCount = state.outputChannelCount
        self.allMissingFragmentIndices = (0..<configuration.mode.fragments.count).map { UInt16($0) }
        self.overrunPolicy = configuration.overrunPolicy
        self.pendingDeadlines = try MadiReceivePendingDeadlineSlots(capacity: Self.maxPendingDeadlines)
        self.readyBlocks = try MadiReceiveReadyBlockRing(
            capacity: configuration.preallocatedBlockCount,
            framesPerBlock: configuration.mode.framesPerPacket
        )
        self.receiverMixScratch = Array(
            repeating: 0,
            count: Self.outputPayloadByteCount(
                mode: configuration.mode,
                outputChannelCount: state.outputChannelCount
            )
        )
        self.missingFragmentScratch = []
        self.missingFragmentScratch.reserveCapacity(configuration.mode.fragments.count)
        self.metrics = MadiReceiveMetrics(
            preallocatedBlockPoolCapacity: configuration.preallocatedBlockCount,
            rxBuffer: RxBufferRuntimeSnapshot(policy: state.rxBufferPolicy)
        )
    }

    public mutating func receive(
        _ packet: UdpPcmV2Packet,
        receivedAtHostTimeNanoseconds: UInt64 = 0
    ) throws -> MadiReceivePacketResult {
        try validate(packet)
        metrics.networkReceiveFragments += 1
        let packetState = try packetReception(
            packet,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
        if let result = packetState.result {
            return result
        }
        guard let timing = packetState.timing else {
            return .droppedLate
        }
        recordPacketOrdering(packet)
        guard !readyBlocks.contains(playoutFrame: timing.playoutFrame) else {
            recordDuplicate()
            return .droppedDuplicate
        }
        let completed: MadiReceiveCompletedPendingPacket
        switch try pendingPacketState(for: packet) {
        case .waiting(let result):
            return result
        case .complete(let completePacket):
            completed = completePacket
        }
        guard let payload = completed.reassembled.payload else {
            return missingPayloadResult(completed)
        }
        let mixedPayload = try applyReceiverMix(payload)
        let block = playoutBlock(
            packet: packet,
            playoutFrame: timing.playoutFrame,
            mixedPayload: mixedPayload
        )
        if let result = storeReadyBlock(
            block,
            sequenceNumber: packet.header.sequenceNumber,
            packetAgeMicroseconds: timing.packetAgeMicroseconds
        ) {
            return result
        }
        return completeQueuedPacket(packet, timing: timing)
    }
}
