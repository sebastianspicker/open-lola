// Creates source-only hardening claims and upgrades gates from an output directory without treating fixture files as release proof.
import Foundation

/// Creates deterministic synthetic release-hardening evidence that exercises report validation without claiming physical measurement.
public enum ReleaseHardeningSyntheticSmoke {
    public static func run() -> ReleaseHardeningReport {
        ReleaseHardeningReport(
            identity: ReleaseHardeningReport.Identity(
                id: "m14-release-hardening-synthetic-smoke",
                title: "M14 release hardening synthetic smoke",
                capturedAt: "2026-05-03T00:00:00Z",
                runMode: .synthetic
            ),
            evidence: ReleaseHardeningReport.Evidence(
                publicDocs: cleanReleasePublicDocAudit(),
                claims: releaseHardeningClaims(),
                verificationGates: releaseHardeningVerificationGates(),
                benchmarkComparison: releaseHardeningBenchmarkComparison(),
                packagingReadiness: releaseHardeningPackagingReadiness()
            ),
            outcome: ReleaseHardeningReport.Outcome(
                remainingPartialGates: releaseHardeningRemainingPartialGates(),
                verdict: .partial,
                notes: "Synthetic M14 release ledger; no release PASS claim is made."
            )
        )
    }
}

/// Runs the release-hardening evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum ReleaseHardeningRunner {
    public static func run(configuration: ReleaseHardeningRunConfiguration) -> ReleaseHardeningReport {
        var report = ReleaseHardeningSyntheticSmoke.run()
        let outputDirectory = URL(fileURLWithPath: configuration.outputPath).deletingLastPathComponent()
        report.id = "m14-release-hardening-run"
        report.title = "M14 release hardening handoff"
        report.capturedAt = ISO8601DateFormatter().string(from: Date())
        report.verificationGates = releaseHardeningRunnerVerificationGates(outputDirectory: outputDirectory)
        report.remainingPartialGates = releaseHardeningRunnerRemainingPartialGates(outputDirectory: outputDirectory)
        report.notes = "Bounded M14 handoff for \(configuration.outputPath); " +
"final release PASS still needs measured gates."
        return report
    }
}

private func cleanReleasePublicDocAudit() -> ReleasePublicDocAudit {
    ReleasePublicDocAudit(
        reviewStatus: ReleasePublicDocAudit.ReviewStatus(
            publicDocsAudited: true,
            cleanRoomRulesReviewed: true,
            publicationRedactionsReviewed: true,
            evidenceLabelsPresent: true
        ),
        findings: ReleasePublicDocAudit.Findings(
            forbiddenTokens: [],
            internalEvidenceLinks: [],
            proprietaryLeakage: [],
            unsupportedCompatibilityClaims: [],
            generatedArtifacts: []
        )
    )
}

private func releaseHardeningClaims() -> [ReleaseClaimReference] {
    [
        ReleaseClaimReference(
            claim: "Public release docs are clean-room safe at source-validation level.",
            evidenceKind: .publicDocumentation,
            sourcePath: "docs/release-boundary.md",
            sourceVerdict: .partial,
            notes: "The public docs verifier owns the leakage scan."
        ),
        ReleaseClaimReference(
            claim: "Release-hardening PASS claims require source tests.",
            evidenceKind: .openLolaTest,
            sourcePath: "Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift",
            sourceVerdict: .partial,
            notes: "Fixture, PASS guard, JSON round-trip, and runner tests define the source contract."
        ),
        ReleaseClaimReference(
            claim: "Packaging and clean-Mac readiness remain PARTIAL until measured field evidence exists.",
            evidenceKind: .measuredReport,
            sourcePath: "reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md",
            sourceVerdict: .partial,
            notes: "M15 source validation exists; signing, notarization, Gatekeeper, and clean-Mac evidence are open."
        )
    ]
}

private func releaseHardeningVerificationGates() -> [ReleaseVerificationGate] {
    [
        ReleaseVerificationGate(
            name: "docs verifier",
            kind: .docs,
            command: "bash scripts/verify-docs.sh",
            passed: true,
            verdict: .pass,
            notes: "Required public docs and clean-room release surface gate."
        ),
        ReleaseVerificationGate(
            name: "shellcheck",
            kind: .shell,
            command: "shellcheck -x scripts/*.sh scripts/lib/*.sh",
            passed: false,
            verdict: .partial,
            notes: "Required shell hygiene gate for release scripts."
        ),
        ReleaseVerificationGate(
            name: "swift build",
            kind: .swiftBuild,
            command: "swift build",
            passed: false,
            verdict: .partial,
            notes: "Required SwiftPM build gate."
        ),
        ReleaseVerificationGate(
            name: "swift test --no-parallel",
            kind: .swiftTest,
            command: "swift test --no-parallel",
            passed: false,
            verdict: .partial,
            notes: "Required SwiftPM test gate."
        ),
        ReleaseVerificationGate(
            name: "release hardening smoke",
            kind: .cliSmoke,
            command: ".build/debug/open-lola release-hardening-synthetic-smoke",
            passed: false,
            verdict: .partial,
            notes: "User-surface probe for the release-hardening ledger."
        )
    ]
}

private func releaseHardeningBenchmarkComparison() -> ReleaseBenchmarkComparison {
    ReleaseBenchmarkComparison(
        selectedProfile: "audio-first field-ready profile",
        m12ReportId: "m12-apple-silicon-performance-required",
        m13ReportId: "m13-e2e-integrated-benchmark-required",
        currentBenchmarkReportId: "f10-faster-than-lola-closure-required",
        comparedWithAcceptedReports: false,
        regressionDetected: false,
        notes: "Measured M12 Apple Silicon, M13 E2E, and F10 benchmark evidence is still required before release PASS."
    )
}

private func releaseHardeningPackagingReadiness() -> ReleasePackagingReadiness {
    ReleasePackagingReadiness(
        packagingReportId: "M15_PACKAGING_FIELD_TEST_2026-05-02",
        packagingVerdict: .partial,
        cleanMacVerdict: .partial,
        signingVerdict: .partial,
        generatedArtifactsExcluded: true,
        notes: "M15 ad-hoc package source validation exists; Developer ID " +
            "signing and clean-Mac launch evidence remain open."
    )
}

private func releaseHardeningRemainingPartialGates() -> [String] {
    ["swift-build-and-test", "regression-benchmark-comparison", "developer-id-notarization", "clean-mac-field-test"]
}

private func releaseHardeningRunnerVerificationGates(outputDirectory: URL) -> [ReleaseVerificationGate] {
    releaseHardeningVerificationGates() + [
        ReleaseVerificationGate(
            name: "benchmark report presence",
            kind: .benchmark,
            command: "test -f \(outputDirectory.appendingPathComponent("m12-apple-silicon-performance.json").path) " +
"&& test -f \(outputDirectory.appendingPathComponent("m13-e2e-integrated-benchmark.json").path) " +
"&& test -f \(outputDirectory.appendingPathComponent("f10-faster-than-lola-closure.json").path)",
            passed: releaseHardeningBenchmarkReportsExist(outputDirectory: outputDirectory),
            verdict: releaseHardeningBenchmarkReportsExist(outputDirectory: outputDirectory) ? .pass : .partial,
            notes: "Checks whether the benchmark reports needed for release " +
                "comparison are attached beside the release-hardening output."
        ),
        ReleaseVerificationGate(
            name: "packaging report presence",
            kind: .packaging,
            command: "test -f \(outputDirectory.appendingPathComponent("m15-packaging-field.json").path)",
            passed: releaseHardeningPackagingReportExists(outputDirectory: outputDirectory),
            verdict: releaseHardeningPackagingReportExists(outputDirectory: outputDirectory) ? .pass : .partial,
            notes: "Checks whether the packaging field-test report is attached beside the release-hardening output."
        )
    ]
}

private func releaseHardeningRunnerRemainingPartialGates(outputDirectory: URL) -> [String] {
    var gates = [
        "swift-build-not-executed-by-runner",
        "swift-test-not-executed-by-runner",
        "release-smoke-not-executed-by-runner",
        "developer-id-notarization",
        "clean-mac-field-test"
    ]
    if !releaseHardeningBenchmarkReportsExist(outputDirectory: outputDirectory) {
        gates.append("benchmark-reports-not-attached")
    }
    if !releaseHardeningPackagingReportExists(outputDirectory: outputDirectory) {
        gates.append("packaging-report-not-attached")
    }
    return gates
}

private func releaseHardeningBenchmarkReportsExist(outputDirectory: URL) -> Bool {
    [
        "m12-apple-silicon-performance.json",
        "m13-e2e-integrated-benchmark.json",
        "f10-faster-than-lola-closure.json"
    ].allSatisfy { FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent($0).path) }
}

private func releaseHardeningPackagingReportExists(outputDirectory: URL) -> Bool {
    FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("m15-packaging-field.json").path)
}
