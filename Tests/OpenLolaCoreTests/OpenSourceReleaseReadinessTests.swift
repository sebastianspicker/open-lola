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
func openSourceReleaseReadinessRejectsPassWithMissingRequirementKind() throws {
    var report = passCandidateReport()
    report.requirements.removeAll { $0.kind == .publicReleaseApproval }

    #expect(throws: OpenSourceReleaseReadinessValidationError.missingRequirement(.publicReleaseApproval)) {
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

@Test
func releaseApprovalRequiresVerdictPassOnItsOwnLine() throws {
    let root = try releaseReadinessRepository(
        releaseManifest: """
        generated from an allowlist
        archive/2026-05-11-win-compiled/**
        private/**
        reverse-engineering/**
        Exclude By Default
        Not ready: Verdict: PASS is not confirmed
        """
    )

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let approval = try requirement(.publicReleaseApproval, in: report)
    #expect(approval.releaseBlocking)
    #expect(report.verdict == .partial)
}

@Test
func releaseApprovalPassesConformingManifest() throws {
    let root = try releaseReadinessRepository(
        releaseManifest: """
        generated from an allowlist
        archive/2026-05-11-win-compiled/**
        private/**
        reverse-engineering/**
        Exclude By Default
        Verdict: PASS
        """
    )

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let approval = try requirement(.publicReleaseApproval, in: report)
    #expect(approval.releaseBlocking == false)
    #expect(report.verdict == .pass)
}

@Test
func releaseApprovalRejectsMultiwordLineContainingVerdictPass() throws {
    let root = try releaseReadinessRepository(
        releaseManifest: """
        generated from an allowlist
        archive/2026-05-11-win-compiled/**
        private/**
        reverse-engineering/**
        Exclude By Default
        # Verdict: PASS
        """
    )

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let approval = try requirement(.publicReleaseApproval, in: report)
    #expect(approval.releaseBlocking)
    #expect(report.verdict == .partial)
}

@Test
func releaseReadinessReportsMissingFileAsAbsent() throws {
    let root = try releaseReadinessRepository()
    try FileManager.default.removeItem(
        at: root.appendingPathComponent("docs/fixture-provenance.md")
    )

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let fixtureProvenance = try requirement(.fixtureProvenance, in: report)
    #expect(fixtureProvenance.present == false)
    #expect(fixtureProvenance.releaseBlocking)
    #expect(fixtureProvenance.notes.contains("Read error") == false)
}

@Test
func releaseReadinessReportsReadableFileAsPresent() throws {
    let root = try releaseReadinessRepository()

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let thirdPartyNotices = try requirement(.thirdPartyNotices, in: report)
    #expect(thirdPartyNotices.present)
    #expect(thirdPartyNotices.releaseBlocking == false)
}

@Test
func releaseReadinessReportsReadErrorDistinctFromAbsent() throws {
    let root = try releaseReadinessRepository()
    try Data([0xff, 0xfe, 0xfd]).write(
        to: root.appendingPathComponent("THIRD_PARTY_NOTICES.md")
    )

    let report = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "reports/open-source-readiness.json"),
        repositoryRoot: root
    )

    let thirdPartyNotices = try requirement(.thirdPartyNotices, in: report)
    #expect(thirdPartyNotices.present)
    #expect(thirdPartyNotices.releaseBlocking)
    #expect(thirdPartyNotices.notes.contains("Read error for THIRD_PARTY_NOTICES.md"))
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

private func releaseReadinessRepository(
    releaseManifest: String = """
    generated from an allowlist
    archive/2026-05-11-win-compiled/**
    private/**
    reverse-engineering/**
    Exclude By Default
    Verdict: PASS
    """
) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-release-readiness-\(UUID().uuidString)")
    let docs = root.appendingPathComponent("docs")
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    try "MIT\n".write(to: root.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)
    try "Documentation license selected.\n".write(
        to: docs.appendingPathComponent("license-decision-record.md"),
        atomically: true,
        encoding: .utf8
    )
    try "Third-party notices finalized.\n".write(
        to: root.appendingPathComponent("THIRD_PARTY_NOTICES.md"),
        atomically: true,
        encoding: .utf8
    )
    try "Fixture provenance confirmed.\n".write(
        to: docs.appendingPathComponent("fixture-provenance.md"),
        atomically: true,
        encoding: .utf8
    )
    try "Maintainer, legal, clean-room, and release reviewer signoff recorded.\n".write(
        to: docs.appendingPathComponent("final-review-packet.md"),
        atomically: true,
        encoding: .utf8
    )
    try "let package = Package(name: \"OpenLoLa\")\n".write(
        to: root.appendingPathComponent("Package.swift"),
        atomically: true,
        encoding: .utf8
    )
    try releaseManifest.write(
        to: docs.appendingPathComponent("release-manifest.md"),
        atomically: true,
        encoding: .utf8
    )
    return root
}
