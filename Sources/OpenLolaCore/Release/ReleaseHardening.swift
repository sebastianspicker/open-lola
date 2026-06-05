import Foundation

public typealias ReleaseHardeningRunMode = MeasurementMethodology

public enum ReleaseClaimEvidenceKind: String, Codable, Equatable, Sendable {
    case publicDocumentation
    case openLolaTest
    case measuredReport
}

public enum ReleaseVerificationGateKind: String, Codable, Equatable, Sendable {
    case docs
    case shell
    case swiftBuild
    case swiftTest
    case cliSmoke
    case benchmark
    case packaging
}

public struct ReleasePublicDocAudit: Codable, Equatable, Sendable {
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
        publicDocsAudited: Bool,
        cleanRoomRulesReviewed: Bool,
        publicationRedactionsReviewed: Bool,
        forbiddenTokensFound: [String],
        internalEvidenceLinksFound: [String],
        proprietaryLeakageFound: [String],
        unsupportedCompatibilityClaimsFound: [String],
        generatedArtifactsFound: [String],
        evidenceLabelsPresent: Bool
    ) {
        self.publicDocsAudited = publicDocsAudited
        self.cleanRoomRulesReviewed = cleanRoomRulesReviewed
        self.publicationRedactionsReviewed = publicationRedactionsReviewed
        self.forbiddenTokensFound = forbiddenTokensFound
        self.internalEvidenceLinksFound = internalEvidenceLinksFound
        self.proprietaryLeakageFound = proprietaryLeakageFound
        self.unsupportedCompatibilityClaimsFound = unsupportedCompatibilityClaimsFound
        self.generatedArtifactsFound = generatedArtifactsFound
        self.evidenceLabelsPresent = evidenceLabelsPresent
    }
}

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

public struct ReleaseHardeningReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
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
        id: String,
        title: String,
        capturedAt: String,
        runMode: ReleaseHardeningRunMode,
        publicDocs: ReleasePublicDocAudit,
        claims: [ReleaseClaimReference],
        verificationGates: [ReleaseVerificationGate],
        benchmarkComparison: ReleaseBenchmarkComparison,
        packagingReadiness: ReleasePackagingReadiness,
        remainingPartialGates: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.publicDocs = publicDocs
        self.claims = claims
        self.verificationGates = verificationGates
        self.benchmarkComparison = benchmarkComparison
        self.packagingReadiness = packagingReadiness
        self.remainingPartialGates = remainingPartialGates
        self.verdict = verdict
        self.notes = notes
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
        try validateList(publicDocs.unsupportedCompatibilityClaimsFound, "publicDocs.unsupportedCompatibilityClaimsFound")
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
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.selectedProfile, "benchmarkComparison.selectedProfile")
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.m12ReportId, "benchmarkComparison.m12ReportId")
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.m13ReportId, "benchmarkComparison.m13ReportId")
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.currentBenchmarkReportId, "benchmarkComparison.currentBenchmarkReportId")
        try ReleaseHardeningValidator.requireNonEmpty(benchmarkComparison.notes, "benchmarkComparison.notes")
    }

    private func validatePackagingReadiness() throws {
        try ReleaseHardeningValidator.requireNonEmpty(packagingReadiness.packagingReportId, "packagingReadiness.packagingReportId")
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
            ("packagingReadiness.packagingReportId", packagingReadiness.packagingReportId),
        ]
    }
}

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

public enum ReleaseHardeningRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
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
    .packaging,
]

private func releaseHardeningPathIsInternalEvidence(_ path: String) -> Bool {
    let normalized = path.lowercased()
    return releaseHardeningInternalEvidencePathPrefixes.contains { prefix in
        normalized == prefix
            || normalized.hasPrefix("\(prefix)/")
            || normalized.contains("/\(prefix)/")
    }
}

private let releaseHardeningInternalEvidencePathPrefixes = [
    "confidential",
    "internal",
    "private",
    "proprietary",
    "reverse-engineering",
    "win-compiled",
]

private func releaseHardeningIsPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["required", "synthetic", "partial", "not-supplied", "not supplied", "placeholder"],
        trimWhitespace: false,
        emptyIsPlaceholder: false
    )
}
