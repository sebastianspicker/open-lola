// Verifies that release hardening run configuration parses output and rejects missing output.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func releaseHardeningRunConfigurationParsesOutputAndRejectsMissingOutput() throws {
    let configuration = try ReleaseHardeningRunConfiguration.parse([
        "--output", "reports/m14-release-hardening.json"
    ])

    #expect(configuration.outputPath == "reports/m14-release-hardening.json")

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
func releaseHardeningRejectsInvalidPassEvidence() throws {
    let syntheticPass = try loadReleaseHardeningFixture(named: "release-hardening-synthetic-pass")
    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredRun) {
        try syntheticPass.validate()
    }

    try expectReleaseHardeningError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectReleaseHardeningError(.passWithFailingVerificationGate("docs verifier")) {
        $0.verificationGates[0].passed = false
    }
    try expectReleaseHardeningError(.passWithoutMeasuredReportClaim) {
        $0.claims.removeAll { $0.evidenceKind == .measuredReport }
    }
    try expectReleaseHardeningError(.passMissingVerificationGate(.benchmark)) {
        $0.verificationGates.removeAll { $0.kind == .benchmark }
    }
    try expectReleaseHardeningError(.passWithBenchmarkRegression) {
        $0.benchmarkComparison.regressionDetected = true
    }
    try expectReleaseHardeningError(.passWithPlaceholderEvidenceField(
        "benchmarkComparison.currentBenchmarkReportId"
    )) {
        $0.benchmarkComparison.currentBenchmarkReportId = "f10-faster-than-lola-closure-required"
    }
    try expectReleaseHardeningError(.passWithoutPackagingPass(.partial)) {
        $0.packagingReadiness.packagingVerdict = .partial
    }

    #expect(throws: ReleaseHardeningValidationError.claimUsesInternalEvidence(
        "private/reverse-engineering/lola-2-windows/static-analysis.md"
    )) {
        var report = try passCandidateReport()
        report.claims[0].sourcePath = "private/reverse-engineering/lola-2-windows/static-analysis.md"
        try report.validate()
    }

    for sourcePath in [
        "internal/windows-lola/static-analysis.md",
        "docs/confidential/windows-lola/static-analysis.md",
        "proprietary/lola-2-windows/static-analysis.md"
    ] {
        var report = try passCandidateReport()
        report.claims[0].sourcePath = sourcePath

        #expect(throws: ReleaseHardeningValidationError.claimUsesInternalEvidence(sourcePath)) {
            try report.validate()
        }
    }
}

@Test
func releaseHardeningDocsExposeImplementedReleaseSurface() throws {
    let root = repositoryRoot()
    let releaseBoundary = try String(
        contentsOf: root.appendingPathComponent("docs/release-boundary.md"),
        encoding: .utf8
    )
    let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)

    #expect(releaseBoundary.contains("Release remains `PARTIAL`"))
    #expect(releaseBoundary.contains("clean-room"))
    #expect(readme.contains("experimental source alpha"))
    #expect(readme.contains("currently grants no rights"))
    #expect(readme.contains("bash scripts/export-release-candidate.sh"))
    #expect(readme.contains("The exporter refuses a dirty checkout by default"))
}

private func expectReleaseHardeningError(
    _ expected: ReleaseHardeningValidationError,
    mutate: (inout ReleaseHardeningReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
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
appendPassCandidateVerificationGates(to: &report)
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

private func appendPassCandidateVerificationGates(to report: inout ReleaseHardeningReport) {
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
