// Owns full-duplex MADI session state and accumulates clock, correction, loss, and receiver metrics across a live run.
import Foundation
import OpenLolaContracts

/// Tracks `transmittedBlocks`, `transmittedFragments`, `socketTransmittedFragments`, and `socketBackpressureDroppedBlocks` to expose latency, pressure, and delivery outcomes in MADI full-duplex transport.
public struct MadiFullDuplexMetrics: Codable, Equatable, Sendable {
    public var transmittedBlocks: Int
    public var transmittedFragments: Int
    /// Socket-level fragments actually accepted by the kernel for network runtime runs.
    public var socketTransmittedFragments: Int?
    /// Audio blocks abandoned atomically after nonblocking socket backpressure.
    public var socketBackpressureDroppedBlocks: Int?
    /// Synthetic/model blocks skipped instead of being burst after a missed real-time slot.
    public var socketDeadlineDroppedBlocks: Int?
    public var receivedFragments: Int
    public var completedReceiveBlocks: Int
    public var renderedReceiveBlocks: Int
    public var underruns: Int
    public var overruns: Int
    public var lateDrops: Int
    public var recoveryEvents: Int
    public var txSenderFrameEnd: UInt64
    public var rxPlayoutFrameEnd: UInt64
    public var videoStreamsEnabled: Int
    public var hiddenPlayoutGrowthDetected: Bool
    public var drift: MadiFullDuplexDriftEstimate
    public var correctionEvents: [MadiFullDuplexCorrectionEvent]
    public var rxBuffer: RxBufferRuntimeSnapshot

    public init(
        videoStreamsEnabled: Int,
        rxBuffer: RxBufferRuntimeSnapshot,
        drift: MadiFullDuplexDriftEstimate? = nil
    ) {
        self.transmittedBlocks = 0
        self.transmittedFragments = 0
        self.socketTransmittedFragments = 0
        self.socketBackpressureDroppedBlocks = 0
        self.socketDeadlineDroppedBlocks = 0
        self.receivedFragments = 0
        self.completedReceiveBlocks = 0
        self.renderedReceiveBlocks = 0
        self.underruns = 0
        self.overruns = 0
        self.lateDrops = 0
        self.recoveryEvents = 0
        self.txSenderFrameEnd = 0
        self.rxPlayoutFrameEnd = 0
        self.videoStreamsEnabled = videoStreamsEnabled
        self.hiddenPlayoutGrowthDetected = false
        self.drift = drift ?? MadiFullDuplexDriftEstimate(
            sampleCount: 1,
            senderFrameDelta: 0,
            receiverFrameDelta: 0,
            driftSlopePartsPerMillion: 0
        )
        self.correctionEvents = []
        self.rxBuffer = rxBuffer
    }

    public func validate() throws {
        try MadiFullDuplexValidator.requireNonNegative(transmittedBlocks, "metrics.transmittedBlocks")
        try MadiFullDuplexValidator.requireNonNegative(transmittedFragments, "metrics.transmittedFragments")
        if let socketTransmittedFragments {
            try MadiFullDuplexValidator.requireNonNegative(
                socketTransmittedFragments,
                "metrics.socketTransmittedFragments"
            )
        }
        if let socketBackpressureDroppedBlocks {
            try MadiFullDuplexValidator.requireNonNegative(
                socketBackpressureDroppedBlocks,
                "metrics.socketBackpressureDroppedBlocks"
            )
        }
        if let socketDeadlineDroppedBlocks {
            try MadiFullDuplexValidator.requireNonNegative(
                socketDeadlineDroppedBlocks,
                "metrics.socketDeadlineDroppedBlocks"
            )
        }
        try MadiFullDuplexValidator.requireNonNegative(receivedFragments, "metrics.receivedFragments")
        try MadiFullDuplexValidator.requireNonNegative(completedReceiveBlocks, "metrics.completedReceiveBlocks")
        try MadiFullDuplexValidator.requireNonNegative(renderedReceiveBlocks, "metrics.renderedReceiveBlocks")
        try MadiFullDuplexValidator.requireNonNegative(underruns, "metrics.underruns")
        try MadiFullDuplexValidator.requireNonNegative(overruns, "metrics.overruns")
        try MadiFullDuplexValidator.requireNonNegative(lateDrops, "metrics.lateDrops")
        try MadiFullDuplexValidator.requireNonNegative(recoveryEvents, "metrics.recoveryEvents")
        try MadiFullDuplexValidator.requireNonNegative(Double(txSenderFrameEnd), "metrics.txSenderFrameEnd")
        try MadiFullDuplexValidator.requireNonNegative(Double(rxPlayoutFrameEnd), "metrics.rxPlayoutFrameEnd")
        try MadiFullDuplexValidator.requireNonNegative(videoStreamsEnabled, "metrics.videoStreamsEnabled")
        try drift.validate()
        for event in correctionEvents {
            try event.validate()
        }
        try rxBuffer.validate()
    }
}

/// Owns `configuration` and the state transitions that keep MADI full-duplex transport bounded at runtime.
public struct MadiFullDuplexSession: Sendable {
    public let configuration: MadiFullDuplexSessionConfiguration
    public private(set) var metrics: MadiFullDuplexMetrics

    private var transmitter: RealtimeAudioPacketHandoff
    private var receiver: MadiReceiveEngine
    private let localSendMode: AudioTransportMode
    private let remoteReceiveMode: AudioTransportMode
    private var running = false
    public private(set) var lastReceiverMixRevision: UInt64 = 1
    public private(set) var lastReceiverOutputChannelCount: Int

    public init(configuration: MadiFullDuplexSessionConfiguration) throws {
        try configuration.validate()
        let modes = try madiFullDuplexTransportModes(for: configuration)
        let localMode = modes.local
        let remoteMode = modes.remote
        let rxPolicy = try audioTransportRxBufferPolicy(for: remoteMode)
        self.configuration = configuration
        self.localSendMode = localMode
        self.remoteReceiveMode = remoteMode
        self.lastReceiverOutputChannelCount = remoteMode.channelCount
        self.transmitter = try RealtimeAudioPacketHandoff(
            configuration: Self.handoffConfiguration(
                mode: localMode,
                inputDeviceUID: configuration.inputDeviceUID,
                outputDeviceUID: configuration.outputDeviceUID,
                preallocatedBlockCount: configuration.preallocatedBlockCount
            )
        )
        self.receiver = try MadiReceiveEngine(
            configuration: MadiReceiveConfiguration(
                mode: remoteMode,
                rxBufferPolicy: rxPolicy,
                receiverMix: configuration.receiverMix,
                outputChannelCount: remoteMode.channelCount,
                preallocatedBlockCount: configuration.preallocatedBlockCount,
                overrunPolicy: configuration.overrunPolicy
            )
        )
        self.metrics = MadiFullDuplexMetrics(
            videoStreamsEnabled: configuration.videoStreamsEnabled,
            rxBuffer: RxBufferRuntimeSnapshot(policy: rxPolicy)
        )
    }

    public mutating func start() throws {
        try configuration.validate()
        running = true
    }

    public mutating func captureLocalPayload(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        payload: Data
    ) throws -> RealtimeAudioRingPushResult {
        try requireRunning()
        let result = transmitter.captureCallback(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            payload: payload
        )
        refreshTransmitMetrics()
        return result
    }

    public mutating func sendNextLocalPackets() throws -> [UdpPcmV2Packet] {
        try requireRunning()
        let packets = try transmitter.sendNextV2Packets(mode: localSendMode) ?? []
        refreshTransmitMetrics()
        if let header = packets.first?.header {
            let frameEnd = header.senderFrameIndex.addingReportingOverflow(
                UInt64(header.framesPerPacket)
            )
            metrics.txSenderFrameEnd = max(
                metrics.txSenderFrameEnd,
                frameEnd.overflow ? UInt64.max : frameEnd.partialValue
            )
        }
        return packets
    }

    mutating func recordSocketTransmit(sentFragments: Int, droppedForBackpressure: Bool) {
        metrics.socketTransmittedFragments = (metrics.socketTransmittedFragments ?? 0) + sentFragments
        if droppedForBackpressure {
            metrics.socketBackpressureDroppedBlocks = (metrics.socketBackpressureDroppedBlocks ?? 0) + 1
        }
    }

    mutating func recordSocketDeadlineDrop() {
        metrics.socketDeadlineDroppedBlocks = (metrics.socketDeadlineDroppedBlocks ?? 0) + 1
    }

    public mutating func receiveRemotePackets(
        _ packets: [UdpPcmV2Packet],
        receivedAtHostTimeNanoseconds: UInt64
    ) throws -> [MadiReceivePacketResult] {
        try requireRunning()
        let results = try packets.map {
            try receiver.receive($0, receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds)
        }
        refreshReceiveMetrics()
        return results
    }

    public mutating func renderRemoteAudioCallback() throws -> MadiReceiveRenderResult {
        try requireRunning()
        let result = receiver.renderCallback()
        if case .played(let block) = result {
            metrics.rxPlayoutFrameEnd = block.startFrame + UInt64(block.frameCount)
            lastReceiverMixRevision = block.mixRevision
            lastReceiverOutputChannelCount = block.outputChannelCount
        }
        refreshReceiveMetrics()
        return result
    }

    mutating func applyDriftSimulation(_ simulation: MadiFullDuplexDriftSimulationResult) {
        metrics.drift = simulation.estimate
        metrics.correctionEvents = simulation.correctionEvents
    }

    private mutating func refreshTransmitMetrics() {
        metrics.transmittedBlocks = transmitter.metrics.networkSendBlocks
        metrics.transmittedFragments = transmitter.metrics.packetFragmentCount
    }

    private mutating func refreshReceiveMetrics() {
        metrics.receivedFragments = receiver.metrics.networkReceiveFragments
        metrics.completedReceiveBlocks = receiver.metrics.completedBlocks
        metrics.renderedReceiveBlocks = receiver.metrics.renderedBlocks
        metrics.underruns = receiver.metrics.underruns
        metrics.overruns = receiver.metrics.overruns
        metrics.lateDrops = receiver.metrics.latePackets
        metrics.recoveryEvents = receiver.metrics.sameDeadlineRecoveries
        metrics.rxBuffer = receiver.metrics.rxBuffer
        metrics.hiddenPlayoutGrowthDetected = receiver.metrics.rxBuffer.hiddenGrowthDetected
    }

    private func requireRunning() throws {
        if !running {
            throw MadiFullDuplexError.notStarted
        }
    }

    static func handoffConfiguration(
        mode: AudioTransportMode,
        inputDeviceUID: String,
        outputDeviceUID: String,
        preallocatedBlockCount: Int
    ) -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        devices: .init(inputDeviceUID: inputDeviceUID, outputDeviceUID: outputDeviceUID),
        format: .init(sampleRateHertz: mode.sampleRateHertz, framesPerBuffer: mode.framesPerPacket, channelCount: mode.channelCount, packetFormat: mode.sampleFormat),
        channelMaps: .init(input: Array(0..<mode.channelCount), output: Array(0..<mode.channelCount)),
        buffering: .init(playoutTargetFrames: mode.framesPerPacket, preallocatedBlockCount: preallocatedBlockCount, rxBufferPolicy: nil)
    )
    }
}
