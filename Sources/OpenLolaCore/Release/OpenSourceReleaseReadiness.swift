import Foundation

public enum OpenSourceReleaseRequirementKind: String, Codable, CaseIterable, Equatable, Sendable {
    case sourceLicense
    case documentationLicense
    case thirdPartyNotices
    case fixtureProvenance
    case releaseAllowlist
    case internalEvidenceExclusion
    case externalSwiftDependencies
    case reviewerSignoff
    case publicReleaseApproval
}

public struct OpenSourceReleaseRequirement: Codable, Equatable, Sendable {
    public var kind: OpenSourceReleaseRequirementKind
    public var sourcePath: String
    public var present: Bool
    public var finalized: Bool
    public var releaseBlocking: Bool
    public var notes: String

    public init(
        kind: OpenSourceReleaseRequirementKind,
        sourcePath: String,
        present: Bool,
        finalized: Bool,
        releaseBlocking: Bool,
        notes: String
    ) {
        self.kind = kind
        self.sourcePath = sourcePath
        self.present = present
        self.finalized = finalized
        self.releaseBlocking = releaseBlocking
        self.notes = notes
    }
}

public enum OpenSourceReleaseReadinessValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationMalformedFieldError {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
    case duplicateRequirement(OpenSourceReleaseRequirementKind)
    case missingRequirement(OpenSourceReleaseRequirementKind)
    case partialWithoutBlockers
    case passWithBlockers
    case passWithUnreadyRequirement(OpenSourceReleaseRequirementKind)
}

public struct OpenSourceReleaseReadinessReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var requirements: [OpenSourceReleaseRequirement]
    public var blockers: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        requirements: [OpenSourceReleaseRequirement],
        blockers: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.requirements = requirements
        self.blockers = blockers
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try OpenSourceReleaseReadinessValidator.requireNonEmpty(id, "id")
        try OpenSourceReleaseReadinessValidator.requireNonEmpty(title, "title")
        try OpenSourceReleaseReadinessValidator.requireNonEmpty(capturedAt, "capturedAt")
        try OpenSourceReleaseReadinessValidator.requireISO8601Date(capturedAt, "capturedAt")
        try OpenSourceReleaseReadinessValidator.requireNonEmpty(notes, "notes")
        try validateRequirements()
        try validateBlockers()
        try validatePartialVerdict()
        try validatePassVerdict()
    }

    private func validateRequirements() throws {
        guard !requirements.isEmpty else {
            throw OpenSourceReleaseReadinessValidationError.emptyList("requirements")
        }
        var seen: Set<OpenSourceReleaseRequirementKind> = []
        for requirement in requirements {
            guard seen.insert(requirement.kind).inserted else {
                throw OpenSourceReleaseReadinessValidationError.duplicateRequirement(requirement.kind)
            }
            try OpenSourceReleaseReadinessValidator.requireNonEmpty(requirement.sourcePath, "requirements.sourcePath")
            try OpenSourceReleaseReadinessValidator.requireNonEmpty(requirement.notes, "requirements.notes")
        }
        for requiredKind in OpenSourceReleaseRequirementKind.allCases where !seen.contains(requiredKind) {
            throw OpenSourceReleaseReadinessValidationError.missingRequirement(requiredKind)
        }
    }

    private func validateBlockers() throws {
        for blocker in blockers {
            try OpenSourceReleaseReadinessValidator.requireNonEmpty(blocker, "blockers")
        }
    }

    private func validatePartialVerdict() throws {
        if verdict == .partial, blockers.isEmpty {
            throw OpenSourceReleaseReadinessValidationError.partialWithoutBlockers
        }
    }

    private func validatePassVerdict() throws {
        try VerdictValidationPolicy.validatePass(verdict) {
            try VerdictValidationPolicy.passForbids(
                !blockers.isEmpty,
                OpenSourceReleaseReadinessValidationError.passWithBlockers
            )
            for requirement in requirements where !requirement.present || !requirement.finalized || requirement.releaseBlocking {
                try VerdictValidationPolicy.passForbids(
                    true,
                    OpenSourceReleaseReadinessValidationError.passWithUnreadyRequirement(requirement.kind)
                )
            }
        }
    }
}

public struct OpenSourceReleaseReadinessRunConfiguration: Codable, Equatable, Sendable {
    public let outputPath: String

    public init(outputPath: String) {
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> OpenSourceReleaseReadinessRunConfiguration {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: ["--output"],
            unknown: OpenSourceReleaseReadinessRunConfigurationError.unknownArgument,
            duplicate: OpenSourceReleaseReadinessRunConfigurationError.duplicateArgument,
            missingValue: OpenSourceReleaseReadinessRunConfigurationError.missingValue
        )
        let outputPath = try KeyValueArgumentParser.requiredString(
            "--output",
            values,
            missing: OpenSourceReleaseReadinessRunConfigurationError.missingRequiredArgument
        )
        return OpenSourceReleaseReadinessRunConfiguration(outputPath: outputPath)
    }
}

public enum OpenSourceReleaseReadinessRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

public enum OpenSourceReleaseReadinessRunner {
    public static func run(
        configuration: OpenSourceReleaseReadinessRunConfiguration,
        repositoryRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> OpenSourceReleaseReadinessReport {
        let requirements = makeRequirements(repositoryRoot: repositoryRoot)
        let blockers = requirements
            .filter(\.releaseBlocking)
            .map { "\($0.kind.rawValue): \($0.notes)" }
        return OpenSourceReleaseReadinessReport(
            id: "open-source-release-readiness-current",
            title: "Open-source release readiness preflight",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            requirements: requirements,
            blockers: blockers,
            verdict: blockers.isEmpty ? .pass : .partial,
            notes: "Source-level release preflight for \(configuration.outputPath); it does not choose licenses or approve publication."
        )
    }

    private static func makeRequirements(repositoryRoot: URL) -> [OpenSourceReleaseRequirement] {
        let inputs = readRequirementInputs(repositoryRoot: repositoryRoot)
        return licenseRequirements(inputs)
            + releaseBoundaryRequirements(inputs)
            + signoffRequirements(inputs)
    }

    private static func readRequirementInputs(repositoryRoot: URL) -> OpenSourceReleaseReadinessInputs {
        OpenSourceReleaseReadinessInputs(
            license: readText("LICENSE", repositoryRoot: repositoryRoot),
            licenseDecision: readText("docs/license-decision-record.md", repositoryRoot: repositoryRoot),
            notices: readText("THIRD_PARTY_NOTICES.md", repositoryRoot: repositoryRoot),
            fixtureProvenance: readText("docs/fixture-provenance.md", repositoryRoot: repositoryRoot),
            releaseManifest: readText("docs/release-manifest.md", repositoryRoot: repositoryRoot),
            finalReviewPacket: readText("docs/final-review-packet.md", repositoryRoot: repositoryRoot),
            packageManifest: readText("Package.swift", repositoryRoot: repositoryRoot)
        )
    }

    private static func licenseRequirements(
        _ inputs: OpenSourceReleaseReadinessInputs
    ) -> [OpenSourceReleaseRequirement] {
        [
            requirement(
                .sourceLicense,
                "LICENSE",
                text: inputs.license,
                ready: inputs.license.readable
                    && !containsDraftMarker(inputs.license.contents)
                    && !inputs.license.contents.contains("no final open-source license"),
                notes: "Root license must be a final grant, not the current pending placeholder."
            ),
            requirement(
                .documentationLicense,
                "docs/license-decision-record.md",
                text: inputs.licenseDecision,
                ready: inputs.licenseDecision.readable && !containsDraftMarker(inputs.licenseDecision.contents),
                notes: "Documentation license decision must be recorded and no longer deferred."
            ),
            requirement(
                .thirdPartyNotices,
                "THIRD_PARTY_NOTICES.md",
                text: inputs.notices,
                ready: inputs.notices.readable && !containsDraftMarker(inputs.notices.contents),
                notes: "Notice packet must be final against the selected release allowlist."
            ),
            requirement(
                .fixtureProvenance,
                "docs/fixture-provenance.md",
                text: inputs.fixtureProvenance,
                ready: inputs.fixtureProvenance.readable
                    && !containsDraftMarker(inputs.fixtureProvenance.contents),
                notes: "Fixture provenance must be confirmed before fixtures are included."
            ),
        ]
    }

    private static func releaseBoundaryRequirements(
        _ inputs: OpenSourceReleaseReadinessInputs
    ) -> [OpenSourceReleaseRequirement] {
        [
            requirement(
                .releaseAllowlist,
                "docs/release-manifest.md",
                text: inputs.releaseManifest,
                ready: inputs.releaseManifest.readable
                    && inputs.releaseManifest.contents.contains("generated from an allowlist"),
                notes: "Release candidates must be allowlist-generated, not raw-checkout archives."
            ),
            requirement(
                .internalEvidenceExclusion,
                "docs/release-manifest.md",
                text: inputs.releaseManifest,
                ready: releaseManifestExcludesInternalEvidence(inputs.releaseManifest),
                notes: "Internal evidence, generated analysis, and unclear media/captures must stay excluded."
            ),
            requirement(
                .externalSwiftDependencies,
                "Package.swift",
                text: inputs.packageManifest,
                ready: inputs.packageManifest.readable && !inputs.packageManifest.contents.contains(".package("),
                notes: "SwiftPM manifest must stay free of external package dependencies until license review is rerun."
            ),
        ]
    }

    private static func signoffRequirements(
        _ inputs: OpenSourceReleaseReadinessInputs
    ) -> [OpenSourceReleaseRequirement] {
        [
            requirement(
                .reviewerSignoff,
                "docs/final-review-packet.md",
                text: inputs.finalReviewPacket,
                ready: inputs.finalReviewPacket.readable
                    && !containsDraftMarker(inputs.finalReviewPacket.contents),
                notes: "Maintainer, legal, clean-room, and release reviewer signoff must be recorded."
            ),
            requirement(
                .publicReleaseApproval,
                "docs/release-manifest.md",
                text: inputs.releaseManifest,
                ready: inputs.releaseManifest.readable
                    && releaseManifestHasStandalonePassVerdict(inputs.releaseManifest.contents),
                notes: "Public release approval remains blocked until the manifest and review packet reach PASS."
            ),
        ]
    }

    private static func releaseManifestExcludesInternalEvidence(_ releaseManifest: ReadTextResult) -> Bool {
        releaseManifest.readable
            && releaseManifest.contents.contains("archive/2026-05-11-win-compiled/**")
            && releaseManifest.contents.contains("private/**")
            && releaseManifest.contents.contains("reverse-engineering/**")
            && releaseManifest.contents.contains("Exclude By Default")
    }

    private static func requirement(
        _ kind: OpenSourceReleaseRequirementKind,
        _ sourcePath: String,
        text: ReadTextResult,
        ready: Bool,
        notes: String
    ) -> OpenSourceReleaseRequirement {
        OpenSourceReleaseRequirement(
            kind: kind,
            sourcePath: sourcePath,
            present: text.exists,
            finalized: ready,
            releaseBlocking: !ready,
            notes: text.notes(appendingTo: notes, sourcePath: sourcePath)
        )
    }

    private static func readText(
        _ relativePath: String,
        repositoryRoot: URL
    ) -> ReadTextResult {
        let url = repositoryRoot.appendingPathComponent(relativePath)
        do {
            return .found(try String(contentsOf: url, encoding: .utf8))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .absent
        } catch {
            return .readError(error)
        }
    }

    private static func containsDraftMarker(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return [
            "placeholder",
            "pending",
            "not final",
            "not selected",
            "deferred",
            "not confirmed",
            "missing",
            "reviewer decisions pending",
            "signoff pending",
            "verdict: partial",
            PlaceholderDetection.manualEvidenceToken,
        ].contains { normalized.contains($0) }
    }

    private static func releaseManifestHasStandalonePassVerdict(_ text: String) -> Bool {
        text.components(separatedBy: "\n")
            .contains { $0.trimmingCharacters(in: .whitespaces) == "Verdict: PASS" }
    }

    private struct OpenSourceReleaseReadinessInputs {
        var license: ReadTextResult
        var licenseDecision: ReadTextResult
        var notices: ReadTextResult
        var fixtureProvenance: ReadTextResult
        var releaseManifest: ReadTextResult
        var finalReviewPacket: ReadTextResult
        var packageManifest: ReadTextResult
    }

    private enum ReadTextResult {
        case found(String)
        case absent
        case readError(Error)

        var exists: Bool {
            switch self {
            case .found, .readError:
                true
            case .absent:
                false
            }
        }

        var readable: Bool {
            switch self {
            case .found:
                true
            case .absent, .readError:
                false
            }
        }

        var contents: String {
            switch self {
            case .found(let contents):
                contents
            case .absent, .readError:
                ""
            }
        }

        func notes(appendingTo notes: String, sourcePath: String) -> String {
            switch self {
            case .found, .absent:
                notes
            case .readError(let error):
                "\(notes) Read error for \(sourcePath): \(error.localizedDescription)"
            }
        }
    }
}
