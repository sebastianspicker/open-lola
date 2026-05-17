import Foundation
import Testing

@testable import OpenLolaCore


@Test
func openSourceReleaseReadinessRunnerReportsCurrentCheckoutBlockers() throws {
    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: repositoryRoot
    )

    try report.validate()
    let sourceLicense = try requirement(.sourceLicense, in: report)
    let thirdPartyNotices = try requirement(.thirdPartyNotices, in: report)
    let fixtureProvenance = try requirement(.fixtureProvenance, in: report)
    let releaseAllowlist = try requirement(.releaseAllowlist, in: report)
    let internalEvidenceExclusion = try requirement(.internalEvidenceExclusion, in: report)
    let externalSwiftDependencies = try requirement(.externalSwiftDependencies, in: report)

    #expect(report.verdict == .partial)
    #expect(report.requirements.count == OpenSourceReleaseRequirementKind.allCases.count)
    #expect(report.blockers.isEmpty == false)
    #expect(sourceLicense.releaseBlocking)
    #expect(thirdPartyNotices.releaseBlocking)
    #expect(fixtureProvenance.releaseBlocking)
    #expect(releaseAllowlist.releaseBlocking == false)
    #expect(internalEvidenceExclusion.releaseBlocking == false)
    #expect(externalSwiftDependencies.releaseBlocking == false)
    #expect(externalSwiftDependencies.sourcePath == "Package.swift")
}

@Test
func openSourceReleaseReadinessRejectsPassWithDraftRequirement() throws {
    var report = passCandidateReport()
    let index = try #require(report.requirements.firstIndex { $0.kind == .thirdPartyNotices })
    report.requirements[index].finalized = false
    report.requirements[index].releaseBlocking = true

    #expect(throws: OpenSourceReleaseReadinessValidationError.passWithUnreadyRequirement(.thirdPartyNotices)) {
        try report.validate()
    }
}

@Test
func openSourceReleaseReadinessRejectsPassWithBlockers() throws {
    var report = passCandidateReport()
    report.blockers = ["sourceLicense: placeholder remains"]

    #expect(throws: OpenSourceReleaseReadinessValidationError.passWithBlockers) {
        try report.validate()
    }
}

private func passCandidateReport() -> OpenSourceReleaseReadinessReport {
    OpenSourceReleaseReadinessReport(
        id: "open-source-release-readiness-pass-candidate",
        title: "Open-source release readiness pass candidate",
        capturedAt: "2026-05-05T00:00:00Z",
        requirements: OpenSourceReleaseRequirementKind.allCases.map {
            OpenSourceReleaseRequirement(
                kind: $0,
                sourcePath: sourcePath(for: $0),
                present: true,
                finalized: true,
                releaseBlocking: false,
                notes: "Requirement finalized for PASS candidate."
            )
        },
        blockers: [],
        verdict: .pass,
        notes: "PASS candidate used only by validator tests."
    )
}

private func requirement(
    _ kind: OpenSourceReleaseRequirementKind,
    in report: OpenSourceReleaseReadinessReport
) throws -> OpenSourceReleaseRequirement {
    try #require(report.requirements.first { $0.kind == kind })
}

private func sourcePath(for kind: OpenSourceReleaseRequirementKind) -> String {
    switch kind {
    case .sourceLicense:
        "LICENSE"
    case .documentationLicense:
        "docs/license-decision-record.md"
    case .thirdPartyNotices:
        "THIRD_PARTY_NOTICES.md"
    case .fixtureProvenance:
        "docs/fixture-provenance.md"
    case .releaseAllowlist, .internalEvidenceExclusion, .publicReleaseApproval:
        "docs/release-manifest.md"
    case .externalSwiftDependencies:
        "Package.swift"
    case .reviewerSignoff:
        "docs/final-review-packet.md"
    }
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
