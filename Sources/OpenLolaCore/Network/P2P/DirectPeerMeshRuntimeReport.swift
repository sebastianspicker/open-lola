// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Dispatch
import Foundation

/// Represents the DirectPeerMeshRuntimeRouteMetrics produced by direct peer sessions without exposing its execution state.
public struct DirectPeerMeshRuntimeRouteMetrics: Codable, Equatable, Sendable {
    public var senderPeerID: String
    public var receiverPeerID: String
    public var audioDeadlinesSent: Int
    public var audioDeadlinesReceived: Int
    public var audioFragmentsSent: Int
    public var audioFragmentsReceived: Int
    public var incompleteAudioDeadlines: Int
    public var duplicateAudioFragments: Int

    public init(
        senderPeerID: String,
        receiverPeerID: String,
        audioDeadlinesSent: Int,
        audioDeadlinesReceived: Int,
        audioFragmentsSent: Int,
        audioFragmentsReceived: Int,
        incompleteAudioDeadlines: Int,
        duplicateAudioFragments: Int
    ) {
        self.senderPeerID = senderPeerID
        self.receiverPeerID = receiverPeerID
        self.audioDeadlinesSent = audioDeadlinesSent
        self.audioDeadlinesReceived = audioDeadlinesReceived
        self.audioFragmentsSent = audioFragmentsSent
        self.audioFragmentsReceived = audioFragmentsReceived
        self.incompleteAudioDeadlines = incompleteAudioDeadlines
        self.duplicateAudioFragments = duplicateAudioFragments
    }
}

/// Represents the DirectPeerMeshRuntimeMetrics produced by direct peer sessions without exposing its execution state.
public struct DirectPeerMeshRuntimeMetrics: Codable, Equatable, Sendable {
    public var peerCount: Int
    public var directedRouteCount: Int
    public var audioDeadlinesSent: Int
    public var audioDeadlinesReceived: Int
    public var audioFragmentsSent: Int
    public var audioFragmentsReceived: Int
    public var incompleteAudioDeadlines: Int
    public var duplicateAudioFragments: Int
    public var audioPayloadsSentOnControlChannel: Int
}

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerMeshRuntimeError: Error, Equatable, Sendable {
    case emptyField(String)
    case invalidPacketCount(Int)
    case negativeMetric(String)
    case routeMetricReferencesUnknownRoute(sender: String, receiver: String)
    case duplicateRouteMetric(sender: String, receiver: String)
    case metricMismatch(String)
    case passRequiresPhysicalMeshEvidence
}

/// Captures DirectPeerMeshRuntimeReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerMeshRuntimeReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var topology: DirectPeerMeshTopologyReport
    public var routeMetrics: [DirectPeerMeshRuntimeRouteMetrics]
    public var metrics: DirectPeerMeshRuntimeMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        topology: DirectPeerMeshTopologyReport,
        routeMetrics: [DirectPeerMeshRuntimeRouteMetrics],
        metrics: DirectPeerMeshRuntimeMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.topology = topology
        self.routeMetrics = routeMetrics
        self.metrics = metrics
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireMeshRuntimeNonEmpty(id, "id")
        try requireMeshRuntimeNonEmpty(capturedAt, "capturedAt")
        try requireMeshRuntimeNonEmpty(notes, "notes")
        try topology.validate()
        try validateRouteMetrics()
        try validateMetrics()
        if verdict == .pass {
            throw DirectPeerMeshRuntimeError.passRequiresPhysicalMeshEvidence
        }
    }

    private func validateRouteMetrics() throws {
        let expectedRoutes = Set(topology.routes.map {
            DirectPeerMeshDirectedPair(sender: $0.senderPeerID, receiver: $0.receiverPeerID)
        })
        try requireMeshRuntimeMetric(routeMetrics.count == expectedRoutes.count, "routeMetrics.count")
        var seenRoutes = Set<DirectPeerMeshDirectedPair>()
        for metric in routeMetrics {
            try requireMeshRuntimeNonEmpty(metric.senderPeerID, "routeMetrics.senderPeerID")
            try requireMeshRuntimeNonEmpty(metric.receiverPeerID, "routeMetrics.receiverPeerID")
            try requireMeshRuntimeNonNegative(metric.audioDeadlinesSent, "routeMetrics.audioDeadlinesSent")
            try requireMeshRuntimeNonNegative(metric.audioDeadlinesReceived, "routeMetrics.audioDeadlinesReceived")
            try requireMeshRuntimeNonNegative(metric.audioFragmentsSent, "routeMetrics.audioFragmentsSent")
            try requireMeshRuntimeNonNegative(metric.audioFragmentsReceived, "routeMetrics.audioFragmentsReceived")
            try requireMeshRuntimeNonNegative(
                metric.incompleteAudioDeadlines,
                "routeMetrics.incompleteAudioDeadlines"
            )
            try requireMeshRuntimeNonNegative(
                metric.duplicateAudioFragments,
                "routeMetrics.duplicateAudioFragments"
            )
            let pair = DirectPeerMeshDirectedPair(
                sender: metric.senderPeerID,
                receiver: metric.receiverPeerID
            )
            guard expectedRoutes.contains(pair) else {
                throw DirectPeerMeshRuntimeError.routeMetricReferencesUnknownRoute(
                    sender: metric.senderPeerID,
                    receiver: metric.receiverPeerID
                )
            }
            guard seenRoutes.insert(pair).inserted else {
                throw DirectPeerMeshRuntimeError.duplicateRouteMetric(
                    sender: metric.senderPeerID,
                    receiver: metric.receiverPeerID
                )
            }
        }
    }

    private func validateMetrics() throws {
        let peerCount = topology.configuration.peers.count
        try requireMeshRuntimeNonNegative(metrics.peerCount, "metrics.peerCount")
        try requireMeshRuntimeNonNegative(metrics.directedRouteCount, "metrics.directedRouteCount")
        try requireMeshRuntimeNonNegative(metrics.audioDeadlinesSent, "metrics.audioDeadlinesSent")
        try requireMeshRuntimeNonNegative(metrics.audioDeadlinesReceived, "metrics.audioDeadlinesReceived")
        try requireMeshRuntimeNonNegative(metrics.audioFragmentsSent, "metrics.audioFragmentsSent")
        try requireMeshRuntimeNonNegative(metrics.audioFragmentsReceived, "metrics.audioFragmentsReceived")
        try requireMeshRuntimeNonNegative(
            metrics.incompleteAudioDeadlines,
            "metrics.incompleteAudioDeadlines"
        )
        try requireMeshRuntimeNonNegative(
            metrics.duplicateAudioFragments,
            "metrics.duplicateAudioFragments"
        )
        try requireMeshRuntimeNonNegative(
            metrics.audioPayloadsSentOnControlChannel,
            "metrics.audioPayloadsSentOnControlChannel"
        )
        try requireMeshRuntimeMetric(metrics.peerCount == peerCount, "metrics.peerCount")
        try requireMeshRuntimeMetric(
            metrics.directedRouteCount == routeMetrics.count,
            "metrics.directedRouteCount"
        )
        try requireMeshRuntimeMetric(
            metrics.audioDeadlinesSent == routeMetrics.map(\.audioDeadlinesSent).reduce(0, +),
            "metrics.audioDeadlinesSent"
        )
        try requireMeshRuntimeMetric(
            metrics.audioDeadlinesReceived == routeMetrics.map(\.audioDeadlinesReceived).reduce(0, +),
            "metrics.audioDeadlinesReceived"
        )
        try requireMeshRuntimeMetric(
            metrics.audioFragmentsSent == routeMetrics.map(\.audioFragmentsSent).reduce(0, +),
            "metrics.audioFragmentsSent"
        )
        try requireMeshRuntimeMetric(
            metrics.audioFragmentsReceived == routeMetrics.map(\.audioFragmentsReceived).reduce(0, +),
            "metrics.audioFragmentsReceived"
        )
        try requireMeshRuntimeMetric(
            metrics.incompleteAudioDeadlines == routeMetrics.map(\.incompleteAudioDeadlines).reduce(0, +),
            "metrics.incompleteAudioDeadlines"
        )
        try requireMeshRuntimeMetric(
            metrics.duplicateAudioFragments == routeMetrics.map(\.duplicateAudioFragments).reduce(0, +),
            "metrics.duplicateAudioFragments"
        )
    }
}

private func requireMeshRuntimeNonEmpty(_ value: String, _ field: String) throws {
    try requireDirectPeerMeshNonEmpty(value, field, makeError: DirectPeerMeshRuntimeError.emptyField)
}

private func requireMeshRuntimeNonNegative(_ value: Int, _ field: String) throws {
    try requireDirectPeerMeshNonNegative(value, field, makeError: DirectPeerMeshRuntimeError.negativeMetric)
}

private func requireMeshRuntimeMetric(_ condition: Bool, _ field: String) throws {
    try requireDirectPeerMeshMetric(condition, field, makeError: DirectPeerMeshRuntimeError.metricMismatch)
}
