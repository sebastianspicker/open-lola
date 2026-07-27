// Validates full-duplex MADI metrics and receiver-mix evidence so synthetic and physical sessions cannot share an unsupported pass verdict.
import Foundation

/// Records `id`, `title`, `capturedAt`, and `runMode` so MADI full-duplex transport measurements and verdicts can be checked after a run.
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

/// Preserves `configured`, `policy`, `routeCount`, and `outputChannelCount` needed to distinguish measured MADI full-duplex transport behavior from configuration claims.
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

/// Exercises a deterministic MADI full-duplex transport path so regressions remain reproducible without hardware.
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
        let modes = try madiFullDuplexTransportModes(for: configuration)
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

    private static func exchangeSyntheticPackets(
        configuration: MadiFullDuplexSessionConfiguration,
        session: inout MadiFullDuplexSession,
        modes: MadiFullDuplexTransportModes
    ) throws {
        for index in 0..<configuration.packetCount {
            try exchangeSyntheticPacket(index: index, session: &session, modes: modes)
        }
    }

    private static func exchangeSyntheticPacket(
        index: Int,
        session: inout MadiFullDuplexSession,
        modes: MadiFullDuplexTransportModes
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
