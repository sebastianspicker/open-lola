import Foundation

public struct MadiFullDuplexReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: MadiFullDuplexRunMode
    public var localPeerID: String
    public var remotePeerID: String
    public var localEndpoint: SessionNetworkEndpoint
    public var remoteEndpoint: SessionNetworkEndpoint
    public var audioPair: MadiFullDuplexAudioPair
    public var metrics: MadiFullDuplexMetrics
    public var receiverMix: MadiFullDuplexReceiverMixEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: MadiFullDuplexRunMode,
        localPeerID: String,
        remotePeerID: String,
        localEndpoint: SessionNetworkEndpoint,
        remoteEndpoint: SessionNetworkEndpoint,
        audioPair: MadiFullDuplexAudioPair,
        metrics: MadiFullDuplexMetrics,
        receiverMix: MadiFullDuplexReceiverMixEvidence? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.localEndpoint = localEndpoint
        self.remoteEndpoint = remoteEndpoint
        self.audioPair = audioPair
        self.metrics = metrics
        self.receiverMix = receiverMix
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try MadiFullDuplexValidator.requireNonEmpty(id, "id")
        try MadiFullDuplexValidator.requireNonEmpty(title, "title")
        try MadiFullDuplexValidator.requireNonEmpty(capturedAt, "capturedAt")
        try MadiFullDuplexValidator.requireNonEmpty(localPeerID, "localPeerID")
        try MadiFullDuplexValidator.requireNonEmpty(remotePeerID, "remotePeerID")
        try MadiFullDuplexValidator.requireNonEmpty(notes, "notes")
        try localEndpoint.validate(fieldPrefix: "localEndpoint")
        try remoteEndpoint.validate(fieldPrefix: "remoteEndpoint")
        try audioPair.validate()
        try metrics.validate()
        try receiverMix?.validate()
        if verdict == .pass, runMode != .measuredPhysical {
            throw MadiFullDuplexError.passRequiresPhysicalRmeEvidence
        }
    }
}

public struct MadiFullDuplexReceiverMixEvidence: Codable, Equatable, Sendable {
    public var configured: Bool
    public var policy: String
    public var routeCount: Int
    public var outputChannelCount: Int
    public var lastAppliedRevision: UInt64
    public var renderedBlocks: Int
    public var requiresDestructiveDownmix: Bool
    public var appliedOutsideAudioCallback: Bool

    public init(
        configured: Bool,
        policy: String,
        routeCount: Int,
        outputChannelCount: Int,
        lastAppliedRevision: UInt64,
        renderedBlocks: Int,
        requiresDestructiveDownmix: Bool,
        appliedOutsideAudioCallback: Bool
    ) {
        self.configured = configured
        self.policy = policy
        self.routeCount = routeCount
        self.outputChannelCount = outputChannelCount
        self.lastAppliedRevision = lastAppliedRevision
        self.renderedBlocks = renderedBlocks
        self.requiresDestructiveDownmix = requiresDestructiveDownmix
        self.appliedOutsideAudioCallback = appliedOutsideAudioCallback
    }

    public func validate() throws {
        try MadiFullDuplexValidator.requireNonEmpty(policy, "receiverMix.policy")
        try MadiFullDuplexValidator.requirePositive(routeCount, "receiverMix.routeCount")
        try MadiFullDuplexValidator.requirePositive(outputChannelCount, "receiverMix.outputChannelCount")
        try MadiFullDuplexValidator.requirePositive(Int(lastAppliedRevision), "receiverMix.lastAppliedRevision")
        try MadiFullDuplexValidator.requireNonNegative(renderedBlocks, "receiverMix.renderedBlocks")
    }
}

public enum MadiFullDuplexSyntheticSmoke {
    public static func run(
        packetCount: Int = 4,
        channelCount: Int = 8,
        receiverDriftFramesPerPacket: Int = 0
    ) throws -> MadiFullDuplexReport {
        let configuration = try MadiFullDuplexSessionConfiguration.synthetic(
            packetCount: packetCount,
            channelCount: channelCount
        )
        return try run(
            configuration: configuration,
            receiverDriftFramesPerPacket: receiverDriftFramesPerPacket
        )
    }

    public static func run(
        configuration: MadiFullDuplexSessionConfiguration,
        receiverDriftFramesPerPacket: Int = 0
    ) throws -> MadiFullDuplexReport {
        var session = try MadiFullDuplexSession(configuration: configuration)
        try session.start()
        let modes = try syntheticModes(for: configuration)
        try exchangeSyntheticPackets(configuration: configuration, session: &session, modes: modes)
        _ = try session.renderRemoteAudioCallback()
        try attachDrift(
            to: &session,
            configuration: configuration,
            remoteMode: modes.remote,
            packetCount: configuration.packetCount,
            receiverDriftFramesPerPacket: receiverDriftFramesPerPacket
        )
        var metrics = session.metrics
        metrics.receivedFragments = metrics.transmittedFragments
        return report(configuration: configuration, metrics: metrics)
    }

    private static func syntheticModes(
        for configuration: MadiFullDuplexSessionConfiguration
    ) throws -> MadiFullDuplexSyntheticModes {
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
        return MadiFullDuplexSyntheticModes(local: localMode, remote: remoteMode)
    }

    private static func exchangeSyntheticPackets(
        configuration: MadiFullDuplexSessionConfiguration,
        session: inout MadiFullDuplexSession,
        modes: MadiFullDuplexSyntheticModes
    ) throws {
        for index in 0..<configuration.packetCount {
            try exchangeSyntheticPacket(index: index, session: &session, modes: modes)
        }
    }

    private static func exchangeSyntheticPacket(
        index: Int,
        session: inout MadiFullDuplexSession,
        modes: MadiFullDuplexSyntheticModes
    ) throws {
        if index > 0 {
            _ = try session.renderRemoteAudioCallback()
        }
        _ = try session.captureLocalPayload(
            startFrame: UInt64(index * modes.local.framesPerPacket),
            hostTimeNanoseconds: UInt64(index + 1),
            payload: SyntheticAudioPayload.make(seed: index, byteCount: modes.local.payloadByteCount)
        )
        _ = try session.sendNextLocalPackets()
        let remotePackets = try syntheticRemotePackets(index: index, remoteMode: modes.remote)
        _ = try session.receiveRemotePackets(
            remotePackets,
            receivedAtHostTimeNanoseconds: UInt64(index + 2)
        )
        if index == 0 {
            _ = try session.renderRemoteAudioCallback()
        }
    }

    private static func syntheticRemotePackets(
        index: Int,
        remoteMode: AudioTransportMode
    ) throws -> [UdpPcmV2Packet] {
        try UdpPcmV2Packetizer.packetize(
            SyntheticAudioPayload.make(seed: index + 100, byteCount: remoteMode.payloadByteCount),
            sequenceNumber: UInt64(index),
            senderFrameIndex: UInt64(index * remoteMode.framesPerPacket),
            senderHostTimeNanoseconds: UInt64(index + 1),
            mode: remoteMode
        )
    }

    private static func attachDrift(
        to session: inout MadiFullDuplexSession,
        configuration: MadiFullDuplexSessionConfiguration,
        remoteMode: AudioTransportMode,
        packetCount: Int,
        receiverDriftFramesPerPacket: Int
    ) throws {
        let simulation = try MadiFullDuplexClockDriftSimulator.run(
            sampleCount: max(2, packetCount),
            senderFrameStep: remoteMode.framesPerPacket,
            receiverFrameStep: remoteMode.framesPerPacket + receiverDriftFramesPerPacket,
            correctionPolicy: configuration.correctionPolicy
        )
        session.applyDriftSimulation(simulation)
    }

    private static func report(
        configuration: MadiFullDuplexSessionConfiguration,
        metrics: MadiFullDuplexMetrics
    ) -> MadiFullDuplexReport {
        MadiFullDuplexReport(
            id: "m05-madi-full-duplex-source-smoke",
            title: "M05 MADI full-duplex source-level smoke",
            capturedAt: "2026-05-04T00:00:00Z",
            runMode: .sourceLevel,
            localPeerID: configuration.localPeerID,
            remotePeerID: configuration.remotePeerID,
            localEndpoint: configuration.localEndpoint,
            remoteEndpoint: configuration.remoteEndpoint,
            audioPair: configuration.audioPair,
            metrics: metrics,
            receiverMix: receiverMixEvidence(
                configuration: configuration,
                metrics: metrics,
                lastAppliedRevision: 1,
                outputChannelCount: configuration.audioPair.remoteToLocal.channelCount
            ),
            verdict: .partial,
            notes: "Source-level full-duplex TX/RX only; physical two-peer RME MADI evidence is required for PASS."
        )
    }

}

private struct MadiFullDuplexSyntheticModes {
    var local: AudioTransportMode
    var remote: AudioTransportMode
}

func receiverMixEvidence(
    configuration: MadiFullDuplexSessionConfiguration,
    metrics: MadiFullDuplexMetrics,
    lastAppliedRevision: UInt64,
    outputChannelCount: Int
) -> MadiFullDuplexReceiverMixEvidence {
    let fallbackRouteCount = configuration.audioPair.remoteToLocal.channelCount
    return MadiFullDuplexReceiverMixEvidence(
        configured: configuration.receiverMix != nil,
        policy: configuration.receiverMixPolicy,
        routeCount: configuration.receiverMix?.routes.count ?? fallbackRouteCount,
        outputChannelCount: outputChannelCount,
        lastAppliedRevision: lastAppliedRevision,
        renderedBlocks: metrics.renderedReceiveBlocks,
        requiresDestructiveDownmix: configuration.receiverMix?.requiresDestructiveDownmix ?? false,
        appliedOutsideAudioCallback: true
    )
}
