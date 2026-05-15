import Foundation
import Testing

@testable import OpenLolaCore

@Test
func releaseHardeningFixtureDecodesAndValidates() throws {
    let report = try loadReleaseHardeningFixture(named: "release-hardening-partial")

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.publicDocs.publicDocsAudited)
    #expect(report.remainingPartialGates.isEmpty == false)
}

@Test
func releaseHardeningSyntheticSmokeEmitsPartialReport() throws {
    let report = ReleaseHardeningSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.claims.map(\.evidenceKind).contains(.publicDocumentation))
    #expect(report.verificationGates.map(\.kind).contains(.swiftTest))
    #expect(report.benchmarkComparison.m12ReportId.contains("apple-silicon-performance"))
    #expect(report.benchmarkComparison.m13ReportId.contains("e2e-integrated-benchmark"))
}

@Test
func releaseHardeningRejectsSyntheticPassFixture() throws {
    let report = try loadReleaseHardeningFixture(named: "release-hardening-synthetic-pass")

    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func releaseHardeningRunConfigurationParsesOutput() throws {
    let configuration = try ReleaseHardeningRunConfiguration.parse([
        "--output", "reports/m14-release-hardening.json",
    ])

    #expect(configuration.outputPath == "reports/m14-release-hardening.json")
}

@Test
func releaseHardeningRunConfigurationRejectsMissingOutput() {
    #expect(throws: ReleaseHardeningRunConfigurationError.missingRequiredArgument("--output")) {
        _ = try ReleaseHardeningRunConfiguration.parse([])
    }
}

@Test
func releaseHardeningRunnerBuildsPartialHandoff() throws {
    let report = ReleaseHardeningRunner.run(
        configuration: ReleaseHardeningRunConfiguration(
            outputPath: "reports/m14-release-hardening.json"
        )
    )

    try report.validate()

    #expect(report.id == "m14-release-hardening-run")
    #expect(report.verdict == .partial)
    #expect(report.verificationGates.contains { $0.name == "benchmark report presence" && $0.kind == .benchmark })
    #expect(report.verificationGates.contains { $0.name == "packaging report presence" && $0.kind == .packaging })
    #expect(report.remainingPartialGates.contains("swift-test-not-executed-by-runner"))
    #expect(report.remainingPartialGates.contains("benchmark-reports-not-attached"))
    #expect(report.remainingPartialGates.contains("packaging-report-not-attached"))
}

@Test
func releaseHardeningPassCandidateValidates() throws {
    let report = try passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
}

@Test
func releaseHardeningRejectsPassWithoutMeasuredRun() throws {
    var report = try passCandidateReport()
    report.runMode = .synthetic

    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsInternalEvidenceClaim() throws {
    var report = try passCandidateReport()
    report.claims[0].sourcePath = "private/reverse-engineering/lola-2-windows/static-analysis.md"

    #expect(throws: ReleaseHardeningValidationError.claimUsesInternalEvidence(
        "private/reverse-engineering/lola-2-windows/static-analysis.md"
    )) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsBroaderInternalEvidencePathPrefixes() throws {
    for sourcePath in [
        "internal/windows-lola/static-analysis.md",
        "docs/confidential/windows-lola/static-analysis.md",
        "proprietary/lola-2-windows/static-analysis.md",
    ] {
        var report = try passCandidateReport()
        report.claims[0].sourcePath = sourcePath

        #expect(throws: ReleaseHardeningValidationError.claimUsesInternalEvidence(sourcePath)) {
            try report.validate()
        }
    }
}

@Test
func releaseHardeningRejectsPassWithFailingGate() throws {
    var report = try passCandidateReport()
    report.verificationGates[0].passed = false

    #expect(throws: ReleaseHardeningValidationError.passWithFailingVerificationGate("docs verifier")) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsPassWithoutMeasuredReportClaim() throws {
    var report = try passCandidateReport()
    report.claims.removeAll { $0.evidenceKind == .measuredReport }

    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredReportClaim) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsPassWithoutBenchmarkGate() throws {
    var report = try passCandidateReport()
    report.verificationGates.removeAll { $0.kind == .benchmark }

    #expect(throws: ReleaseHardeningValidationError.passMissingVerificationGate(.benchmark)) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsPassWithBenchmarkRegression() throws {
    var report = try passCandidateReport()
    report.benchmarkComparison.regressionDetected = true

    #expect(throws: ReleaseHardeningValidationError.passWithBenchmarkRegression) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsPassWithPlaceholderBenchmarkEvidence() throws {
    var report = try passCandidateReport()
    report.benchmarkComparison.currentBenchmarkReportId = "f10-faster-than-lola-closure-required"

    #expect(throws: ReleaseHardeningValidationError.passWithPlaceholderEvidenceField(
        "benchmarkComparison.currentBenchmarkReportId"
    )) {
        try report.validate()
    }
}

@Test
func releaseHardeningRejectsPassWithPartialPackaging() throws {
    var report = try passCandidateReport()
    report.packagingReadiness.packagingVerdict = .partial

    #expect(throws: ReleaseHardeningValidationError.passWithoutPackagingPass(.partial)) {
        try report.validate()
    }
}

@Test
func releaseHardeningJSONRoundTripPreservesReport() throws {
    let report = try loadReleaseHardeningFixture(named: "release-hardening-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try ReleaseHardeningReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func releaseHardeningDocsExposeImplementedReleaseSurface() throws {
    let root = repositoryRoot()
    let archivedMilestone = try String(
        contentsOf: root.appendingPathComponent("archive/2026-05-11-doc-cleanup/docs/milestones/M14-release-hardening.md"),
        encoding: .utf8
    )
    let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)

    #expect(archivedMilestone.contains("source-validation implemented"))
    #expect(archivedMilestone.contains("release-hardening-run"))
    #expect(archivedMilestone.contains("validate-release-hardening-report"))
    #expect(readme.contains("Direct Audio First"))
    #expect(readme.contains("Balanced AV"))
    #expect(readme.contains("Release Validation Checklist"))
    #expect(readme.contains("release-hardening-synthetic-smoke"))
}

private func passCandidateReport() throws -> ReleaseHardeningReport {
    var report = try loadReleaseHardeningFixture(named: "release-hardening-partial")
    report.runMode = .measured
    report.verdict = .pass
    report.claims = report.claims.map { claim in
        ReleaseClaimReference(
            claim: claim.claim,
            evidenceKind: claim.evidenceKind,
            sourcePath: claim.sourcePath,
            sourceVerdict: .pass,
            notes: claim.notes
        )
    }
    report.verificationGates = report.verificationGates.map { gate in
        ReleaseVerificationGate(
            name: gate.name,
            kind: gate.kind,
            command: gate.command,
            passed: true,
            verdict: .pass,
            notes: gate.notes
        )
    }
    report.verificationGates.append(
        ReleaseVerificationGate(
            name: "accepted E2E benchmark comparison",
            kind: .benchmark,
            command: "swift run open-lola validate-e2e-benchmark-report reports/m13-e2e-pass.json",
            passed: true,
            verdict: .pass,
            notes: "Measured M12/M13/F10 benchmark comparison accepted for release."
        )
    )
    report.verificationGates.append(
        ReleaseVerificationGate(
            name: "signed clean-Mac packaging field gate",
            kind: .packaging,
            command: "swift run open-lola validate-packaging-field-report reports/m15-packaging-pass.json",
            passed: true,
            verdict: .pass,
            notes: "Developer ID, notarization, Gatekeeper, and clean-Mac package evidence accepted."
        )
    )
    report.benchmarkComparison.comparedWithAcceptedReports = true
    report.benchmarkComparison.regressionDetected = false
    report.benchmarkComparison.m12ReportId = "m12-apple-silicon-performance-pass-2026-05-04"
    report.benchmarkComparison.m13ReportId = "m13-e2e-integrated-benchmark-pass-2026-05-04"
    report.benchmarkComparison.currentBenchmarkReportId = "f10-faster-than-lola-closure-pass-2026-05-04"
    report.packagingReadiness.packagingReportId = "m15-packaging-field-test-pass-2026-05-04"
    report.packagingReadiness.packagingVerdict = .pass
    report.packagingReadiness.cleanMacVerdict = .pass
    report.packagingReadiness.signingVerdict = .pass
    report.packagingReadiness.generatedArtifactsExcluded = true
    report.remainingPartialGates = []
    return report
}

private func loadReleaseHardeningFixture(named name: String) throws -> ReleaseHardeningReport {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "ReleaseHardeningReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "ReleaseHardeningReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )
    let url = try #require(validURL ?? invalidURL ?? rootURL)
    return try ReleaseHardeningReport.decode(from: Data(contentsOf: url))
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
