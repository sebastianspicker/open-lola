// Validates NetworkAoipCertification acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation
import OpenLolaContracts

/// Enumerates failures that callers must handle when working with network diagnostics.
public enum NetworkAoipCertificationValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case partialWithoutReason
    case passWithoutMeasuredRun
    case passWithoutRouteCertification
    case passWithoutDriftPlcCertification
    case passWithoutAoipEvaluation
    case passWithoutAcceptedRouteCertification
    case passWithoutAcceptedDriftPlcCertification
    case passWithoutAcceptedAoipEvaluation
    case passWithoutDirectLinkRoute
    case passWithoutProfessionalMode
    case passWithBaselineMismatch
    case passWithRouteMismatch
    case passWithoutPtpArtifact
    case passWithoutStressArtifact
    case passWithoutProfileArtifact
    case passWithPlaceholderField(String)
}

/// Aggregates route, drift/PLC, AoIP, and artifact evidence for network-timing certification.
public struct NetworkAoipCertificationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Metadata: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: ReportRunMode

        public init(id: String, title: String, capturedAt: String, runMode: ReportRunMode) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
        }
    }

    public struct Reports: Equatable, Sendable {
        public var routeCertification: MacToMacRouteCertificationReport?
        public var driftPlcCertification: DriftPlcFixedTargetCertificationReport?
        public var aoipEvaluation: AoipEvaluationReport?

        public init(
            routeCertification: MacToMacRouteCertificationReport?,
            driftPlcCertification: DriftPlcFixedTargetCertificationReport?,
            aoipEvaluation: AoipEvaluationReport?
        ) {
            self.routeCertification = routeCertification
            self.driftPlcCertification = driftPlcCertification
            self.aoipEvaluation = aoipEvaluation
        }
    }

    public struct Artifacts: Equatable, Sendable {
        public var ptpPath: String?
        public var stressPath: String?
        public var profilePath: String?
        public var notTestedReason: String?

        public init(
            ptpPath: String?,
            stressPath: String?,
            profilePath: String?,
            notTestedReason: String?
        ) {
            self.ptpPath = ptpPath
            self.stressPath = stressPath
            self.profilePath = profilePath
            self.notTestedReason = notTestedReason
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public struct Input: Equatable, Sendable {
        public var metadata: Metadata
        public var reports: Reports
        public var artifacts: Artifacts
        public var outcome: Outcome

        public init(metadata: Metadata, reports: Reports, artifacts: Artifacts, outcome: Outcome) {
            self.metadata = metadata
            self.reports = reports
            self.artifacts = artifacts
            self.outcome = outcome
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var routeCertificationReport: MacToMacRouteCertificationReport?
    public var driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport?
    public var aoipEvaluationReport: AoipEvaluationReport?
    public var ptpArtifactPath: String?
    public var stressArtifactPath: String?
    public var profileArtifactPath: String?
    public var notTestedReason: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(_ input: Input) {
        ((self.id, self.title), (self.capturedAt, self.runMode)) = reportMetadataValues(input.metadata)
        self.routeCertificationReport = input.reports.routeCertification
        self.driftPlcCertificationReport = input.reports.driftPlcCertification
        self.aoipEvaluationReport = input.reports.aoipEvaluation
        self.ptpArtifactPath = input.artifacts.ptpPath
        self.stressArtifactPath = input.artifacts.stressPath
        self.profileArtifactPath = input.artifacts.profilePath
        self.notTestedReason = input.artifacts.notTestedReason
        self.verdict = input.outcome.verdict
        self.notes = input.outcome.notes
    }
}

extension NetworkAoipCertificationReport.Metadata: ReportMetadataFields {}

private struct NetworkAoipPassContext {
    var routeCertificationReport: MacToMacRouteCertificationReport
    var driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport
    var aoipEvaluationReport: AoipEvaluationReport
}

private struct NetworkAoipPassDirectLink {
    var report: UdpPcmRouteReport
    var packetCaptureArtifact: String
}

/// Produces deterministic partial AoIP certification evidence without claiming a measured professional route.
public enum NetworkAoipCertificationSyntheticSmoke {
    public static func run() -> NetworkAoipCertificationReport {
        let metadata = NetworkAoipCertificationReport.Metadata(
            id: "g06-network-aoip-certification-synthetic-smoke",
            title: "Synthetic G06 network timing AoIP certification",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic
        )
        let reports = NetworkAoipCertificationReport.Reports(
            routeCertification: nil,
            driftPlcCertification: nil,
            aoipEvaluation: nil
        )
        let artifacts = NetworkAoipCertificationReport.Artifacts(
            ptpPath: nil,
            stressPath: nil,
            profilePath: nil,
            notTestedReason: "Synthetic smoke only; G06 PASS requires accepted G04/G05 direct baselines "
                + "plus measured AoIP, PTP, profile, and WCRT evidence."
        )
        return NetworkAoipCertificationReport(
            .init(
                metadata: metadata,
                reports: reports,
                artifacts: artifacts,
                outcome: .init(
                    verdict: .partial,
                    notes: "Synthetic source validation only; no professional AoIP route is certified."
                )
            )
        )
    }
}

func requireNetworkAoipNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NetworkAoipCertificationValidationError.emptyField(field)
    }
}

func isNetworkAoipPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "none", "tbd", "not-tested", "notrun", "not-run"]
    )
}
