// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures DirectPeerSessionReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var configuration: SessionConfiguration
    public var metrics: DirectPeerSessionReportMetrics
    public var avRuntime: DirectPeerSessionAVRuntimeMetadata?
    public var measuredEvidence: DirectPeerSessionMeasuredEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        configuration: SessionConfiguration,
        metrics: DirectPeerSessionReportMetrics,
        avRuntime: DirectPeerSessionAVRuntimeMetadata? = nil,
        measuredEvidence: DirectPeerSessionMeasuredEvidence? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.configuration = configuration
        self.metrics = metrics
        self.avRuntime = avRuntime
        self.measuredEvidence = measuredEvidence
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> DirectPeerSessionReport {
        try JSONDecoder().decode(DirectPeerSessionReport.self, from: data)
    }
}
