// Collects control-plane evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation
import OpenLolaContracts

/// Captures LightingFixtureGateReport evidence in a stable form for validation and serialized reporting.
public struct LightingFixtureGateReportIdentity: Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public init(id: String, title: String, capturedAt: String, runMode: ReportRunMode = .synthetic) { self.id = id; self.title = title; self.capturedAt = capturedAt; self.runMode = runMode }
}

/// Groups the standards, workflow, safety, probe, fixture, and audio evidence for a gate report.
public struct LightingFixtureGateReportEvidence: Equatable, Sendable {
    public var standards: [LightingProtocolStandardEvidence]
    public var workflow: LightingCueWorkflowEvidence?
    public var policy: LightingSafetyPolicy
    public var probe: LightingProbeReport
    public var fixtureMetadata: LightingFixtureMetadataPolicy
    public var audioImpact: LightingAudioImpactMetrics
    public init(standards: [LightingProtocolStandardEvidence], workflow: LightingCueWorkflowEvidence? = nil, policy: LightingSafetyPolicy, probe: LightingProbeReport, fixtureMetadata: LightingFixtureMetadataPolicy, audioImpact: LightingAudioImpactMetrics) { self.standards = standards; self.workflow = workflow; self.policy = policy; self.probe = probe; self.fixtureMetadata = fixtureMetadata; self.audioImpact = audioImpact }
}

/// Serializes the complete lighting fixture gate evidence and its final verdict.
public struct LightingFixtureGateReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var standards: [LightingProtocolStandardEvidence]
    public var workflow: LightingCueWorkflowEvidence?
    public var policy: LightingSafetyPolicy
    public var probe: LightingProbeReport
    public var fixtureMetadata: LightingFixtureMetadataPolicy
    public var audioImpact: LightingAudioImpactMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(identity: LightingFixtureGateReportIdentity, evidence: LightingFixtureGateReportEvidence, verdict: MeasurementVerdict, notes: String) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.runMode = identity.runMode
        self.standards = evidence.standards
        self.workflow = evidence.workflow
        self.policy = evidence.policy
        self.probe = evidence.probe
        self.fixtureMetadata = evidence.fixtureMetadata
        self.audioImpact = evidence.audioImpact
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> LightingFixtureGateReport {
        try JSONDecoder().decode(LightingFixtureGateReport.self, from: data)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case capturedAt
        case runMode
        case standards
        case workflow
        case policy
        case probe
        case fixtureMetadata
        case audioImpact
        case verdict
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.capturedAt = try container.decode(String.self, forKey: .capturedAt)
        self.runMode = try container.decodeIfPresent(ReportRunMode.self, forKey: .runMode) ?? .synthetic
        self.standards = try container.decode([LightingProtocolStandardEvidence].self, forKey: .standards)
        self.workflow = try container.decodeIfPresent(LightingCueWorkflowEvidence.self, forKey: .workflow)
        self.policy = try container.decode(LightingSafetyPolicy.self, forKey: .policy)
        self.probe = try container.decode(LightingProbeReport.self, forKey: .probe)
        self.fixtureMetadata = try container.decode(LightingFixtureMetadataPolicy.self, forKey: .fixtureMetadata)
        self.audioImpact = try container.decode(LightingAudioImpactMetrics.self, forKey: .audioImpact)
        self.verdict = try container.decode(MeasurementVerdict.self, forKey: .verdict)
        self.notes = try container.decode(String.self, forKey: .notes)
    }

}
