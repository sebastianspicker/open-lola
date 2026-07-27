// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures report contents required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingSessionArtifactReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: RecordingSessionRunMode
    public var durationSeconds: Double
    public var session: RecordingSessionMetadata
    public var sideLane: RecordingSideLanePolicy
    public var capture: RecordingMediaCaptureSelection
    public var writerPressure: RecordingWriterPressureMetrics
    public var mediaImpact: RecordingMediaImpactMetrics
    public var audioArtifact: RecordingAudioArtifactMetrics
    public var videoArtifact: RecordingVideoArtifactMetrics
    public var manifest: RecordingArtifactManifest
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        metadata: RecordingSessionArtifactReportMetadata,
        evidence: RecordingSessionArtifactReportEvidence,
        verdict: MeasurementVerdict
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.runMode = metadata.runMode
        self.durationSeconds = metadata.durationSeconds
        self.session = evidence.session
        self.sideLane = evidence.sideLane
        self.capture = evidence.capture
        self.writerPressure = evidence.writerPressure
        self.mediaImpact = evidence.mediaImpact
        self.audioArtifact = evidence.audioArtifact
        self.videoArtifact = evidence.videoArtifact
        self.manifest = evidence.manifest
        self.verdict = verdict
        self.notes = metadata.notes
    }

    public static func decode(from data: Data) throws -> RecordingSessionArtifactReport {
        try JSONDecoder().decode(RecordingSessionArtifactReport.self, from: data)
    }

}
