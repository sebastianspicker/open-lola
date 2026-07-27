// Verifies that goal completion audit keeps requested professional AV features traceable.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func goalCompletionAuditKeepsRequestedProfessionalAVFeaturesTraceable() throws {
    let report = goalCompletionAuditReport()
    let text = report.items
        .flatMap { [$0.id, $0.title, $0.notes] + $0.evidence + $0.commands + $0.blockers }
        .joined(separator: "\n")
        .lowercased()

    #expect(text.contains("apple silicon"))
    #expect(text.contains("direct p2p"))
    #expect(text.contains("rme"))
    #expect(text.contains("madi"))
    #expect(text.contains("blackmagic"))
    #expect(text.contains("atem"))
    #expect(text.contains("decklink"))
    #expect(text.contains("ultrastudio"))
    #expect(text.contains("multiple video"))
    #expect(text.contains("lighting"))
    #expect(text.contains("latency budget"))
    #expect(text.contains("video never blocks audio"))
}

@Test
func goalCompletionAuditMapsEveryBlockerToClosureCommands() throws {
    let report = goalCompletionAuditReport()

    try report.validate()

    let rmeAction = try #require(report.nextActions.first {
        $0.itemID == "runtime.\(GoalRuntimeEvidenceDeliverableID.twoMacRmeMadiBidirectional.rawValue)"
    })
    let releaseAction = try #require(report.nextActions.first {
        $0.itemID == "release.\(OpenSourceReleaseRequirementKind.sourceLicense.rawValue)"
    })

    #expect(rmeAction.blocker.contains("Core Audio") || rmeAction.blocker.contains("RME"))
    #expect(rmeAction.commands.contains { $0.contains("madi-full-duplex-run") })
    #expect(rmeAction.commands.contains { $0.contains("validate-madi-full-duplex-report") })
    #expect(releaseAction.evidence.contains("LICENSE"))
    #expect(releaseAction.commands.contains("open-source-release-readiness-run"))
    #expect(releaseAction.commands.contains("validate-open-source-release-readiness-report"))
}

@Test
// swiftlint:disable:next function_body_length
func goalCompletionAuditRejectsInvalidSummaryAndVerdictState() throws {
    var report = goalCompletionAuditReport()
    let duplicatedID = report.nextActions[0].id
    report.nextActions[1].id = duplicatedID
    report.summary = GoalCompletionAuditSummary(
        items: report.items,
        blockers: report.blockers,
        nextActions: report.nextActions
    )

    #expect(throws: GoalCompletionAuditValidationError.duplicateNextAction(duplicatedID)) {
        try report.validate()
    }

    report = goalCompletionAuditReport()
    report.nextActions.removeLast()
    report.summary = GoalCompletionAuditSummary(
        items: report.items,
        blockers: report.blockers,
        nextActions: report.nextActions
    )

    #expect(throws: GoalCompletionAuditValidationError.nextActionMismatch) {
        try report.validate()
    }

    report = goalCompletionAuditReport()
    report.items.removeAll { $0.id == "goal.\(GoalCodewiseRequirementID.architectureMacOSAppleSilicon.rawValue)" }
    report.summary = GoalCompletionAuditSummary(
        items: report.items,
        blockers: report.blockers,
        nextActions: report.nextActions
    )

    #expect(throws: GoalCompletionAuditValidationError.missingGoalRequirement(
        GoalCodewiseRequirementID.architectureMacOSAppleSilicon.rawValue
    )) {
        try report.validate()
    }

    report = goalCompletionAuditReport()
    report.realWorldVerdict = .pass

    #expect(throws: GoalCompletionAuditValidationError.passWithBlockers) {
        try report.validate()
    }

    report = goalCompletionAuditReport()
    report.items = report.items.map { item in
        var copy = item
        copy.blockers = []
        copy.verdict = .pass
        return copy
    }
    report.blockers = []
    report.nextActions = []
    report.summary = GoalCompletionAuditSummary(
        items: report.items,
        blockers: report.blockers,
        nextActions: report.nextActions
    )

    #expect(throws: GoalCompletionAuditValidationError.emptyList("blockers")) {
        try report.validate()
    }
}

@Test
func goalCompletionAuditValidatorPrintsRealWorldVerdictAndBlockers() throws {
    let report = goalCompletionAuditReport()
    let output = try ReportValidatorSurface.validate(
        try report.prettyJSONData(),
        as: GoalCompletionAuditReport.self,
        label: "GOAL.md completion audit report",
        extraLines: {
            [
                "real-world-verdict: \($0.realWorldVerdict.rawValue)",
                "blockers: \($0.blockers.count)",
                "next-actions: \($0.nextActions.count)"
            ]
        }
    )

    #expect(output.lines == [
        "GOAL.md completion audit report valid: goal-completion-audit-2026-05-05",
        "real-world-verdict: partial",
        "blockers: \(report.blockers.count)",
        "next-actions: \(report.nextActions.count)",
        "VERDICT: PARTIAL"
    ])
}

private func goalCompletionAuditReport() -> GoalCompletionAuditReport {
    GoalCompletionAuditReport.make(
        capturedAt: "2026-05-05T00:00:00Z",
        codewise: GoalCodewiseClosureReport.codewiseClosure(),
        runtime: blockedPreflightReport(),
        openSource: openSourcePartialReport()
    )
}

private func openSourcePartialReport() -> OpenSourceReleaseReadinessReport {
    let requirements = OpenSourceReleaseRequirementKind.allCases.map { kind in
        let blocking = kind == .sourceLicense || kind == .publicReleaseApproval
        return OpenSourceReleaseRequirement(
            kind: kind,
            sourcePath: sourcePath(for: kind),
            present: true,
            finalized: !blocking,
            releaseBlocking: blocking,
            notes: blocking
                ? "Requirement remains blocked for release approval."
                : "Requirement is source-visible for this audit fixture."
        )
    }
    return OpenSourceReleaseReadinessReport(
        id: "open-source-release-readiness-audit-fixture",
        title: "Open-source release readiness audit fixture",
        capturedAt: "2026-05-05T00:00:00Z",
        requirements: requirements,
        blockers: [
            "sourceLicense: final license grant pending",
            "publicReleaseApproval: public approval pending"
        ],
        verdict: .partial,
        notes: "Deterministic fixture for goal completion audit tests."
    )
}

private func sourcePath(for kind: OpenSourceReleaseRequirementKind) -> String {
    openSourceRequirementSourcePaths.first { $0.kind == kind }?.path ?? ""
}

let openSourceRequirementSourcePaths: [(kind: OpenSourceReleaseRequirementKind, path: String)] = [
    (.sourceLicense, "LICENSE"),
    (.documentationLicense, "docs/license-decision-record.md"),
    (.thirdPartyNotices, "THIRD_PARTY_NOTICES.md"),
    (.fixtureProvenance, "docs/fixture-provenance.md"),
    (.releaseAllowlist, "docs/release-manifest.md"),
    (.internalEvidenceExclusion, "docs/release-manifest.md"),
    (.externalSwiftDependencies, "Package.swift"),
    (.reviewerSignoff, "docs/final-review-packet.md"),
    (.publicReleaseApproval, "docs/release-manifest.md")
]
