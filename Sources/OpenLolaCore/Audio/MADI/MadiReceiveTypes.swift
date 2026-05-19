import Foundation

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

public enum MadiReceiveOverrunPolicy: String, Codable, Equatable, Sendable {
    case dropNewest
    case dropOldest
}

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

public struct MadiReceiveBufferLatency: Codable, Equatable, Sendable {
    public var frames: Int
    public var packets: Int
    public var microseconds: Double

    public init(frames: Int, packets: Int, microseconds: Double) {
        self.frames = frames
        self.packets = packets
        self.microseconds = microseconds
    }
}

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

    public init(
        streamID: UInt32,
        sequenceNumber: UInt64,
        startFrame: UInt64,
        senderFrameIndex: UInt64,
        frameCount: Int,
        inputChannelCount: Int,
        outputChannelCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        payload: Data,
        mixRevision: UInt64,
        latency: MadiReceiveBufferLatency
    ) {
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.startFrame = startFrame
        self.senderFrameIndex = senderFrameIndex
        self.frameCount = frameCount
        self.inputChannelCount = inputChannelCount
        self.outputChannelCount = outputChannelCount
        self.sampleFormat = sampleFormat
        self.payload = payload
        self.mixRevision = mixRevision
        self.latency = latency
    }
}

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

public enum MadiReceivePacketResult: Equatable, Sendable {
    case waitingForFragments(receivedFragmentCount: Int, expectedFragmentCount: Int)
    case queued
    case droppedLate
    case droppedFull
    case droppedDuplicate
}

public enum MadiReceiveRenderResult: Equatable, Sendable {
    case played(MadiReceivePlayoutBlock)
    case sameDeadlineRecovery(MadiReceiveRecoveryBlock)
    case silence(startFrame: UInt64, frameCount: Int)
}

public struct MadiReceiveMetrics: Codable, Equatable, Sendable {
    public var networkReceiveFragments: Int
    public var droppedNetworkFragments: Int
    public var completedBlocks: Int
    public var renderedBlocks: Int
    public var latePackets: Int
    public var futurePackets: Int
    public var duplicatePackets: Int
    public var reorderedPackets: Int
    public var lostPackets: Int
    public var fragmentLostPackets: Int
    public var underruns: Int
    public var overruns: Int
    public var sameDeadlineRecoveries: Int
    public var maximumBufferedBlocks: Int
    public var preallocatedBlockPoolCapacity: Int
    public var allocationWarnings: Int
    public var lastPacketAgeMicroseconds: Double?
    public var maximumPacketAgeMicroseconds: Double?
    public var rxBuffer: RxBufferRuntimeSnapshot

    public init(
        networkReceiveFragments: Int = 0,
        droppedNetworkFragments: Int = 0,
        completedBlocks: Int = 0,
        renderedBlocks: Int = 0,
        latePackets: Int = 0,
        futurePackets: Int = 0,
        duplicatePackets: Int = 0,
        reorderedPackets: Int = 0,
        lostPackets: Int = 0,
        fragmentLostPackets: Int = 0,
        underruns: Int = 0,
        overruns: Int = 0,
        sameDeadlineRecoveries: Int = 0,
        maximumBufferedBlocks: Int = 0,
        preallocatedBlockPoolCapacity: Int,
        allocationWarnings: Int = 0,
        lastPacketAgeMicroseconds: Double? = nil,
        maximumPacketAgeMicroseconds: Double? = nil,
        rxBuffer: RxBufferRuntimeSnapshot
    ) {
        self.networkReceiveFragments = networkReceiveFragments
        self.droppedNetworkFragments = droppedNetworkFragments
        self.completedBlocks = completedBlocks
        self.renderedBlocks = renderedBlocks
        self.latePackets = latePackets
        self.futurePackets = futurePackets
        self.duplicatePackets = duplicatePackets
        self.reorderedPackets = reorderedPackets
        self.lostPackets = lostPackets
        self.fragmentLostPackets = fragmentLostPackets
        self.underruns = underruns
        self.overruns = overruns
        self.sameDeadlineRecoveries = sameDeadlineRecoveries
        self.maximumBufferedBlocks = maximumBufferedBlocks
        self.preallocatedBlockPoolCapacity = preallocatedBlockPoolCapacity
        self.allocationWarnings = allocationWarnings
        self.lastPacketAgeMicroseconds = lastPacketAgeMicroseconds
        self.maximumPacketAgeMicroseconds = maximumPacketAgeMicroseconds
        self.rxBuffer = rxBuffer
    }
}
