import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
// DECISION: Preserve stored-property names and types as a persisted JSON contract; CLI validation,
// aggregate reports, and the operator app decode them across process boundaries.
import Foundation

/// Captures DirectPeerSessionReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var configuration: SessionConfiguration
    public var metrics: DirectPeerSessionReportMetrics
    public var avRuntime: DirectPeerSessionAVRuntimeMetadata?
    public var measuredEvidence: DirectPeerSessionMeasuredEvidence?
    /// Process CPU and memory sampled during the run; nil in reports written before sampling existed.
    public var resources: DirectPeerSessionResourceUsage?
    /// Media byte and packet-order counters; nil in reports written before they were counted.
    public var mediaTraffic: DirectPeerSessionMediaTraffic?
    /// Machine model, chip and OS version of the peer; nil in reports written before they were recorded.
    public var host: DirectPeerSessionHostIdentity?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        configuration: SessionConfiguration,
        metrics: DirectPeerSessionReportMetrics,
        avRuntime: DirectPeerSessionAVRuntimeMetadata? = nil,
        measuredEvidence: DirectPeerSessionMeasuredEvidence? = nil,
        resources: DirectPeerSessionResourceUsage? = nil,
        mediaTraffic: DirectPeerSessionMediaTraffic? = nil,
        host: DirectPeerSessionHostIdentity? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.configuration = configuration
        self.metrics = metrics
        self.avRuntime = avRuntime
        self.measuredEvidence = measuredEvidence
        self.resources = resources
        self.mediaTraffic = mediaTraffic
        self.host = host
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> DirectPeerSessionReport {
        try JSONDecoder().decode(DirectPeerSessionReport.self, from: data)
    }
}
