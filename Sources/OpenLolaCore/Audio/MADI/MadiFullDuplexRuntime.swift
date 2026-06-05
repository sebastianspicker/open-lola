import Foundation
import OpenLolaContracts

public struct MadiFullDuplexMetrics: Codable, Equatable, Sendable {
    public var transmittedBlocks: Int
    public var transmittedFragments: Int
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

private func madiFullDuplexRxBufferPolicy(for mode: AudioTransportMode) throws -> RxBufferPolicy {
    switch mode.rxBufferProfile {
    case .direct:
        try RxBufferPolicy.direct(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .small:
        try RxBufferPolicy.small(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .adaptive:
        try RxBufferPolicy.adaptive(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .stableWan:
        try RxBufferPolicy.stableWan(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    }
}

public struct MadiFullDuplexSourceLevelRequest: Sendable {
    public var sessionID: String
    public var localPeerID: String
    public var remotePeerID: String
    public var localEndpoint: SessionNetworkEndpoint
    public var remoteEndpoint: SessionNetworkEndpoint
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var packetCount: Int
    public var channelCount: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var localStreamID: Int
    public var remoteStreamID: Int
    public var rxBufferProfile: RxBufferProfile
    public var receiverMix: ReceiverMixSnapshot?
    public var receiverMixPolicy: String

    public init(
        sessionID: String,
        localPeerID: String,
        remotePeerID: String,
        localEndpoint: SessionNetworkEndpoint,
        remoteEndpoint: SessionNetworkEndpoint,
        inputDeviceUID: String,
        outputDeviceUID: String,
        packetCount: Int,
        channelCount: Int,
        sampleRateHertz: Int = 48_000,
        framesPerPacket: Int = 32,
        sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
        localStreamID: Int = 1,
        remoteStreamID: Int = 2,
        rxBufferProfile: RxBufferProfile = .direct,
        receiverMix: ReceiverMixSnapshot? = nil,
        receiverMixPolicy: String = "identity-default"
    ) {
        self.sessionID = sessionID
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.localEndpoint = localEndpoint
        self.remoteEndpoint = remoteEndpoint
        self.inputDeviceUID = inputDeviceUID
        self.outputDeviceUID = outputDeviceUID
        self.packetCount = packetCount
        self.channelCount = channelCount
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.sampleFormat = sampleFormat
        self.localStreamID = localStreamID
        self.remoteStreamID = remoteStreamID
        self.rxBufferProfile = rxBufferProfile
        self.receiverMix = receiverMix
        self.receiverMixPolicy = receiverMixPolicy
    }
}

public struct MadiFullDuplexSessionConfiguration: Codable, Equatable, Sendable {
    public var sessionID: String
    public var localPeerID: String
    public var remotePeerID: String
    public var localEndpoint: SessionNetworkEndpoint
    public var remoteEndpoint: SessionNetworkEndpoint
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var audioPair: MadiFullDuplexAudioPair
    public var packetCount: Int
    public var maxTransmissionUnitBytes: Int
    public var maxFragmentsPerDeadline: Int
    public var metadataRevision: Int
    public var preallocatedBlockCount: Int
    public var overrunPolicy: MadiReceiveOverrunPolicy
    public var rxBufferProfile: RxBufferProfile
    public var correctionPolicy: MadiFullDuplexCorrectionPolicy
    public var peerBindTimeoutSeconds: Double
    public var videoStreamsEnabled: Int
    public var receiverMix: ReceiverMixSnapshot?
    public var receiverMixPolicy: String

    public init(
        sessionID: String,
        localPeerID: String,
        remotePeerID: String,
        localEndpoint: SessionNetworkEndpoint,
        remoteEndpoint: SessionNetworkEndpoint,
        inputDeviceUID: String,
        outputDeviceUID: String,
        audioPair: MadiFullDuplexAudioPair,
        packetCount: Int,
        maxTransmissionUnitBytes: Int = 1_200,
        maxFragmentsPerDeadline: Int = 16,
        metadataRevision: Int = 5,
        preallocatedBlockCount: Int = 8,
        overrunPolicy: MadiReceiveOverrunPolicy = .dropNewest,
        rxBufferProfile: RxBufferProfile = .direct,
        correctionPolicy: MadiFullDuplexCorrectionPolicy = MadiFullDuplexCorrectionPolicy(),
        peerBindTimeoutSeconds: Double = 1,
        videoStreamsEnabled: Int = 0,
        receiverMix: ReceiverMixSnapshot? = nil,
        receiverMixPolicy: String = "identity-default"
    ) {
        self.sessionID = sessionID
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.localEndpoint = localEndpoint
        self.remoteEndpoint = remoteEndpoint
        self.inputDeviceUID = inputDeviceUID
        self.outputDeviceUID = outputDeviceUID
        self.audioPair = audioPair
        self.packetCount = packetCount
        self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
        self.metadataRevision = metadataRevision
        self.preallocatedBlockCount = preallocatedBlockCount
        self.overrunPolicy = overrunPolicy
        self.rxBufferProfile = rxBufferProfile
        self.correctionPolicy = correctionPolicy
        self.peerBindTimeoutSeconds = peerBindTimeoutSeconds
        self.videoStreamsEnabled = videoStreamsEnabled
        self.receiverMix = receiverMix
        self.receiverMixPolicy = receiverMixPolicy
    }

    public static func synthetic(
        packetCount: Int,
        channelCount: Int
    ) throws -> MadiFullDuplexSessionConfiguration {
        try sourceLevel(MadiFullDuplexSourceLevelRequest(
            sessionID: "m05-full-duplex-source",
            localPeerID: "local-open-lola",
            remotePeerID: "remote-open-lola",
            localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_001),
            remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_101),
            inputDeviceUID: "synthetic-rme-madi",
            outputDeviceUID: "synthetic-rme-madi",
            packetCount: packetCount,
            channelCount: channelCount
        ))
    }

    public static func sourceLevel(
        _ request: MadiFullDuplexSourceLevelRequest
    ) throws -> MadiFullDuplexSessionConfiguration {
        let pair = try MadiFullDuplexAudioPair(
            localToRemote: audioStream(
                id: request.localStreamID,
                channelCount: request.channelCount,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                sampleFormat: request.sampleFormat
            ),
            remoteToLocal: audioStream(
                id: request.remoteStreamID,
                channelCount: request.channelCount,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                sampleFormat: request.sampleFormat
            )
        )
        return MadiFullDuplexSessionConfiguration(
            sessionID: request.sessionID,
            localPeerID: request.localPeerID,
            remotePeerID: request.remotePeerID,
            localEndpoint: request.localEndpoint,
            remoteEndpoint: request.remoteEndpoint,
            inputDeviceUID: request.inputDeviceUID,
            outputDeviceUID: request.outputDeviceUID,
            audioPair: pair,
            packetCount: request.packetCount,
            rxBufferProfile: request.rxBufferProfile,
            receiverMix: request.receiverMix,
            receiverMixPolicy: request.receiverMixPolicy
        )
    }

    public static func fromSessionConfiguration(
        _ session: SessionConfiguration,
        localPeerID: String,
        remotePeerID: String,
        inputDeviceUID: String,
        outputDeviceUID: String
    ) throws -> MadiFullDuplexSessionConfiguration {
        guard session.videoStreams.filter(\.isEnabled).isEmpty else {
            throw MadiFullDuplexError.enabledVideoNotAllowed
        }
        guard let audio = session.audioStreams.first(where: { $0.direction == .bidirectional }) else {
            throw MadiFullDuplexError.noBidirectionalAudioStream
        }
        let pair = try MadiFullDuplexAudioPair(localToRemote: audio, remoteToLocal: audio)
        return MadiFullDuplexSessionConfiguration(
            sessionID: session.sessionID,
            localPeerID: localPeerID,
            remotePeerID: remotePeerID,
            localEndpoint: SessionNetworkEndpoint(host: "0.0.0.0", port: session.audioEndpoint.port),
            remoteEndpoint: session.audioEndpoint,
            inputDeviceUID: inputDeviceUID,
            outputDeviceUID: outputDeviceUID,
            audioPair: pair,
            packetCount: 1,
            maxTransmissionUnitBytes: session.mtuBytes,
            rxBufferProfile: session.rxBufferProfile,
            videoStreamsEnabled: 0
        )
    }

    public func validate() throws {
        try MadiFullDuplexValidator.requireNonEmpty(sessionID, "sessionID")
        try MadiFullDuplexValidator.requireNonEmpty(localPeerID, "localPeerID")
        try MadiFullDuplexValidator.requireNonEmpty(remotePeerID, "remotePeerID")
        try MadiFullDuplexValidator.requireNonEmpty(inputDeviceUID, "inputDeviceUID")
        try MadiFullDuplexValidator.requireNonEmpty(outputDeviceUID, "outputDeviceUID")
        try localEndpoint.validate(fieldPrefix: "localEndpoint")
        try remoteEndpoint.validate(fieldPrefix: "remoteEndpoint")
        try audioPair.validate()
        try MadiFullDuplexValidator.requirePositive(packetCount, "packetCount")
        try MadiFullDuplexValidator.requirePositive(maxTransmissionUnitBytes, "maxTransmissionUnitBytes")
        try MadiFullDuplexValidator.requirePositive(maxFragmentsPerDeadline, "maxFragmentsPerDeadline")
        try MadiFullDuplexValidator.requirePositive(metadataRevision, "metadataRevision")
        try MadiFullDuplexValidator.requirePositive(preallocatedBlockCount, "preallocatedBlockCount")
        try MadiFullDuplexValidator.requireNonNegative(peerBindTimeoutSeconds, "peerBindTimeoutSeconds")
        try MadiFullDuplexValidator.requireNonNegative(videoStreamsEnabled, "videoStreamsEnabled")
        try MadiFullDuplexValidator.requireNonEmpty(receiverMixPolicy, "receiverMixPolicy")
        guard videoStreamsEnabled == 0 else {
            throw MadiFullDuplexError.enabledVideoNotAllowed
        }
        try correctionPolicy.validate()
    }

    private static func audioStream(
        id: Int,
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormat: UdpPcmSampleFormat
    ) -> AudioStreamDescription {
        AudioStreamDescription(
            id: id,
            direction: .bidirectional,
            sampleRateHertz: sampleRateHertz,
            sampleFormat: sampleFormat,
            channelCount: channelCount,
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            clockDomain: "core-audio-device:madi-full-duplex",
            framesPerPacket: framesPerPacket,
            payloadType: .audioPcmV2
        )
    }
}

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
        let localMode = try configuration.audioPair.localSendMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision
        )
        let remoteMode = try configuration.audioPair.remoteReceiveMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision,
            rxBufferProfile: configuration.rxBufferProfile
        )
        let rxPolicy = try madiFullDuplexRxBufferPolicy(for: remoteMode)
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
        return packets
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
        metrics.txSenderFrameEnd = UInt64(metrics.transmittedBlocks)
            * UInt64(localSendMode.framesPerPacket)
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
            inputDeviceUID: inputDeviceUID,
            outputDeviceUID: outputDeviceUID,
            sampleRateHertz: mode.sampleRateHertz,
            framesPerBuffer: mode.framesPerPacket,
            channelCount: mode.channelCount,
            packetFormat: mode.sampleFormat,
            inputChannelMap: Array(0..<mode.channelCount),
            outputChannelMap: Array(0..<mode.channelCount),
            playoutTargetFrames: mode.framesPerPacket,
            preallocatedBlockCount: preallocatedBlockCount
        )
    }
}
