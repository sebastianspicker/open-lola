// Holds MADI receive configuration, buffer latency, playout outcomes, and recovery results so packet ingestion and rendering agree on state.
import Foundation

/// Reports `transportModeMismatch`, `invalidTransportMode`, `emptyField`, and `nonPositiveField` failures that stop invalid MADI full-duplex transport work before it reaches a live path.
public enum MadiReceiveError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case transportModeMismatch(String)
    case invalidTransportMode
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case receiverMix(ReceiverMixSnapshotError)
    case reassembly(UdpPcmV2FragmentReassemblyError)
    case audioBufferBaseAddressUnavailable(String)
    case pendingDeadlineLimitExceeded(Int)
    case playoutFrameOverflow(senderFrameIndex: UInt64, targetFrames: Int)
    case passRequiresPhysicalRmeEvidence

    public static func nonFiniteField(_ field: String) -> MadiReceiveError {
        .negativeField(field)
    }
}

/// Chooses whether a full MADI receive buffer drops the newest or oldest packet.
public enum MadiReceiveOverrunPolicy: String, Codable, Equatable, Sendable {
    case dropNewest
    case dropOldest
}

/// Binds `mode`, `rxBufferPolicy`, `receiverMix`, and `outputChannelCount` before MADI full-duplex transport starts, preventing implicit runtime defaults.
public struct MadiReceiveConfiguration: Equatable, Sendable {
    public var mode: AudioTransportMode
    public var rxBufferPolicy: RxBufferPolicy?
    public var receiverMix: ReceiverMixSnapshot?
    public var outputChannelCount: Int?
    public var preallocatedBlockCount: Int
    public var overrunPolicy: MadiReceiveOverrunPolicy

    public init(
        mode: AudioTransportMode,
        rxBufferPolicy: RxBufferPolicy? = nil,
        receiverMix: ReceiverMixSnapshot? = nil,
        outputChannelCount: Int? = nil,
        preallocatedBlockCount: Int = 4,
        overrunPolicy: MadiReceiveOverrunPolicy = .dropNewest
    ) {
        self.mode = mode
        self.rxBufferPolicy = rxBufferPolicy
        self.receiverMix = receiverMix
        self.outputChannelCount = outputChannelCount
        self.preallocatedBlockCount = preallocatedBlockCount
        self.overrunPolicy = overrunPolicy
    }
}

/// Keeps MADI receive buffering distinct from other frame/packet latency costs.
public enum MadiReceiveBufferLatencyDomain {}
/// Names the latency metrics accumulated while buffering received MADI packets.
public typealias MadiReceiveBufferLatency = PacketBufferLatency<MadiReceiveBufferLatencyDomain>

/// Pairs `streamID`, `sequenceNumber`, `startFrame`, and `senderFrameIndex` with one playout block in MADI transport.
public struct MadiReceivePlayoutBlock: Equatable, Sendable {
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var startFrame: UInt64
    public var senderFrameIndex: UInt64
    public var frameCount: Int
    public var inputChannelCount: Int
    public var outputChannelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var payload: Data
    public var mixRevision: UInt64
    public var latency: MadiReceiveBufferLatency
}

/// Pairs `sequenceNumber`, `startFrame`, `frameCount`, and `missingFragmentIndices` with one playout block in MADI transport.
public struct MadiReceiveRecoveryBlock: Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var startFrame: UInt64
    public var frameCount: Int
    public var missingFragmentIndices: [UInt16]
    public var payloadByteCount: Int

    public init(
        sequenceNumber: UInt64,
        startFrame: UInt64,
        frameCount: Int,
        missingFragmentIndices: [UInt16],
        payloadByteCount: Int
    ) {
        self.sequenceNumber = sequenceNumber
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.missingFragmentIndices = missingFragmentIndices
        self.payloadByteCount = payloadByteCount
    }
}

/// Distinguishes fragment wait, queued delivery, and late, full, or duplicate drops.
public enum MadiReceivePacketResult: Equatable, Sendable {
    case waitingForFragments(receivedFragmentCount: Int, expectedFragmentCount: Int)
    case queued
    case droppedLate
    case droppedFull
    case droppedDuplicate
}

/// Defines `played`, `sameDeadlineRecovery`, and `silence` states used to make madi receive render result decisions in MADI full-duplex transport.
public enum MadiReceiveRenderResult: Equatable, Sendable {
    case played(MadiReceivePlayoutBlock)
    case sameDeadlineRecovery(MadiReceiveRecoveryBlock)
    case silence(startFrame: UInt64, frameCount: Int)
}

/// Tracks `networkReceiveFragments`, `droppedNetworkFragments`, `completedBlocks`, and `renderedBlocks` to expose latency, pressure, and delivery outcomes in MADI full-duplex transport.
public struct MadiReceiveMetrics: Codable, Equatable, Sendable {
    public var networkReceiveFragments: Int = 0
    public var droppedNetworkFragments: Int = 0
    public var completedBlocks: Int = 0
    public var renderedBlocks: Int = 0
    public var latePackets: Int = 0
    public var futurePackets: Int = 0
    public var duplicatePackets: Int = 0
    public var reorderedPackets: Int = 0
    public var lostPackets: Int = 0
    public var fragmentLostPackets: Int = 0
    public var underruns: Int = 0
    public var overruns: Int = 0
    public var sameDeadlineRecoveries: Int = 0
    public var maximumBufferedBlocks: Int = 0
    public var preallocatedBlockPoolCapacity: Int
    public var allocationWarnings: Int = 0
    public var lastPacketAgeMicroseconds: Double?
    public var maximumPacketAgeMicroseconds: Double?
    public var rxBuffer: RxBufferRuntimeSnapshot
}
