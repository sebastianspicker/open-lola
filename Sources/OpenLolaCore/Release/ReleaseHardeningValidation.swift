// Validates ReleaseHardeningValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Captures report contents required to validate, interpret, and reproduce a release-hardening result.
public struct ReleaseHardeningReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let title: String
        public let capturedAt: String
        public let runMode: ReleaseHardeningRunMode

        public init(id: String, title: String, capturedAt: String, runMode: ReleaseHardeningRunMode) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
        }
    }

    public struct Evidence: Sendable {
        public let publicDocs: ReleasePublicDocAudit
        public let claims: [ReleaseClaimReference]
        public let verificationGates: [ReleaseVerificationGate]
        public let benchmarkComparison: ReleaseBenchmarkComparison
        public let packagingReadiness: ReleasePackagingReadiness

        public init(
            publicDocs: ReleasePublicDocAudit,
            claims: [ReleaseClaimReference],
            verificationGates: [ReleaseVerificationGate],
            benchmarkComparison: ReleaseBenchmarkComparison,
            packagingReadiness: ReleasePackagingReadiness
        ) {
            self.publicDocs = publicDocs
            self.claims = claims
            self.verificationGates = verificationGates
            self.benchmarkComparison = benchmarkComparison
            self.packagingReadiness = packagingReadiness
        }
    }

    public struct Outcome: Sendable {
        public let remainingPartialGates: [String]
        public let verdict: MeasurementVerdict
        public let notes: String

        public init(remainingPartialGates: [String], verdict: MeasurementVerdict, notes: String) {
            self.remainingPartialGates = remainingPartialGates
            self.verdict = verdict
            self.notes = notes
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReleaseHardeningRunMode
    public var publicDocs: ReleasePublicDocAudit
    public var claims: [ReleaseClaimReference]
    public var verificationGates: [ReleaseVerificationGate]
    public var benchmarkComparison: ReleaseBenchmarkComparison
    public var packagingReadiness: ReleasePackagingReadiness
    public var remainingPartialGates: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        identity: Identity,
        evidence: Evidence,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.runMode = identity.runMode
        self.publicDocs = evidence.publicDocs
        self.claims = evidence.claims
        self.verificationGates = evidence.verificationGates
        self.benchmarkComparison = evidence.benchmarkComparison
        self.packagingReadiness = evidence.packagingReadiness
        self.remainingPartialGates = outcome.remainingPartialGates
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

    public func validate() throws {
        try validateIdentity()
        try validatePublicDocs()
        try validateClaims()
        try validateVerificationGates()
        try validateBenchmarkComparison()
        try validatePackagingReadiness()
        try validateVerdict()
    }

    private func validateIdentity() throws {
        try ReleaseHardeningValidator.requireNonEmpty(id, "id")
        try ReleaseHardeningValidator.requireNonEmpty(title, "title")
        try ReleaseHardeningValidator.requireNonEmpty(capturedAt, "capturedAt")
        try ReleaseHardeningValidator.requireNonEmpty(notes, "notes")
    }

    private func validatePublicDocs() throws {
        try validateList(publicDocs.forbiddenTokensFound, "publicDocs.forbiddenTokensFound")
        try validateList(publicDocs.internalEvidenceLinksFound, "publicDocs.internalEvidenceLinksFound")
        try validateList(publicDocs.proprietaryLeakageFound, "publicDocs.proprietaryLeakageFound")
        try validateList(
            publicDocs.unsupportedCompatibilityClaimsFound,
            "publicDocs.unsupportedCompatibilityClaimsFound"
        )
        try validateList(publicDocs.generatedArtifactsFound, "publicDocs.generatedArtifactsFound")
    }

    private func validateClaims() throws {
        guard !claims.isEmpty else {
            throw ReleaseHardeningValidationError.emptyList("claims")
        }
        for claim in claims {
            try ReleaseHardeningValidator.requireNonEmpty(claim.claim, "claims.claim")
            try ReleaseHardeningValidator.requireNonEmpty(claim.sourcePath, "claims.sourcePath")
            try ReleaseHardeningValidator.requireNonEmpty(claim.notes, "claims.notes")
            if releaseHardeningPathIsInternalEvidence(claim.sourcePath) {
                throw ReleaseHardeningValidationError.claimUsesInternalEvidence(claim.sourcePath)
            }
        }
    }

    private func validateVerificationGates() throws {
        guard !verificationGates.isEmpty else {
            throw ReleaseHardeningValidationError.emptyList("verificationGates")
        }
        for gate in verificationGates {
            try ReleaseHardeningValidator.requireNonEmpty(gate.name, "verificationGates.name")
            try ReleaseHardeningValidator.requireNonEmpty(gate.command, "verificationGates.command")
            try ReleaseHardeningValidator.requireNonEmpty(gate.notes, "verificationGates.notes")
        }
    }

    private func validateBenchmarkComparison() throws {
        try ReleaseHardeningValidator.requireNonEmpty(
            benchmarkComparison.selectedProfile,
            "benchmarkComparison.selectedProfile"
        )
        try ReleaseHardeningValidator.requireNonEmpty(
            benchmarkComparison.m12ReportId,
            "benchmarkComparison.m12ReportId"
        )
        try ReleaseHardeningValidator.requireNonEmpty(
            benchmarkComparison.m13ReportId,
            "benchmarkComparison.m13ReportId"
        )
        try ReleaseHardeningValidator.requireNonEmpty(
            benchmarkComparison.currentBenchmarkReportId,
            "benchmarkComparison.currentBenchmarkReportId"
        )
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.notes, "benchmarkComparison.notes")
    }

    private func validatePackagingReadiness() throws {
        try ReleaseHardeningValidator.requireNonEmpty(
            packagingReadiness.packagingReportId,
            "packagingReadiness.packagingReportId"
        )
        try ReleaseHardeningValidator.requireNonEmpty(packagingReadiness.notes, "packagingReadiness.notes")
    }

    private func validateVerdict() throws {
        if verdict == .partial, remainingPartialGates.isEmpty {
            throw ReleaseHardeningValidationError.partialWithoutRemainingGates
        }
        try validateList(remainingPartialGates, "remainingPartialGates")
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw ReleaseHardeningValidationError.passWithoutMeasuredRun
        }
        try validatePassPublicDocs()
        try validatePassClaims()
        try validatePassVerificationGates()
        try validatePassBenchmarkComparison()
        try validatePassEvidenceIdentifiers()
        try validatePassPackagingReadiness()
        try validatePassRemainingGates()
    }

    private func validatePassClaims() throws {
        guard claims.contains(where: { $0.evidenceKind == .measuredReport && $0.sourceVerdict == .pass }) else {
            throw ReleaseHardeningValidationError.passWithoutMeasuredReportClaim
        }
        for claim in claims where claim.sourceVerdict != .pass {
            throw ReleaseHardeningValidationError.passWithNonPassClaim(claim.claim, claim.sourceVerdict)
        }
    }

    private func validatePassVerificationGates() throws {
        for requiredKind in releaseHardeningRequiredPassGateKinds {
            guard verificationGates.contains(where: { $0.kind == requiredKind }) else {
                throw ReleaseHardeningValidationError.passMissingVerificationGate(requiredKind)
            }
        }
        for gate in verificationGates where !gate.passed || gate.verdict != .pass {
            throw ReleaseHardeningValidationError.passWithFailingVerificationGate(gate.name)
        }
    }

    private func validatePassBenchmarkComparison() throws {
        guard benchmarkComparison.comparedWithAcceptedReports else {
            throw ReleaseHardeningValidationError.passWithoutBenchmarkComparison
        }
        guard !benchmarkComparison.regressionDetected else {
            throw ReleaseHardeningValidationError.passWithBenchmarkRegression
        }
    }

    private func validatePassPackagingReadiness() throws {
        guard packagingReadiness.packagingVerdict == .pass else {
            throw ReleaseHardeningValidationError.passWithoutPackagingPass(packagingReadiness.packagingVerdict)
        }
        guard packagingReadiness.cleanMacVerdict == .pass else {
            throw ReleaseHardeningValidationError.passWithoutCleanMacPass(packagingReadiness.cleanMacVerdict)
        }
        guard packagingReadiness.signingVerdict == .pass else {
            throw ReleaseHardeningValidationError.passWithoutSigningPass(packagingReadiness.signingVerdict)
        }
        guard packagingReadiness.generatedArtifactsExcluded else {
            throw ReleaseHardeningValidationError.passWithGeneratedArtifacts
        }
    }

    private func validatePassRemainingGates() throws {
        guard remainingPartialGates.isEmpty else {
            throw ReleaseHardeningValidationError.passWithRemainingPartialGates
        }
    }

    private func validatePassPublicDocs() throws {
        guard publicDocs.publicDocsAudited else {
            throw ReleaseHardeningValidationError.passWithoutPublicDocAudit
        }
        guard publicDocs.cleanRoomRulesReviewed else {
            throw ReleaseHardeningValidationError.passWithoutCleanRoomReview
        }
        guard publicDocs.publicationRedactionsReviewed else {
            throw ReleaseHardeningValidationError.passWithoutPublicationRedactionReview
        }
        guard publicDocs.evidenceLabelsPresent else {
            throw ReleaseHardeningValidationError.passWithoutEvidenceLabels
        }
        let findings = publicDocs.forbiddenTokensFound
            + publicDocs.internalEvidenceLinksFound
            + publicDocs.proprietaryLeakageFound
            + publicDocs.unsupportedCompatibilityClaimsFound
            + publicDocs.generatedArtifactsFound
        if let finding = findings.first {
            throw ReleaseHardeningValidationError.passWithPublicDocFinding(finding)
        }
    }

    private func validatePassEvidenceIdentifiers() throws {
        for field in releaseHardeningPassEvidenceFields() where releaseHardeningIsPlaceholder(field.value) {
            throw ReleaseHardeningValidationError.passWithPlaceholderEvidenceField(field.name)
        }
    }

    private func releaseHardeningPassEvidenceFields() -> [(name: String, value: String)] {
        [
            ("benchmarkComparison.m12ReportId", benchmarkComparison.m12ReportId),
            ("benchmarkComparison.m13ReportId", benchmarkComparison.m13ReportId),
            ("benchmarkComparison.currentBenchmarkReportId", benchmarkComparison.currentBenchmarkReportId),
            ("packagingReadiness.packagingReportId", packagingReadiness.packagingReportId)
        ]
    }
}
private func validateList(_ values: [String], _ field: String) throws {
    for value in values {
        try ReleaseHardeningValidator.requireNonEmpty(value, field)
    }
}
private let releaseHardeningRequiredPassGateKinds: [ReleaseVerificationGateKind] = [
    .docs,
    .shell,
    .swiftBuild,
    .swiftTest,
    .cliSmoke,
    .benchmark,
    .packaging
]
private func releaseHardeningPathIsInternalEvidence(_ path: String) -> Bool {
    let normalized = path.lowercased()
    return internalEvidencePathPrefixes.contains { prefix in
        normalized == prefix
            || normalized.hasPrefix("\(prefix)/")
            || normalized.contains("/\(prefix)/")
    }
}
private let internalEvidencePathPrefixes = [
    "confidential",
    "internal",
    "private",
    "proprietary",
    "reverse-engineering",
    "win-compiled"
]
private func releaseHardeningIsPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["required", "synthetic", "partial", "not-supplied", "not supplied", "placeholder"],
        trimWhitespace: false,
        emptyIsPlaceholder: false
    )
}
