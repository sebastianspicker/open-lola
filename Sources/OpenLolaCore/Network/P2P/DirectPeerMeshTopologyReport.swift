// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Describes DirectPeerMeshRoute values used to plan and verify direct peer sessions.
public struct DirectPeerMeshRoute: Codable, Equatable, Sendable {
    public var senderPeerID: String
    public var receiverPeerID: String
    public var audioStreamID: Int
    public var videoStreamIDs: [Int]

    public init(
        senderPeerID: String,
        receiverPeerID: String,
        audioStreamID: Int,
        videoStreamIDs: [Int]
    ) {
        self.senderPeerID = senderPeerID
        self.receiverPeerID = receiverPeerID
        self.audioStreamID = audioStreamID
        self.videoStreamIDs = videoStreamIDs
    }
}

/// Represents the DirectPeerMeshTopologyMetrics produced by direct peer sessions without exposing its execution state.
public struct DirectPeerMeshTopologyMetrics: Codable, Equatable, Sendable {
    public var peerCount: Int
    public var endpointSetCount: Int
    public var expectedDirectedRouteCount: Int
    public var configuredDirectedRouteCount: Int
    public var audioStreamCount: Int
    public var enabledVideoStreamCount: Int

    public init(
        peerCount: Int,
        endpointSetCount: Int,
        expectedDirectedRouteCount: Int,
        configuredDirectedRouteCount: Int,
        audioStreamCount: Int,
        enabledVideoStreamCount: Int
    ) {
        self.peerCount = peerCount
        self.endpointSetCount = endpointSetCount
        self.expectedDirectedRouteCount = expectedDirectedRouteCount
        self.configuredDirectedRouteCount = configuredDirectedRouteCount
        self.audioStreamCount = audioStreamCount
        self.enabledVideoStreamCount = enabledVideoStreamCount
    }
}

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerMeshTopologyError: Error, Equatable, Sendable {
    case emptyField(String)
    case negativeMetric(String)
    case routeReferencesUnknownPeer(String)
    case routeReferencesUnknownAudioStream(Int)
    case routeReferencesUnknownVideoStream(Int)
    case selfRoute(String)
    case duplicateDirectedRoute(sender: String, receiver: String)
    case missingDirectedRoute(sender: String, receiver: String)
    case metricMismatch(String)
    case passRequiresPhysicalMeshEvidence
}

/// Captures DirectPeerMeshTopologyReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerMeshTopologyReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var configuration: SessionConfiguration
    public var routes: [DirectPeerMeshRoute]
    public var metrics: DirectPeerMeshTopologyMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        configuration: SessionConfiguration,
        routes: [DirectPeerMeshRoute],
        metrics: DirectPeerMeshTopologyMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.configuration = configuration
        self.routes = routes
        self.metrics = metrics
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireMeshNonEmpty(id, "id")
        try requireMeshNonEmpty(capturedAt, "capturedAt")
        try requireMeshNonEmpty(notes, "notes")
        try configuration.validatePeerMediaTopology(minimumPeerCount: 3)
        try validateMetrics()
        try validateRoutes()
        if verdict == .pass {
            throw DirectPeerMeshTopologyError.passRequiresPhysicalMeshEvidence
        }
    }

    private func validateMetrics() throws {
        let peerCount = configuration.peers.count
        let endpointSetCount = configuration.peerMediaEndpoints?.count ?? 0
        let expectedRouteCount = peerCount * (peerCount - 1)
        try requireMeshNonNegative(metrics.peerCount, "metrics.peerCount")
        try requireMeshNonNegative(metrics.endpointSetCount, "metrics.endpointSetCount")
        try requireMeshNonNegative(
            metrics.expectedDirectedRouteCount,
            "metrics.expectedDirectedRouteCount"
        )
        try requireMeshNonNegative(
            metrics.configuredDirectedRouteCount,
            "metrics.configuredDirectedRouteCount"
        )
        try requireMeshNonNegative(metrics.audioStreamCount, "metrics.audioStreamCount")
        try requireMeshNonNegative(metrics.enabledVideoStreamCount, "metrics.enabledVideoStreamCount")
        try requireMetric(metrics.peerCount == peerCount, "metrics.peerCount")
        try requireMetric(metrics.endpointSetCount == endpointSetCount, "metrics.endpointSetCount")
        try requireMetric(
            metrics.expectedDirectedRouteCount == expectedRouteCount,
            "metrics.expectedDirectedRouteCount"
        )
        try requireMetric(metrics.configuredDirectedRouteCount == routes.count, "metrics.configuredDirectedRouteCount")
        try requireMetric(metrics.audioStreamCount == configuration.audioStreams.count, "metrics.audioStreamCount")
        try requireMetric(
            metrics.enabledVideoStreamCount == configuration.videoStreams.filter(\.isEnabled).count,
            "metrics.enabledVideoStreamCount"
        )
    }

    private func validateRoutes() throws {
        let peerIDs = Set(configuration.peers.map(\.peerID))
        let audioStreamIDs = Set(configuration.audioStreams.map(\.id))
        let videoStreamIDs = Set(configuration.videoStreams.map(\.id))
        var directedPairs = Set<DirectPeerMeshDirectedPair>()
        for route in routes {
            try validateRoute(
                route,
                peerIDs: peerIDs,
                audioStreamIDs: audioStreamIDs,
                videoStreamIDs: videoStreamIDs,
                directedPairs: &directedPairs
            )
        }
        try requireCompleteDirectedRoutes(peerIDs: peerIDs, directedPairs: directedPairs)
    }

    private func validateRoute(
        _ route: DirectPeerMeshRoute,
        peerIDs: Set<String>,
        audioStreamIDs: Set<Int>,
        videoStreamIDs: Set<Int>,
        directedPairs: inout Set<DirectPeerMeshDirectedPair>
    ) throws {
        try requireMeshNonEmpty(route.senderPeerID, "routes.senderPeerID")
        try requireMeshNonEmpty(route.receiverPeerID, "routes.receiverPeerID")
        guard peerIDs.contains(route.senderPeerID) else {
            throw DirectPeerMeshTopologyError.routeReferencesUnknownPeer(route.senderPeerID)
        }
        guard peerIDs.contains(route.receiverPeerID) else {
            throw DirectPeerMeshTopologyError.routeReferencesUnknownPeer(route.receiverPeerID)
        }
        guard route.senderPeerID != route.receiverPeerID else {
            throw DirectPeerMeshTopologyError.selfRoute(route.senderPeerID)
        }
        guard audioStreamIDs.contains(route.audioStreamID) else {
            throw DirectPeerMeshTopologyError.routeReferencesUnknownAudioStream(route.audioStreamID)
        }
        for streamID in route.videoStreamIDs where !videoStreamIDs.contains(streamID) {
            throw DirectPeerMeshTopologyError.routeReferencesUnknownVideoStream(streamID)
        }
        let pair = DirectPeerMeshDirectedPair(sender: route.senderPeerID, receiver: route.receiverPeerID)
        if !directedPairs.insert(pair).inserted {
            throw DirectPeerMeshTopologyError.duplicateDirectedRoute(
                sender: route.senderPeerID,
                receiver: route.receiverPeerID
            )
        }
    }

    private func requireCompleteDirectedRoutes(
        peerIDs: Set<String>,
        directedPairs: Set<DirectPeerMeshDirectedPair>
    ) throws {
        for sender in peerIDs {
            for receiver in peerIDs where sender != receiver {
                if !directedPairs.contains(DirectPeerMeshDirectedPair(sender: sender, receiver: receiver)) {
                    throw DirectPeerMeshTopologyError.missingDirectedRoute(
                        sender: sender,
                        receiver: receiver
                    )
                }
            }
        }
    }
}

/// Provides deterministic DirectPeerMeshTopologySmoke coverage without requiring external direct peer sessions infrastructure.
public enum DirectPeerMeshTopologySmoke {
    public static func run(
        peerCount: Int = 3,
        peerMediaEndpoints: [SessionPeerMediaEndpoints]? = nil
    ) throws -> DirectPeerMeshTopologyReport {
        guard peerCount >= 3 else {
            throw SessionValidationError.peerCountBelowMinimum(requested: peerCount, minimum: 3)
        }
        let peers = (0..<peerCount).map { index in
            PeerIdentity(
                peerID: "peer-\(UnicodeScalar(97 + index)!)",
                displayName: "Reference Mac \(index + 1)",
                implementationName: "open-lola",
                implementationVersion: "0.0.0-mesh"
            )
        }
        let configuration = SessionConfiguration(
            identity: .init(sessionID: "mesh-topology-\(peerCount)-peer", peers: peers),
            profile: .init(latencyProfile: .multiVideoPerformance, rxBufferProfile: .adaptive),
            streams: .init(audioStreams: [meshAudioStream()], videoStreams: [meshVideoStream()]),
            endpoints: .init(control: .init(host: "127.0.0.1", port: 41_000), audio: .init(host: "127.0.0.1", port: 41_001),
                             video: .init(host: "127.0.0.1", port: 41_002), metrics: .init(host: "127.0.0.1", port: 41_003)),
            transport: .init(peerMediaEndpoints: peerMediaEndpoints ?? self.peerMediaEndpoints(for: peers), mtuBytes: 1_200,
                             metricIntervalMilliseconds: 1_000, reconnectDeadlineMilliseconds: SessionNegotiation.defaultReconnectDeadlineMilliseconds)
        )
        let routes = directedRoutes(for: peers)
        return DirectPeerMeshTopologyReport(
            id: "m06-direct-p2p-mesh-topology-\(peerCount)",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: configuration,
            routes: routes,
            metrics: DirectPeerMeshTopologyMetrics(
                peerCount: peerCount,
                endpointSetCount: peerCount,
                expectedDirectedRouteCount: peerCount * (peerCount - 1),
                configuredDirectedRouteCount: routes.count,
                audioStreamCount: 1,
                enabledVideoStreamCount: 1
            ),
            verdict: .partial,
            notes: "Source-level multi-peer topology smoke. PASS requires physical multi-peer media runs."
        )
    }

    private static func meshAudioStream() -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: 1, direction: .bidirectional, clockDomain: "mesh-source-level-clock"),
            format: .init(sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian, channelCount: 64, channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex),
            packet: .init(framesPerPacket: 32, payloadType: .audioPcmV2)
        )
    }

    private static func meshVideoStream() -> VideoStreamDescription {
        VideoStreamDescription(
            identity: .init(
                id: 100,
                direction: .send,
                role: .testPattern,
                sourceLabel: "mesh test pattern",
                payloadType: .videoRawFrameFragment
            ),
            format: .init(
                resolution: .init(width: 1_280, height: 720),
                frameRate: .init(numerator: 30, denominator: 1),
                pixelFormat: .bgra8,
                transportFormat: .rawFrameFragment
            )
        )
    }

    private static func peerMediaEndpoints(for peers: [PeerIdentity]) -> [SessionPeerMediaEndpoints] {
        peers.enumerated().map { index, peer in
            let base = UInt16(41_000 + index * 10)
            return SessionPeerMediaEndpoints(
                peerID: peer.peerID,
                controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: base),
                audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: base + 1),
                videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: base + 2),
                metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: base + 3)
            )
        }
    }

    private static func directedRoutes(for peers: [PeerIdentity]) -> [DirectPeerMeshRoute] {
        peers.flatMap { sender in
            peers.compactMap { receiver in
                guard sender.peerID != receiver.peerID else {
                    return nil
                }
                return DirectPeerMeshRoute(
                    senderPeerID: sender.peerID,
                    receiverPeerID: receiver.peerID,
                    audioStreamID: 1,
                    videoStreamIDs: [100]
                )
            }
        }
    }
}

private func requireMeshNonEmpty(_ value: String, _ field: String) throws {
    try requireDirectPeerMeshNonEmpty(value, field, makeError: DirectPeerMeshTopologyError.emptyField)
}

private func requireMeshNonNegative(_ value: Int, _ field: String) throws {
    try requireDirectPeerMeshNonNegative(value, field, makeError: DirectPeerMeshTopologyError.negativeMetric)
}

private func requireMetric(_ condition: Bool, _ field: String) throws {
    try requireDirectPeerMeshMetric(condition, field, makeError: DirectPeerMeshTopologyError.metricMismatch)
}
