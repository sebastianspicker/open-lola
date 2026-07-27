// Exercises direct-peer signaling and media over localhost to verify endpoint negotiation without presenting loopback as physical route proof.
import Foundation

/// Represents the DirectP2PLocalhostSmokeResult produced by direct peer sessions without exposing its execution state.
public struct DirectP2PLocalhostSmokeResult: Sendable {
    public var first: PeerSessionRunner
    public var second: PeerSessionRunner
    public var report: DirectPeerSessionReport

    public init(
        first: PeerSessionRunner,
        second: PeerSessionRunner,
        report: DirectPeerSessionReport
    ) {
        self.first = first
        self.second = second
        self.report = report
    }
}

/// Provides deterministic DirectP2PLocalhostSmoke coverage without requiring external direct peer sessions infrastructure.
public enum DirectP2PLocalhostSmoke {
    public static func run(packetCount: Int = 3) throws -> DirectP2PLocalhostSmokeResult {
        var pair = try PeerSessionRunnerLoopbackPair.make()
        try pair.negotiate()
        try pair.startMedia()
        for sequence in 1...packetCount {
            try pair.sendAudioPacketFromFirstToSecond(sequenceNumber: UInt64(sequence))
        }
        let configuration = try requireDirectPeerSessionConfiguration(pair.first.acceptedConfiguration)
        let report = DirectPeerSessionReport(
            id: "m06-direct-p2p-localhost-\(UUID().uuidString)",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: configuration,
            metrics: DirectPeerSessionReportMetrics(
                traffic: .init(
                    controlMessagesSent: pair.first.metrics.controlMessagesSent
                        + pair.second.metrics.controlMessagesSent,
                    packetsSent: pair.first.metrics.mediaPacketsSent,
                    packetsReceived: pair.second.metrics.mediaPacketsReceived,
                    packetsLost: pair.second.transportMetrics().packetsLost,
                    jitterMicroseconds: pair.second.transportMetrics().jitterMicroseconds,
                    audioPacketsRouted: pair.second.metrics.audioPacketsRouted,
                    videoPacketsRouted: pair.second.metrics.videoPacketsRouted,
                    recoveryEvents: pair.first.metrics.recoveryEvents
                        + pair.second.metrics.recoveryEvents
                ),
                control: .init(
                    audioPayloadsSentOnControlChannel: pair.first.metrics.audioPayloadsSentOnControlChannel
                        + pair.second.metrics.audioPayloadsSentOnControlChannel
                ),
                remote: .init(),
                remoteResources: .init()
            ),
            verdict: .partial,
            notes: """
            Loopback direct P2P source smoke passed. M06 remains PARTIAL until direct \
            LAN manual-address evidence and physical MADI route evidence exist.
            """
        )
        pair.first.shutdown(reason: "smoke complete")
        pair.second.shutdown(reason: "smoke complete")
        return DirectP2PLocalhostSmokeResult(
            first: pair.first,
            second: pair.second,
            report: report
        )
    }
}
