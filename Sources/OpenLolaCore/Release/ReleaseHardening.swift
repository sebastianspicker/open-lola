// Defines release claims, verification gates, benchmark comparisons, packaging readiness, and pass rules in one fail-closed policy surface.
import Foundation

/// Identifies the measurement methodology recorded with release-hardening artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias ReleaseHardeningRunMode = MeasurementMethodology

/// Defines the finite evidence provenance values recorded by release-hardening artifacts for deterministic validation and report interpretation.
public enum ReleaseClaimEvidenceKind: String, Codable, Equatable, Sendable {
    case publicDocumentation
    case openLolaTest
    case measuredReport
}

/// Defines the finite classification values recorded by release-hardening artifacts for deterministic validation and report interpretation.
public enum ReleaseVerificationGateKind: String, Codable, Equatable, Sendable {
    case docs
    case shell
    case swiftBuild
    case swiftTest
    case cliSmoke
    case benchmark
    case packaging
}

/// Captures audit findings required to validate, interpret, and reproduce a release-hardening result.
public struct ReleasePublicDocAudit: Codable, Equatable, Sendable {
    public struct ReviewStatus: Equatable, Sendable {
        public var publicDocsAudited: Bool
        public var cleanRoomRulesReviewed: Bool
        public var publicationRedactionsReviewed: Bool
        public var evidenceLabelsPresent: Bool

        public init(
            publicDocsAudited: Bool,
            cleanRoomRulesReviewed: Bool,
            publicationRedactionsReviewed: Bool,
            evidenceLabelsPresent: Bool
        ) {
            self.publicDocsAudited = publicDocsAudited
            self.cleanRoomRulesReviewed = cleanRoomRulesReviewed
            self.publicationRedactionsReviewed = publicationRedactionsReviewed
            self.evidenceLabelsPresent = evidenceLabelsPresent
        }
    }

    public struct Findings: Equatable, Sendable {
        public var forbiddenTokens: [String]
        public var internalEvidenceLinks: [String]
        public var proprietaryLeakage: [String]
        public var unsupportedCompatibilityClaims: [String]
        public var generatedArtifacts: [String]

        public init(
            forbiddenTokens: [String],
            internalEvidenceLinks: [String],
            proprietaryLeakage: [String],
            unsupportedCompatibilityClaims: [String],
            generatedArtifacts: [String]
        ) {
            self.forbiddenTokens = forbiddenTokens
            self.internalEvidenceLinks = internalEvidenceLinks
            self.proprietaryLeakage = proprietaryLeakage
            self.unsupportedCompatibilityClaims = unsupportedCompatibilityClaims
            self.generatedArtifacts = generatedArtifacts
        }
    }

    public var publicDocsAudited: Bool
    public var cleanRoomRulesReviewed: Bool
    public var publicationRedactionsReviewed: Bool
    public var forbiddenTokensFound: [String]
    public var internalEvidenceLinksFound: [String]
    public var proprietaryLeakageFound: [String]
    public var unsupportedCompatibilityClaimsFound: [String]
    public var generatedArtifactsFound: [String]
    public var evidenceLabelsPresent: Bool

    public init(
        reviewStatus: ReviewStatus,
        findings: Findings
    ) {
        publicDocsAudited = reviewStatus.publicDocsAudited
        cleanRoomRulesReviewed = reviewStatus.cleanRoomRulesReviewed
        publicationRedactionsReviewed = reviewStatus.publicationRedactionsReviewed
        forbiddenTokensFound = findings.forbiddenTokens
        internalEvidenceLinksFound = findings.internalEvidenceLinks
        proprietaryLeakageFound = findings.proprietaryLeakage
        unsupportedCompatibilityClaimsFound = findings.unsupportedCompatibilityClaims
        generatedArtifactsFound = findings.generatedArtifacts
        evidenceLabelsPresent = reviewStatus.evidenceLabelsPresent
    }
}

/// Captures structured result required to validate, interpret, and reproduce a release-hardening result.
public struct ReleaseClaimReference: Codable, Equatable, Sendable {
    public var claim: String
    public var evidenceKind: ReleaseClaimEvidenceKind
    public var sourcePath: String
    public var sourceVerdict: MeasurementVerdict
    public var notes: String

    public init(
        claim: String,
        evidenceKind: ReleaseClaimEvidenceKind,
        sourcePath: String,
        sourceVerdict: MeasurementVerdict,
        notes: String
    ) {
        self.claim = claim
        self.evidenceKind = evidenceKind
        self.sourcePath = sourcePath
        self.sourceVerdict = sourceVerdict
        self.notes = notes
    }
}

/// Captures structured result required to validate, interpret, and reproduce a release-hardening result.
public struct ReleaseVerificationGate: Codable, Equatable, Sendable {
    public var name: String
    public var kind: ReleaseVerificationGateKind
    public var command: String
    public var passed: Bool
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        name: String,
        kind: ReleaseVerificationGateKind,
        command: String,
        passed: Bool,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.name = name
        self.kind = kind
        self.command = command
        self.passed = passed
        self.verdict = verdict
        self.notes = notes
    }
}

/// Captures structured result required to validate, interpret, and reproduce a release-hardening result.
public struct ReleaseBenchmarkComparison: Codable, Equatable, Sendable {
    public var selectedProfile: String
    public var m12ReportId: String
    public var m13ReportId: String
    public var currentBenchmarkReportId: String
    public var comparedWithAcceptedReports: Bool
    public var regressionDetected: Bool
    public var notes: String

    public init(
        selectedProfile: String,
        m12ReportId: String,
        m13ReportId: String,
        currentBenchmarkReportId: String,
        comparedWithAcceptedReports: Bool,
        regressionDetected: Bool,
        notes: String
    ) {
        self.selectedProfile = selectedProfile
        self.m12ReportId = m12ReportId
        self.m13ReportId = m13ReportId
        self.currentBenchmarkReportId = currentBenchmarkReportId
        self.comparedWithAcceptedReports = comparedWithAcceptedReports
        self.regressionDetected = regressionDetected
        self.notes = notes
    }
}

/// Captures structured result required to validate, interpret, and reproduce a release-hardening result.
public struct ReleasePackagingReadiness: Codable, Equatable, Sendable {
    public var packagingReportId: String
    public var packagingVerdict: MeasurementVerdict
    public var cleanMacVerdict: MeasurementVerdict
    public var signingVerdict: MeasurementVerdict
    public var generatedArtifactsExcluded: Bool
    public var notes: String

    public init(
        packagingReportId: String,
        packagingVerdict: MeasurementVerdict,
        cleanMacVerdict: MeasurementVerdict,
        signingVerdict: MeasurementVerdict,
        generatedArtifactsExcluded: Bool,
        notes: String
    ) {
        self.packagingReportId = packagingReportId
        self.packagingVerdict = packagingVerdict
        self.cleanMacVerdict = cleanMacVerdict
        self.signingVerdict = signingVerdict
        self.generatedArtifactsExcluded = generatedArtifactsExcluded
        self.notes = notes
    }
}

/// Describes failures that prevent release-hardening inputs or evidence from satisfying the required validation invariants.
public enum ReleaseHardeningValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case claimUsesInternalEvidence(String)
    case partialWithoutRemainingGates
    case passWithoutMeasuredRun
    case passWithoutMeasuredReportClaim
    case passWithoutPublicDocAudit
    case passWithoutCleanRoomReview
    case passWithoutPublicationRedactionReview
    case passWithoutEvidenceLabels
    case passWithPublicDocFinding(String)
    case passWithNonPassClaim(String, MeasurementVerdict)
    case passMissingVerificationGate(ReleaseVerificationGateKind)
    case passWithFailingVerificationGate(String)
    case passWithoutBenchmarkComparison
    case passWithBenchmarkRegression
    case passWithPlaceholderEvidenceField(String)
    case passWithoutPackagingPass(MeasurementVerdict)
    case passWithoutCleanMacPass(MeasurementVerdict)
    case passWithoutSigningPass(MeasurementVerdict)
    case passWithGeneratedArtifacts
    case passWithRemainingPartialGates
}

/// Captures run configuration required to validate, interpret, and reproduce a release-hardening result.
public struct ReleaseHardeningRunConfiguration: Codable, Equatable, Sendable {
    public let outputPath: String

    public init(outputPath: String) {
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> ReleaseHardeningRunConfiguration {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: ["--output"],
            unknown: ReleaseHardeningRunConfigurationError.unknownArgument,
            duplicate: ReleaseHardeningRunConfigurationError.duplicateArgument,
            missingValue: ReleaseHardeningRunConfigurationError.missingValue
        )
        let outputPath = try KeyValueArgumentParser.requiredString(
            "--output",
            values,
            missing: ReleaseHardeningRunConfigurationError.missingRequiredArgument
        )
        return ReleaseHardeningRunConfiguration(outputPath: outputPath)
    }
}

/// Describes failures that prevent release-hardening inputs or evidence from satisfying the required validation invariants.
public enum ReleaseHardeningRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}
